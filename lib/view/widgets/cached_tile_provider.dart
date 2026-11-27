import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/cache/map_tile_cache_manager.dart';

/// Map tiles through `cached_network_image` instead of a plain download each time.
///
/// Each tile is an image at a URL, so [CachedNetworkImageProvider] handles it like any other
/// photo: decoded tiles stay in Flutter's in-memory image cache, and the downloaded files stay on
/// disk ([MapTileCacheManager], 30 days). Reopening the meeting point map draws the campus at once,
/// and the parts already seen still show without a connection.
class CachedTileProvider extends TileProvider {
  final BaseCacheManager cacheManager;

  CachedTileProvider({super.headers, BaseCacheManager? cacheManager})
      : cacheManager = cacheManager ?? MapTileCacheManager.instance;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => CachedNetworkImageProvider(
        getTileUrl(coordinates, options),
        // flutter_map puts the User-Agent that OpenStreetMap requires into [headers].
        headers: headers,
        cacheManager: cacheManager,
      );
}
