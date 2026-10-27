/// Where a queued item is: still waiting to be sent, or refused by the server.
/// A sent item is deleted from the outbox, so it has no status.
enum PendingStatus { waiting, refused }

/// A chat message saved on the phone and not confirmed by the server yet.
class PendingMessage {
  /// Client UUID, created when the message is queued.
  final String id;
  final String ownerId;
  final String chatRoomId;
  final String content;
  final DateTime createdAt;
  final PendingStatus status;
  final int attempts;

  /// Why the last attempt failed: the server's reason when refused.
  final String? lastError;

  const PendingMessage({
    required this.id,
    required this.ownerId,
    required this.chatRoomId,
    required this.content,
    required this.createdAt,
    this.status = PendingStatus.waiting,
    this.attempts = 0,
    this.lastError,
  });
}

/// A new listing saved on the phone and not published yet. Its photos are files in the app's
/// documents folder until they are uploaded.
class PendingListing {
  final String id;
  final String ownerId;

  /// The `POST /materials` body without `imageUrls`, which are known only after the upload.
  final Map<String, dynamic> payload;
  final List<String> photoPaths;
  final DateTime createdAt;
  final PendingStatus status;
  final int attempts;
  final String? lastError;

  const PendingListing({
    required this.id,
    required this.ownerId,
    required this.payload,
    required this.photoPaths,
    required this.createdAt,
    this.status = PendingStatus.waiting,
    this.attempts = 0,
    this.lastError,
  });

  String get title => payload['title'] as String? ?? '';
}

/// The exchange steps that can be done offline.
enum PendingActionKind { completeExchange, rate, proposeMeeting }

/// An exchange step saved on the phone and not confirmed by the server yet.
class PendingAction {
  final String id;
  final String ownerId;
  final PendingActionKind kind;

  /// What the step belongs to: the exchange for a completion or a rating, the chat for a
  /// meeting proposal. Steps of one group are sent in order, and a refused one holds back the
  /// rest, so a rating never reaches the server before its completion.
  final String groupId;

  /// The request body for the server.
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final PendingStatus status;
  final int attempts;
  final String? lastError;

  const PendingAction({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.groupId,
    required this.payload,
    required this.createdAt,
    this.status = PendingStatus.waiting,
    this.attempts = 0,
    this.lastError,
  });

  /// When the proposed meeting starts; `null` for other steps.
  DateTime? get meetingStartsAt =>
      kind == PendingActionKind.proposeMeeting ? DateTime.tryParse(payload['startsAt'] as String? ?? '') : null;
}
