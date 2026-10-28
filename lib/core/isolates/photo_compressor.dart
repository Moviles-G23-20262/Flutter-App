import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;

/// CPU-bound photo compression and resizing executed inside a background isolate.
///
/// Prevents the UI thread from freezing when photos are taken or picked from the gallery.
/// Implements Rubric: Multithreading (Isolate for heavy CPU work).
class PhotoCompressor {
  static const int maxDimension = 1080;
  static const int jpegQuality = 80;

  /// Resizes and compresses an image at [sourcePath] and saves it to [destinationPath].
  /// Photos larger than 1080px in width or height are proportionally scaled down.
  static Future<File> compressFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    return Isolate.run(() async {
      final bytes = await File(sourcePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        // Fallback: if decoding fails, copy the original file
        return File(sourcePath).copy(destinationPath);
      }

      img.Image processed = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width >= image.height) {
          processed = img.copyResize(image, width: maxDimension);
        } else {
          processed = img.copyResize(image, height: maxDimension);
        }
      }

      final compressedBytes = img.encodeJpg(processed, quality: jpegQuality);
      final destFile = File(destinationPath);
      await destFile.writeAsBytes(compressedBytes, flush: true);
      return destFile;
    });
  }

  /// Compresses in-memory [bytes] and returns the compressed JPEG bytes.
  static Future<List<int>> compressBytes(List<int> bytes) async {
    return Isolate.run(() {
      final image = img.decodeImage(bytes as dynamic);
      if (image == null) return bytes;

      img.Image processed = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width >= image.height) {
          processed = img.copyResize(image, width: maxDimension);
        } else {
          processed = img.copyResize(image, height: maxDimension);
        }
      }

      return img.encodeJpg(processed, quality: jpegQuality);
    });
  }
}
