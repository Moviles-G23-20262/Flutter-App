import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../entities/new_listing_data.dart';

/// The photos of the unfinished listing, kept as files in the documents folder
/// (`listing_draft/<userId>/`) so the draft can name them by path and still have them after the
/// app is closed. Writing and reading the bytes runs in an isolate.
///
/// Losing a photo only means picking it again, so storage errors are swallowed.
class DraftPhotoStore {
  final Future<Directory> Function() _documents;

  DraftPhotoStore([Future<Directory> Function()? documents])
      : _documents = documents ?? getApplicationDocumentsDirectory;

  Future<String> _folder(String userId) async => p.join((await _documents()).path, 'listing_draft', userId);

  /// Makes the folder hold exactly [photos]: writes the ones it lacks, deletes the rest.
  /// Returns the path of every photo, in order. Only new photos travel to the isolate.
  Future<List<String>> sync(String userId, List<PendingImage> photos) async {
    final folder = await _folder(userId);
    try {
      final onDisk = <String, int>{};
      final dir = Directory(folder);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) onDisk[p.basename(entity.path)] = await entity.length();
        }
      }
      final keep = {for (final photo in photos) photo.filename};
      final toWrite = [
        for (final photo in photos)
          if (onDisk[photo.filename] != photo.bytes.length) (photo.filename, photo.bytes),
      ];
      final stale = [for (final name in onDisk.keys) if (!keep.contains(name)) name];
      if (toWrite.isNotEmpty || stale.isNotEmpty) {
        await Isolate.run(() {
          Directory(folder).createSync(recursive: true);
          for (final (name, bytes) in toWrite) {
            File(p.join(folder, name)).writeAsBytesSync(bytes, flush: true);
          }
          for (final name in stale) {
            File(p.join(folder, name)).deleteSync();
          }
        });
      }
      return [for (final photo in photos) p.join(folder, photo.filename)];
    } on Exception {
      return const [];
    }
  }

  /// The photos at [paths] that are still there. Paths outside this user's folder are ignored.
  Future<List<PendingImage>> read(String userId, List<String> paths) async {
    final folder = await _folder(userId);
    try {
      final inside = [for (final path in paths) if (p.isWithin(folder, path)) path];
      return await Isolate.run(() => [
            for (final path in inside)
              if (File(path).existsSync()) PendingImage(bytes: File(path).readAsBytesSync(), filename: p.basename(path)),
          ]);
    } on Exception {
      return const [];
    }
  }

  Future<void> deleteAll(String userId) async {
    try {
      final dir = Directory(await _folder(userId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Exception {
      // Leftover files are replaced by the next draft.
    }
  }
}
