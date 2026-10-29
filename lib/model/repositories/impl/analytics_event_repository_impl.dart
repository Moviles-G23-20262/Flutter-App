import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../entities/analytics_event.dart';
import '../analytics_event_repository.dart';

/// Serializes every read and write of the queue files in this app.
///
/// Appends ([AnalyticsEventRepositoryImpl.track]) and the sync's rename / rewrite / delete run in
/// different isolates. Without this, an append that opened `pending.jsonl` just before the swap
/// could write into a `.sending` file that is deleted right after, and the event would be lost.
/// The upload itself runs outside the lock, so tracking never waits for the network.
class AnalyticsQueueLock {
  AnalyticsQueueLock._();

  static Future<void> _last = Future.value();

  /// Runs [action] after every file operation queued before it.
  static Future<T> run<T>(Future<T> Function() action) {
    final result = _last.then((_) => action());
    _last = result.then((_) {}, onError: (_) {});
    return result;
  }
}

/// Queues analytics events on disk instead of sending them. Each event is one JSON line
/// appended to [fileName]; `AnalyticsSyncService` uploads and removes them later.
class AnalyticsEventRepositoryImpl implements AnalyticsEventRepository {
  static const fileName = 'pending.jsonl';

  final Future<Directory> Function() _directory;

  AnalyticsEventRepositoryImpl({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  @override
  Future<void> track(AnalyticsEvent event) async {
    final path = p.join((await _directory()).path, fileName);
    // Encoding and the disk write run off the UI thread.
    await AnalyticsQueueLock.run(() => Isolate.run(() {
          final file = File(path);
          file.writeAsStringSync('${jsonEncode(event.toJson())}\n', mode: FileMode.append, flush: true);
        }));
  }
}
