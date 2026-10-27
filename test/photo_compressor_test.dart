import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_front_end/core/isolates/photo_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  img.fillRect(image, x1: 0, y1: 0, x2: width ~/ 2, y2: height ~/ 2, color: img.ColorRgb8(220, 40, 40));
  return Uint8List.fromList(img.encodePng(image));
}

img.Image _decode(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  late Directory documents;

  setUp(() => documents = Directory.systemTemp.createTempSync('photo_compressor'));
  tearDown(() => documents.deleteSync(recursive: true));

  Future<Directory> docs() async => documents;

  group('compressPhotoBytes', () {
    test('a landscape photo gets 1080 px on its long side and keeps its proportions', () async {
      final result = await compressPhotoBytes([_png(2400, 1200)], documents: docs);

      final out = _decode(result.single.bytes);
      expect(out.width, 1080);
      expect(out.height, 540);
    });

    test('a portrait photo is limited by its height', () async {
      final result = await compressPhotoBytes([_png(900, 2700)], documents: docs);

      final out = _decode(result.single.bytes);
      expect(out.height, 1080);
      expect(out.width, 360);
    });

    test('a small photo is never enlarged', () async {
      final result = await compressPhotoBytes([_png(300, 200)], documents: docs);

      final out = _decode(result.single.bytes);
      expect((out.width, out.height), (300, 200));
    });

    test('the result is a JPEG, smaller than the original, saved in pending_photos/', () async {
      final original = _png(2400, 1200);

      final result = await compressPhotoBytes([original], documents: docs);

      final photo = result.single;
      expect(photo.path, startsWith('${documents.path}${Platform.pathSeparator}pending_photos${Platform.pathSeparator}'));
      expect(photo.path, endsWith('.jpg'));
      expect(File(photo.path).readAsBytesSync(), photo.bytes);
      expect(photo.bytes.take(2), [0xFF, 0xD8]); // JPEG start-of-image marker
      expect(photo.bytes.length, lessThan(original.length * 2));
    });

    test('keeps the order of the photos and gives each one its own file', () async {
      final result = await compressPhotoBytes([_png(2000, 1000), _png(100, 400), _png(500, 500)], documents: docs);

      expect(result.map((p) => _decode(p.bytes).width), [1080, 100, 500]);
      expect(result.map((p) => p.path).toSet(), hasLength(3));
    });

    test('two runs never overwrite each other\'s photos', () async {
      final first = await compressPhotoBytes([_png(200, 200)], documents: docs);
      final second = await compressPhotoBytes([_png(200, 200)], documents: docs);

      expect(first.single.path, isNot(second.single.path));
      expect(File(first.single.path).existsSync(), isTrue);
      expect(File(second.single.path).existsSync(), isTrue);
    });

    test('bytes that are not an image are saved as they are instead of blocking the listing', () async {
      final junk = Uint8List.fromList([1, 2, 3, 4, 5]);

      final result = await compressPhotoBytes([junk], documents: docs);

      expect(result.single.bytes, junk);
      expect(File(result.single.path).readAsBytesSync(), junk);
    });

    test('an empty list does nothing', () async {
      expect(await compressPhotoBytes(const [], documents: docs), isEmpty);
    });

    test('the UI isolate keeps running while a big photo is compressed', () async {
      final big = _png(4000, 3000);
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 2), (_) => ticks++);

      final pending = compressPhotoBytes([big], documents: docs);
      await pending;
      timer.cancel();

      // Done on the main isolate, the timer could not have fired until the work ended.
      expect(ticks, greaterThan(0));
    });
  });

  group('compressPhotoFiles', () {
    test('reads the photos from their paths and compresses them the same way', () async {
      final source = File('${documents.path}/camera.png')..writeAsBytesSync(_png(3000, 1500));

      final result = await compressPhotoFiles([source.path], documents: docs);

      expect(_decode(result.single.bytes).width, 1080);
      expect(result.single.path, contains('pending_photos'));
      expect(source.existsSync(), isTrue); // the original is left alone
    });

    test('a path that does not exist fails with a FileSystemException', () async {
      expect(
        compressPhotoFiles(['${documents.path}/missing.jpg'], documents: docs),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('deleteCompressedPhotos', () {
    test('deletes the files and ignores the ones already gone', () async {
      final result = await compressPhotoBytes([_png(100, 100), _png(100, 100)], documents: docs);
      File(result.first.path).deleteSync();

      await deleteCompressedPhotos(result.map((p) => p.path));

      expect(File(result.first.path).existsSync(), isFalse);
      expect(File(result.last.path).existsSync(), isFalse);
    });
  });
}
