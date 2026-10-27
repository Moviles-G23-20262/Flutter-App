import 'dart:async';

import '../../data_sources/local/outbox_store.dart';
import '../../dto/marketplace_models.dart';
import '../../entities/exchange_entity.dart';
import '../../entities/material_entity.dart';
import '../../entities/pending_items.dart';
import '../../services/outbox_sync_service.dart';
import '../pending_action_repository.dart';

class PendingActionRepositoryImpl implements PendingActionRepository {
  final OutboxStore store;

  /// Asked to flush after every new step, so it goes out at once if the connection is back.
  final OutboxSyncService? sync;

  PendingActionRepositoryImpl(this.store, {this.sync});

  @override
  Future<PendingAction> queueCompletion({
    required String ownerId,
    required String exchangeId,
    MaterialConditionEnum? receivedCondition,
  }) =>
      _queue(ownerId, PendingActionKind.completeExchange, exchangeId, {
        'exchangeId': exchangeId,
        if (receivedCondition != null) 'receivedCondition': receivedCondition.name,
      });

  @override
  Future<PendingAction> queueRating({required String ownerId, required NewRating rating}) =>
      _queue(ownerId, PendingActionKind.rate, rating.exchangeId, newRatingToJson(rating));

  @override
  Future<PendingAction> queueMeetingProposal({
    required String ownerId,
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) =>
      _queue(
        ownerId,
        PendingActionKind.proposeMeeting,
        chatRoomId,
        meetingProposalToJson(
          chatRoomId: chatRoomId,
          meetingPointId: meetingPointId,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );

  Future<PendingAction> _queue(
    String ownerId,
    PendingActionKind kind,
    String groupId,
    Map<String, dynamic> payload,
  ) async {
    final action = await store.enqueueAction(ownerId: ownerId, kind: kind, groupId: groupId, payload: payload);
    sync?.flush();
    return action;
  }

  @override
  Stream<List<PendingAction>> watch(String ownerId) {
    late final StreamController<List<PendingAction>> controller;
    StreamSubscription<void>? changes;
    Future<void> emit() async {
      try {
        final actions = await store.actions(ownerId);
        if (!controller.isClosed) controller.add(actions);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<PendingAction>>(
      onListen: () {
        changes = store.changes.listen((_) => emit());
        emit();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> discard(String actionId) => store.discard(PendingKind.action, actionId);
}
