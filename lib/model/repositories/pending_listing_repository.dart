import '../entities/new_listing_data.dart';
import '../entities/pending_items.dart';

/// Listings created without a connection: saved on the phone and published by the sync service.
abstract class PendingListingRepository {
  /// Saves [data] (its text and choices) with the already compressed photos at [photoPaths].
  Future<PendingListing> queue({
    required String ownerId,
    required NewListingData data,
    required List<String> photoPaths,
  });

  /// [ownerId]'s queued listings now (oldest first), and again after every change: queued,
  /// published, refused or discarded.
  Stream<List<PendingListing>> watch(String ownerId);

  /// Moves a refused listing back to waiting and asks the sync service to try publishing it again.
  Future<void> retry(String listingId);

  /// The user gives up on a listing; its photos are deleted from the phone.
  Future<void> discard(String listingId);
}
