import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Longest side of a listing photo after compression.
const int maxPhotoSide = 1080;
const int photoJpegQuality = 80;

/// Folder (inside the documents folder) that holds the compressed photos of listings that are
/// waiting to be published. They stay there until the listing is sent or discarded.
const String pendingPhotosFolder = 'pending_photos';

/// A compressed photo: the file in [pendingPhotosFolder] and the same bytes in memory, ready to upload.
class CompressedPhoto {
  final String path;
  final Uint8List bytes;

  const CompressedPhoto({required this.path, required this.bytes});
}

/// Takes the photos as bytes and returns them compressed and saved on the phone.
typedef PhotoCompressor = Future<List<CompressedPhoto>> Function(List<Uint8List> photos);

/// Reads the photos at [sourcePaths], shrinks each one so that its longest side is at most
/// [maxSide] (smaller photos are never enlarged), encodes it as JPEG and saves the result in
/// `<documents>/pending_photos/`. Returns them in the same order.
///
/// Reading, decoding, resizing, encoding and writing all happen in one `Isolate.run`, so the UI
/// thread only awaits: frames keep being drawn while a photo is processed. The caller gets back
/// the compressed bytes (moved between isolates, not copied).
///
/// A file that cannot be read fails with [FileSystemException]. A file that is not a
/// decodable image is saved as it is, so an odd format never blocks publishing.
Future<List<CompressedPhoto>> compressPhotoFiles(
  List<String> sourcePaths, {
  Future<Directory> Function()? documents,
  int maxSide = maxPhotoSide,
  int quality = photoJpegQuality,
}) async {
  final folder = await _outputFolder(documents);
  final stamp = _stamp();
  final results = await Isolate.run(
    () => _compressAll([for (final path in sourcePaths) File(path).readAsBytesSync()], folder, stamp, maxSide, quality),
  );
  return _asPhotos(results);
}

/// Same as [compressPhotoFiles] for photos that are only in memory (what the camera and the
/// gallery picker give). The bytes travel to the isolate once.
Future<List<CompressedPhoto>> compressPhotoBytes(
  List<Uint8List> photos, {
  Future<Directory> Function()? documents,
  int maxSide = maxPhotoSide,
  int quality = photoJpegQuality,
}) async {
  final folder = await _outputFolder(documents);
  final stamp = _stamp();
  final results = await Isolate.run(() => _compressAll(photos, folder, stamp, maxSide, quality));
  return _asPhotos(results);
}

/// Deletes compressed photos that are no longer needed (the listing was published or discarded).
/// A file that is already gone is not an error.
Future<void> deleteCompressedPhotos(Iterable<String> paths) async {
  for (final path in paths) {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already deleted.
    }
  }
}

Future<String> _outputFolder(Future<Directory> Function()? documents) async =>
    p.join((await (documents ?? getApplicationDocumentsDirectory)()).path, pendingPhotosFolder);

/// Makes names unique across runs: two listings never overwrite each other's photos.
String _stamp() => '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(16)}';

List<CompressedPhoto> _asPhotos(List<(String, Uint8List)> results) =>
    [for (final (path, bytes) in results) CompressedPhoto(path: path, bytes: bytes)];

/// Runs inside the isolate: only plain values come in and go out.
List<(String, Uint8List)> _compressAll(List<Uint8List> photos, String folder, String stamp, int maxSide, int quality) {
  Directory(folder).createSync(recursive: true);
  final results = <(String, Uint8List)>[];
  for (var i = 0; i < photos.length; i++) {
    final bytes = _compressOne(photos[i], maxSide, quality);
    final path = p.join(folder, '$stamp-${i + 1}.jpg');
    File(path).writeAsBytesSync(bytes, flush: true);
    results.add((path, bytes));
  }
  return results;
}

Uint8List _compressOne(Uint8List original, int maxSide, int quality) {
  img.Image? image;
  try {
    image = img.decodeImage(original);
  } on Object {
    image = null;
  }
  if (image == null) return original;

  // Phones store the rotation in the EXIF data; apply it before it is lost in the re-encode.
  image = img.bakeOrientation(image);
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}
