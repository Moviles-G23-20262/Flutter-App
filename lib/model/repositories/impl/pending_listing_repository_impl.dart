import 'dart:async';

import '../../../core/isolates/photo_compressor.dart';
import '../../data_sources/local/outbox_store.dart';
import '../../dto/marketplace_models.dart';
import '../../entities/new_listing_data.dart';
import '../../entities/pending_items.dart';
import '../../services/outbox_sync_service.dart';
import '../pending_listing_repository.dart';

class PendingListingRepositoryImpl implements PendingListingRepository {
  final OutboxStore store;

  /// Asked to flush after every new listing, which also starts its retry timer.
  final OutboxSyncService? sync;

  PendingListingRepositoryImpl(this.store, {this.sync});

  @override
  Future<PendingListing> queue({
    required String ownerId,
    required NewListingData data,
    required List<String> photoPaths,
  }) async {
    final listing = await store.enqueueListing(
      ownerId: ownerId,
      payload: newListingToJson(data),
      photoPaths: photoPaths,
    );
    sync?.flush();
    return listing;
  }

  @override
  Stream<List<PendingListing>> watch(String ownerId) {
    late final StreamController<List<PendingListing>> controller;
    StreamSubscription<void>? changes;
    Future<void> emit() async {
      try {
        final listings = await store.listings(ownerId);
        if (!controller.isClosed) controller.add(listings);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<PendingListing>>(
      onListen: () {
        changes = store.changes.listen((_) => emit());
        emit();
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> discard(String listingId) async {
    final photos = await store.photoPathsOf(listingId);
    await store.discard(PendingKind.listing, listingId);
    await deleteCompressedPhotos(photos);
  }
}
