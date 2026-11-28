import 'dart:io';

import 'package:path/path.dart' as p;

import '../../app/network/api_client.dart';
import '../entities/pending_items.dart';
import '../services/outbox_sync_service.dart';
import 'marketplace_remote_data_source.dart';
import 'meetup_remote_data_source.dart';

/// Delivers queued items through the marketplace API. Errors are left as they come
/// ([NetworkException] / [ApiException]) so the sync service can classify them.
class RemoteOutboxSender implements MeetingProposalLookup {
  final MarketplaceRemoteDataSource remote;
  final MeetupRemoteDataSource meetups;

  RemoteOutboxSender(this.remote, this.meetups);

  @override
  Future<void> sendMessage(PendingMessage message) async {
    await remote.sendMessage(
      message.chatRoomId,
      message.content,
      id: message.id,
      clientCreatedAt: message.createdAt,
    );
  }

  @override
  Future<String> uploadPhoto(String path) async =>
      remote.uploadImage(bytes: await File(path).readAsBytes(), filename: p.basename(path));

  @override
  Future<void> createListing(Map<String, dynamic> body) async {
    // Only the 2xx matters to the queue; the published listing is read again from `GET /materials`.
    await remote.createMaterialRaw(body);
  }

  @override
  Future<void> sendAction(PendingAction action) async {
    final body = action.payload;
    switch (action.kind) {
      case PendingActionKind.completeExchange:
        try {
          await remote.completeExchange(
            body['exchangeId'] as String,
            receivedCondition: body['receivedCondition'] as String?,
          );
        } on ApiException catch (e) {
          if (e.statusCode != 409 || e.message != 'This exchange is already completed') rethrow;
        }
      case PendingActionKind.rate:
        try {
          await remote.createRating(body);
        } on ApiException catch (e) {
          if (e.statusCode == 409 && e.message == 'This user already rated this exchange') return;
          if (e.statusCode != 400 || e.message != 'You can rate each other once the exchange is completed') rethrow;
          final exchanges = await remote.getExchanges();
          final exchange = exchanges.where((item) => item.id == action.groupId).firstOrNull;
          if (exchange != null && (exchange.isPending || exchange.isCompleted)) {
            throw const OutboxActionDeferred();
          }
          throw const ApiException(400, 'This exchange is no longer available to rate');
        }
      case PendingActionKind.proposeMeeting:
        await meetups.createProposal({...body, 'clientId': action.id});
      case PendingActionKind.updateListingPrice:
        final rawPrice = body['price'];
        final price = rawPrice is num ? rawPrice.toDouble() : double.parse(rawPrice.toString());
        await remote.updateMaterialPrice(body['materialId'] as String, price);
    }
  }

  @override
  Future<bool> wasMeetingProposalDelivered(PendingAction action) async {
    final proposals = await meetups.getProposals(action.groupId);
    return proposals.any((proposal) => proposal.id == action.id && proposal.proposerId == action.ownerId);
  }
}
