import 'dart:convert';
import 'dart:isolate';

/// CPU-bound JSON serialization and deserialization offloaded to a background isolate.
///
/// Running encode/decode with [Isolate.run] avoids jank and frame drops on the UI isolate
/// when dealing with large catalog listings or long chat histories.
class ResponseCodec {
  /// Encodes [data] into a JSON string within a background isolate.
  static Future<String> encode(dynamic data) {
    return Isolate.run(() => jsonEncode(data));
  }

  /// Decodes [jsonString] into a dynamic structure (Map or List) within a background isolate.
  static Future<dynamic> decode(String jsonString) {
    return Isolate.run(() => jsonDecode(jsonString));
  }

  /// Decodes [jsonString] into a Map<String, dynamic> within a background isolate.
  static Future<Map<String, dynamic>> decodeMap(String jsonString) {
    return Isolate.run(() => jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Decodes [jsonString] into a List<dynamic> within a background isolate.
  static Future<List<dynamic>> decodeList(String jsonString) {
    return Isolate.run(() => jsonDecode(jsonString) as List<dynamic>);
  }
}
