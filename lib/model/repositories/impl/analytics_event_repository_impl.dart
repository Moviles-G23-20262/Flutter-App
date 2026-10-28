import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../entities/analytics_event.dart';
import '../analytics_event_repository.dart';

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
    await Isolate.run(() {
      final file = File(path);
      file.writeAsStringSync('${jsonEncode(event.toJson())}\n', mode: FileMode.append, flush: true);
    });
  }
}
