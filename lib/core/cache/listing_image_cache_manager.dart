import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache of the remote photos (listings, chat, history), used by `CachedPhoto`.
///
/// It replaces the library's default manager so its limits are explicit and can be explained:
///
/// - [stalePeriod] = 14 days. A listing photo never changes: a new photo is a new Blob URL (a
///   random UUID in the path), so a cached file is never "wrong", only unused. Listings are
///   short-lived (BQ11 measures days to sell), so after two weeks nobody opens that photo again
///   and the file can go. Inside the period the photo shows with no network at all (offline).
/// - [maxNrOfCacheObjects] = 150. The app compresses photos to at most 1600 px (about 150-400 KB
///   each), so 150 files are roughly 20-60 MB of disk: enough for several screens of the
///   marketplace, chats and history, small enough not to weigh on a student's phone. Past the
///   limit the least recently used files are removed first.
///
/// Memory is bounded separately: `main()` caps Flutter's `ImageCache` (100 images / 50 MB) and
/// `CachedPhoto` passes `memCacheWidth` / `memCacheHeight` so a list thumbnail is decoded at its
/// on-screen size, never at the size of the original file.
abstract final class ListingImageCacheManager {
  static const String key = 'campusSwapListingImages';
  static const Duration stalePeriod = Duration(days: 14);
  static const int maxNrOfCacheObjects = 150;

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
    ),
  );
}
