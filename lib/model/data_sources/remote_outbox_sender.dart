import 'dart:io';

import 'package:path/path.dart' as p;

import '../entities/pending_items.dart';
import '../services/outbox_sync_service.dart';
import 'marketplace_remote_data_source.dart';
import 'meetup_remote_data_source.dart';

/// Delivers queued items through the marketplace API. Errors are left as they come
/// ([NetworkException] / [ApiException]) so the sync service can classify them.
class RemoteOutboxSender implements OutboxSender {
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

  /// Uploads the photos (up to 3 at once; `Future.wait` keeps their order), then creates the listing.
  @override
  Future<void> sendListing(PendingListing listing) async {
    final imageUrls = <String>[];
    for (var i = 0; i < listing.photoPaths.length; i += 3) {
      final batch = listing.photoPaths.skip(i).take(3);
      imageUrls.addAll(await Future.wait(batch.map(_upload)));
    }
    await remote.createMaterial({
      'id': listing.id,
      ...listing.payload,
      'imageUrls': imageUrls,
    });
  }

  @override
  Future<void> sendAction(PendingAction action) async {
    final body = action.payload;
    switch (action.kind) {
      case PendingActionKind.completeExchange:
        await remote.completeExchange(
          body['exchangeId'] as String,
          receivedCondition: body['receivedCondition'] as String?,
        );
      case PendingActionKind.rate:
        await remote.createRating(body);
      case PendingActionKind.proposeMeeting:
        await meetups.createProposal(body);
    }
  }

  Future<String> _upload(String path) async =>
      remote.uploadImage(bytes: await File(path).readAsBytes(), filename: p.basename(path));
}
