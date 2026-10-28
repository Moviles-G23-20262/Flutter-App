import '../entities/new_listing_data.dart';
import '../entities/pending_items.dart';
import '../repositories/pending_listing_repository.dart';

/// Saves a listing on the phone because it could not be published now.
class QueueListingUseCase {
  final PendingListingRepository repository;
  QueueListingUseCase(this.repository);

  Future<PendingListing> execute({
    required String ownerId,
    required NewListingData data,
    required List<String> photoPaths,
  }) =>
      repository.queue(ownerId: ownerId, data: data, photoPaths: photoPaths);
}

/// The signed-in user's queued listings, updated whenever the outbox changes.
class WatchPendingListingsUseCase {
  final PendingListingRepository repository;
  WatchPendingListingsUseCase(this.repository);

  Stream<List<PendingListing>> execute(String ownerId) => repository.watch(ownerId);
}

/// The user gives up on a listing that is waiting or that the server refused.
class DiscardPendingListingUseCase {
  final PendingListingRepository repository;
  DiscardPendingListingUseCase(this.repository);

  Future<void> execute(String listingId) => repository.discard(listingId);
}
