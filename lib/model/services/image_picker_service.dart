import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// The phone's camera and gallery through image_picker.
/// The photo is downscaled and kept in memory only; nothing is written to storage.
class ImagePickerService {
  final ImagePicker _picker;

  ImagePickerService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  /// The photo bytes, or null if the user cancelled. Throws if the camera or gallery
  /// cannot be used (e.g. permission denied); the caller decides what to tell the user.
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    return file?.readAsBytes();
  }
}
