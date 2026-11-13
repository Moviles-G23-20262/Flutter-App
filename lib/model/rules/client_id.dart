import 'dart:math';

final Random _random = Random.secure();

/// A random (version 4) UUID, made on the phone: the client id of every queued item, listing and
/// analytics event, so a retry after a lost answer is recognised by the server.
String newClientId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// RFC 4122, like the server's `@IsUUID()` (class-validator): version 1 to 5 and variant 8, 9, a or b.
/// PostgreSQL accepts any 32 hex digits, but the validator does not, so a looser check here would
/// let through ids the server then answers with "must be a UUID".
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

/// Whether [value] is a UUID the server accepts. The server refuses anything else in an id (path,
/// query or body) with a 400 "uuid is expected", so an empty id, "guest" or a local placeholder
/// such as "temp-..." must never be sent.
bool isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

/// Shown instead of calling the server about an item it does not know yet (one made offline and
/// still waiting on the phone, or an id that is not a server UUID).
const String itemSyncingMessage =
    'This item is still syncing. Try again in a moment, once it has been published.';
