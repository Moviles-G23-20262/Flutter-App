import 'dart:async';
import '../local/pending_listing_store.dart';
import '../local/pending_message_store.dart';

/// Central store for outbox items with reactive [Stream] updates.
///
/// Consumed by UI components like [chat_view.dart] and [home_screen.dart] to show real-time pending badges.
class OutboxStore {
  final PendingMessageStore messageStore;
  final PendingListingStore listingStore;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  OutboxStore({
    required this.messageStore,
    required this.listingStore,
  });

  /// Broadcast stream emitting the total count of pending outbox items for the active user.
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Refreshes and broadcasts the total pending count for [userId].
  Future<int> refreshPendingCount(String userId) async {
    final messageCount = await messageStore.countPending(userId);
    final listingCount = await listingStore.countPending(userId);
    final total = messageCount + listingCount;
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(total);
    }
    return total;
  }

  void dispose() {
    _pendingCountController.close();
  }
}
