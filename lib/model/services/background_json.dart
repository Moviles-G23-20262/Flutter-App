import 'dart:convert';
import 'dart:isolate';

/// Decoding and mapping JSON is CPU work that runs on the thread that draws the UI. For a long
/// answer (every listing, a long chat) that is enough to freeze scrolling and typing on a
/// mid-range phone, so big answers are handled in a background isolate (`Isolate.run`).
///
/// Starting an isolate also costs a few milliseconds, so small answers, which are most of them,
/// stay on the UI thread.

/// Answers with at least this many characters (about 50 KB) are decoded in an isolate.
const int backgroundDecodeThreshold = 50 * 1024;

/// Lists with at least this many items are mapped to entities in an isolate.
const int backgroundParseThreshold = 100;

/// `jsonDecode(text)`, in a background isolate when [text] is long.
Future<Object?> decodeJson(String text, {int threshold = backgroundDecodeThreshold}) {
  if (text.length < threshold) return Future.value(jsonDecode(text));
  return Isolate.run(() => jsonDecode(text), debugName: 'decode-json');
}

/// Maps a decoded JSON list with [parse], in a background isolate when the list is long.
///
/// [parse] must be a top-level function (like `materialFromJson`): it runs in the other isolate,
/// and the entities it builds are copied back.
Future<List<T>> parseListInBackground<T>(
  Object? json,
  T Function(Map<String, dynamic> item) parse, {
  int threshold = backgroundParseThreshold,
}) {
  final items = json as List<dynamic>;
  List<T> map() => [for (final item in items) parse(item as Map<String, dynamic>)];
  if (items.length < threshold) return Future.value(map());
  return Isolate.run(map, debugName: 'parse-json-list');
}
