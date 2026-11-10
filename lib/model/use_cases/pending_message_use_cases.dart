import '../data_sources/local/outbox_store.dart';
import '../entities/pending_items.dart';
import '../services/outbox_sync_service.dart';

/// A chat message written offline-first: saved in the outbox, then sent by the sync service.
/// The returned future completes when that send attempt is over (sent or still waiting).
class QueueMessageUseCase {
  final OutboxStore outbox;
  final OutboxSyncService sync;
  QueueMessageUseCase(this.outbox, this.sync);

  Future<PendingMessage> execute({
    required String ownerId,
    required String chatRoomId,
    required String content,
  }) =>
      outbox.enqueueMessage(ownerId: ownerId, chatRoomId: chatRoomId, content: content);

  /// Sends what is waiting now; completes when the flush is over.
  Future<void> send() => sync.flush();
}

/// Retries a refused chat message by moving it back to `waiting` and flushing the outbox.
class RetryPendingMessageUseCase {
  final OutboxStore outbox;
  final OutboxSyncService sync;
  RetryPendingMessageUseCase(this.outbox, this.sync);

  Future<void> execute(String messageId) async {
    await outbox.retry(PendingKind.message, messageId);
    await sync.flush();
  }
}

/// Deletes a refused (or queued) chat message and lets later messages in the room sync.
class DeletePendingMessageUseCase {
  final OutboxStore outbox;
  final OutboxSyncService sync;
  DeletePendingMessageUseCase(this.outbox, this.sync);

  Future<void> execute(String messageId) async {
    await outbox.discard(PendingKind.message, messageId);
    await sync.flush();
  }
}

/// [ownerId]'s messages of [chatRoomId] still in the outbox, oldest first.
class GetPendingMessagesUseCase {
  final OutboxStore outbox;
  GetPendingMessagesUseCase(this.outbox);

  Future<List<PendingMessage>> execute(String ownerId, String chatRoomId) =>
      outbox.messages(ownerId, chatRoomId: chatRoomId);
}

/// How many items wait in the outbox, now and after every change.
class WatchPendingCountUseCase {
  final OutboxStore outbox;
  WatchPendingCountUseCase(this.outbox);

  Stream<int> execute() => outbox.pendingCountStream;
}
