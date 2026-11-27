import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for the OpenStreetMap tiles of the meeting point map, kept apart from the listing
/// photos ([ListingImageCacheManager]) so neither pushes the other out.
///
/// The campus fits in a few hundred tiles across the zoom levels the map allows (14 to 19), and
/// the streets around it rarely change, so tiles are kept for 30 days. OpenStreetMap's tile
/// policy also asks apps to cache tiles instead of downloading them again.
abstract final class MapTileCacheManager {
  static const String key = 'campusSwapMapTiles';
  static const Duration stalePeriod = Duration(days: 30);
  static const int maxNrOfCacheObjects = 1000;

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
    ),
  );
}
