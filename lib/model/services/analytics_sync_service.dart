import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data_sources/analytics_event_remote_data_source.dart';
import '../entities/analytics_event.dart';
import '../repositories/connectivity_repository.dart';
import '../repositories/impl/analytics_event_repository_impl.dart';

/// Uploads the analytics events queued in `pending.jsonl`:
/// - every [interval] (30 s), if the phone is online, it takes the queue by renaming it to
///   `pending.sending.jsonl` (atomic, so `track()` keeps appending to a fresh `pending.jsonl`);
/// - sends it in batches of at most [batchSize]; a batch the server accepted (2xx) is removed
///   from the file, a batch that fails stays, and everything unsent goes back to `pending.jsonl`;
/// - reading, parsing and rewriting the files all run in isolates, one at a time with the
///   appends of `track()` ([AnalyticsQueueLock]), so no event is lost to a race.
///
/// A singleton: there must be one queue consumer. Listen to [isSyncing] to react to uploads.
class AnalyticsSyncService extends ChangeNotifier {
  static const sendingFileName = 'pending.sending.jsonl';
  static const batchSize = 10;
  static const interval = Duration(seconds: 30);

  static AnalyticsSyncService? _instance;

  /// The first call builds the service; later calls return it and ignore their arguments.
  factory AnalyticsSyncService({
    required AnalyticsEventRemoteDataSource remote,
    required ConnectivityRepository connectivity,
    Future<Directory> Function()? directory,
  }) =>
      _instance ??= AnalyticsSyncService._(remote, connectivity, directory ?? getApplicationDocumentsDirectory);

  static AnalyticsSyncService get instance =>
      _instance ?? (throw StateError('AnalyticsSyncService has not been created yet.'));

  /// Forgets the singleton so a test can build its own.
  @visibleForTesting
  static void reset() {
    _instance?.stop();
    _instance = null;
  }

  AnalyticsSyncService._(this._remote, this._connectivity, this._directory);

  final AnalyticsEventRemoteDataSource _remote;
  final ConnectivityRepository _connectivity;
  final Future<Directory> Function() _directory;

  Timer? _timer;
  bool _running = false;
  bool _isSyncing = false;

  /// Whether events are being uploaded right now.
  bool get isSyncing => _isSyncing;

  /// Starts the 30 s timer, and syncs once right away for what the last session left queued.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => syncNow());
    syncNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One sync pass. A pass already running, or no connection, makes this a no-op.
  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    try {
      if (!await _connectivity.isOnline()) return;
      final dir = (await _directory()).path;
      final pending = p.join(dir, AnalyticsEventRepositoryImpl.fileName);
      final sending = p.join(dir, sendingFileName);
      _setSyncing(true);
      try {
        await _upload(pending, sending);
      } finally {
        // Whatever happened, what was not delivered goes back to the queue.
        await AnalyticsQueueLock.run(() => Isolate.run(() => _returnToQueue(pending, sending)));
      }
    } catch (_) {
      // Best effort: the events stay on disk for the next pass.
    } finally {
      _running = false;
      _setSyncing(false);
    }
  }

  void _setSyncing(bool value) {
    if (_isSyncing == value) return;
    _isSyncing = value;
    notifyListeners();
  }

  Future<void> _upload(String pending, String sending) async {
    final events = await AnalyticsQueueLock.run(() => Isolate.run(() => _takeQueue(pending, sending)));
    for (var i = 0; i < events.length; i += batchSize) {
      final batch = events.sublist(i, i + batchSize > events.length ? events.length : i + batchSize);
      try {
        await _remote.sendBatch(batch);
      } catch (_) {
        return; // The rest waits for the next pass.
      }
      final sent = {for (final e in batch) e.clientId};
      await AnalyticsQueueLock.run(() => Isolate.run(() => _removeSent(sending, sent)));
    }
  }
}

/// Renames `pending.jsonl` to `pending.sending.jsonl` and parses it. A `.sending` file left by
/// a crash is handed back to the queue first, so there is only ever one batch file in flight.
List<AnalyticsEvent> _takeQueue(String pending, String sending) {
  _returnToQueue(pending, sending);
  final queue = File(pending);
  if (!queue.existsSync()) return const [];
  queue.renameSync(sending);
  return _parse(File(sending).readAsLinesSync());
}

/// Rewrites `.sending` without the events whose `client_id` is in [sent]. It re-reads the file
/// instead of using the first snapshot, so a line appended meanwhile is not lost.
void _removeSent(String sending, Set<String> sent) {
  final file = File(sending);
  if (!file.existsSync()) return;
  final kept = file.readAsLinesSync().where((line) {
    if (line.trim().isEmpty) return false;
    try {
      return !sent.contains((jsonDecode(line) as Map)['client_id']);
    } catch (_) {
      return false; // Corrupt line: it can never be sent.
    }
  }).toList();
  if (kept.isEmpty) {
    file.deleteSync();
    return;
  }
  final temp = File('$sending.tmp')..writeAsStringSync('${kept.join('\n')}\n', flush: true);
  temp.renameSync(sending);
}

/// Puts whatever is in `.sending` back at the end of `pending.jsonl`.
void _returnToQueue(String pending, String sending) {
  final file = File(sending);
  if (!file.existsSync()) return;
  final text = file.readAsStringSync();
  if (text.trim().isNotEmpty) {
    File(pending).writeAsStringSync(text.endsWith('\n') ? text : '$text\n', mode: FileMode.append, flush: true);
  }
  file.deleteSync();
}

List<AnalyticsEvent> _parse(List<String> lines) {
  final events = <AnalyticsEvent>[];
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      events.add(AnalyticsEvent.fromJson(jsonDecode(line) as Map<String, dynamic>));
    } catch (_) {
      // Corrupt line: skipped here and dropped by _removeSent.
    }
  }
  return events;
}
