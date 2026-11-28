import '../entities/exchange_entity.dart';
import '../entities/material_entity.dart';
import '../entities/pending_items.dart';

/// Exchange steps done without a connection: saved on the phone and sent by the sync service.
abstract class PendingActionRepository {
  Future<PendingAction> queueCompletion({
    required String ownerId,
    required String exchangeId,
    MaterialConditionEnum? receivedCondition,
    NewRating? rating,
  });

  Future<PendingAction> queueRating({required String ownerId, required NewRating rating});

  Future<PendingAction> queueMeetingProposal({
    required String ownerId,
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<PendingAction> queuePriceUpdate({
    required String ownerId,
    required String materialId,
    required double newPrice,
    String? listingTitle,
  });

  /// Attempts delivery. Returns the stored step if it is still waiting or was refused.
  Future<PendingAction?> deliver(PendingAction action);

  /// [ownerId]'s queued steps now, and again after every change (queued, sent, refused, discarded).
  Stream<List<PendingAction>> watch(String ownerId);

  Future<void> discard(String actionId);
}
