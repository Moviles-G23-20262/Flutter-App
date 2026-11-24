import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

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
/// - how many events wait is kept in memory ([pendingCount]): the files are counted once by
///   [init], then every append adds one ([recordQueued]) and every accepted batch subtracts its
///   size. A timer tick with nothing queued returns at once, without touching the disk or
///   starting an isolate.
/// - [pause] stops the timer while the app is in the background; [resume] restarts it and
///   flushes what is waiting.
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

  /// Started with [start] and not [stop]ped; [pause] keeps it true.
  bool _started = false;
  Future<void>? _init;
  int _pendingCount = 0;
  bool _flushAgain = false;

  /// Whether events are being uploaded right now.
  bool get isSyncing => _isSyncing;

  /// Events waiting on the phone, as counted in memory (see the class comment).
  int get pendingCount => _pendingCount;

  /// Whether the periodic timer is running (false before [start], after [stop] and while paused).
  bool get isTimerActive => _timer != null;

  /// Counts the events already in the queue files. It reads the disk once; later calls return
  /// the same future.
  Future<void> init() => _init ??= _countQueued();

  Future<void> _countQueued() async {
    try {
      final dir = (await _directory()).path;
      final pending = p.join(dir, AnalyticsEventRepositoryImpl.fileName);
      final sending = p.join(dir, sendingFileName);
      // Assigned inside the lock: an append that ran before the count is in the files (and its
      // +1 is overwritten here), one that runs after adds its +1 to this value.
      await AnalyticsQueueLock.run(() async {
        _pendingCount = await _countInIsolate(pending, sending);
      });
    } catch (_) {
      // Unreadable folder: the counter starts from the appends of this session.
    }
  }

  /// One more event was appended to `pending.jsonl`. Called by the repository inside
  /// [AnalyticsQueueLock], right after the write.
  void recordQueued() => _pendingCount++;

  /// Starts the 30 s timer, and syncs once right away for what the last session left queued.
  void start() {
    if (_started) return;
    _started = true;
    _startTimer();
    init().then((_) => _flushIfQueued());
  }

  void stop() {
    _started = false;
    _cancelTimer();
  }

  /// The app went to the background: no timer wakes the CPU. The queue and its count stay.
  void pause() => _cancelTimer();

  /// The app is in the foreground again: the timer restarts and what waits is sent now.
  void resume() {
    if (!_started || _timer != null) return;
    _startTimer();
    _flushIfQueued();
  }

  void _startTimer() => _timer ??= Timer.periodic(interval, (_) => onTick());

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// What the periodic timer runs: nothing at all while the queue is empty.
  @visibleForTesting
  Future<void> onTick() => _flushIfQueued();

  Future<void> _flushIfQueued() async {
    if (_pendingCount == 0) return;
    if (_running) {
      // A pass is running (it may have started offline): run one more right after it.
      _flushAgain = true;
      return;
    }
    await syncNow();
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
        // The count is set to what is really left (corrupt lines dropped, appends meanwhile kept).
        await AnalyticsQueueLock.run(() async {
          _pendingCount = await _returnToQueueInIsolate(pending, sending);
        });
      }
    } catch (_) {
      // Best effort: the events stay on disk for the next pass.
    } finally {
      _running = false;
      _setSyncing(false);
      if (_flushAgain) {
        _flushAgain = false;
        unawaited(_flushIfQueued());
      }
    }
  }

  void _setSyncing(bool value) {
    if (_isSyncing == value) return;
    _isSyncing = value;
    notifyListeners();
  }

  Future<void> _upload(String pending, String sending) async {
    final events = await AnalyticsQueueLock.run(() => _takeQueueInIsolate(pending, sending));
    for (var i = 0; i < events.length; i += batchSize) {
      final batch = events.sublist(i, i + batchSize > events.length ? events.length : i + batchSize);
      try {
        await _remote.sendBatch(batch);
      } catch (_) {
        return; // The rest waits for the next pass.
      }
      final sent = {for (final e in batch) e.clientId};
      await AnalyticsQueueLock.run(() async {
        await _removeSentInIsolate(sending, sent);
        _pendingCount = math.max(0, _pendingCount - batch.length);
      });
    }
  }
}

// Top-level, so the closures sent to the isolate capture only their arguments, never the service.
Future<int> _countInIsolate(String pending, String sending) =>
    Isolate.run(() => _countEvents(pending) + _countEvents(sending));

Future<List<AnalyticsEvent>> _takeQueueInIsolate(String pending, String sending) =>
    Isolate.run(() => _takeQueue(pending, sending));

Future<int> _returnToQueueInIsolate(String pending, String sending) =>
    Isolate.run(() => _returnToQueue(pending, sending));

Future<void> _removeSentInIsolate(String sending, Set<String> sent) =>
    Isolate.run(() => _removeSent(sending, sent));

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

/// Puts whatever is in `.sending` back at the end of `pending.jsonl`. Returns how many events
/// are then queued.
int _returnToQueue(String pending, String sending) {
  final file = File(sending);
  if (file.existsSync()) {
    final text = file.readAsStringSync();
    if (text.trim().isNotEmpty) {
      File(pending).writeAsStringSync(text.endsWith('\n') ? text : '$text\n', mode: FileMode.append, flush: true);
    }
    file.deleteSync();
  }
  return _countEvents(pending);
}

/// Non-empty lines of [path]; 0 when the file does not exist.
int _countEvents(String path) {
  final file = File(path);
  if (!file.existsSync()) return 0;
  return file.readAsLinesSync().where((line) => line.trim().isNotEmpty).length;
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
