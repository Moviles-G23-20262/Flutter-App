import '../entities/exchange_entity.dart';
import '../entities/material_entity.dart';
import '../entities/meetup_entities.dart';
import '../entities/pending_items.dart';
import '../exceptions/data_exceptions.dart';
import '../repositories/pending_action_repository.dart';
import 'marketplace_use_cases.dart';

/// The buyer confirmed the exchange without a connection: saved and sent later.
class QueueExchangeCompletionUseCase {
  final PendingActionRepository repository;
  QueueExchangeCompletionUseCase(this.repository);

  Future<PendingAction> execute({
    required String ownerId,
    required ExchangeEntity exchange,
    MaterialConditionEnum? receivedCondition,
  }) {
    if (!exchange.isPending) throw const DataException('This exchange is already closed.');
    return repository.queueCompletion(
      ownerId: ownerId,
      exchangeId: exchange.id,
      receivedCondition: receivedCondition,
    );
  }
}

/// A rating written without a connection: checked like an online one, then saved.
class QueueRatingUseCase {
  final PendingActionRepository repository;
  QueueRatingUseCase(this.repository);

  Future<PendingAction> execute({required String ownerId, required NewRating rating}) =>
      repository.queueRating(ownerId: ownerId, rating: RateUserUseCase.validated(rating));
}

/// A meeting proposal made without a connection. The sync service checks the time again before
/// sending it, since it may have passed by then.
class QueueMeetingProposalUseCase {
  final PendingActionRepository repository;
  QueueMeetingProposalUseCase(this.repository);

  Future<PendingAction> execute({
    required String ownerId,
    required String chatRoomId,
    required MeetingPointEntity zone,
    required FreeSlot slot,
    DateTime? now,
  }) {
    if (!slot.startsAt.isAfter(now ?? DateTime.now())) {
      throw const DataException('That time already passed. Pick another one.');
    }
    return repository.queueMeetingProposal(
      ownerId: ownerId,
      chatRoomId: chatRoomId,
      meetingPointId: zone.id,
      startsAt: slot.startsAt,
      endsAt: slot.endsAt,
    );
  }
}

/// The signed-in user's queued exchange steps, updated whenever the outbox changes.
class WatchPendingActionsUseCase {
  final PendingActionRepository repository;
  WatchPendingActionsUseCase(this.repository);

  Stream<List<PendingAction>> execute(String ownerId) => repository.watch(ownerId);
}

/// The user gives up on a step the server refused.
class DiscardPendingActionUseCase {
  final PendingActionRepository repository;
  DiscardPendingActionUseCase(this.repository);

  Future<void> execute(String actionId) => repository.discard(actionId);
}
