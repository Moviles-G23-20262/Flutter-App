import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../core/cache/listing_image_cache_manager.dart';

/// Reusable cached image widget for listings and chat photos.
///
/// Implements EC14: Caches images in memory and local disk through [ListingImageCacheManager]
/// (150 files, 14 days; see that class for why).
/// If an image fails to load while offline or has never been downloaded, it gracefully renders
/// a category placeholder icon instead of a broken empty box or crash.
///
/// A photo is usually shown much smaller than it was uploaded. By default the decode size follows
/// the widget's size and the device pixel ratio. [memCacheWidth] and [maxWidthDiskCache] (both in
/// pixels, both optional) set the limits explicitly — feed thumbnails share
/// [thumbnailMemCacheWidth] (360 px) and [thumbnailDiskCacheWidth] (720 px) (MO5).
class CachedPhoto extends StatelessWidget {
  /// Shared decode & disk-cache limits for feed thumbnails across Home, Favorites,
  /// Seller Hub, and Seller Profile (MO5).
  static const int thumbnailMemCacheWidth = 360;
  static const int thumbnailDiskCacheWidth = 720;

  final String? imageUrl;
  final String? category;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Width in pixels the decoded image is limited to in the memory cache; null follows layout × DPR.
  final int? memCacheWidth;

  /// Width in pixels the image file is limited to in the disk cache; null keeps it as is.
  final int? maxWidthDiskCache;

  const CachedPhoto({
    super.key,
    required this.imageUrl,
    this.category,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.maxWidthDiskCache,
  });

  IconData _categoryIcon() {
    switch (category?.toUpperCase()) {
      case 'BOOKS':
        return Icons.menu_book_rounded;
      case 'CALCULATORS':
        return Icons.calculate_rounded;
      case 'LAB_EQUIPMENT':
        return Icons.science_rounded;
      case 'FURNITURE':
        return Icons.chair_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final iconColor = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      width: width,
      height: height,
      color: bg,
      alignment: Alignment.center,
      child: Icon(
        _categoryIcon(),
        color: iconColor.withValues(alpha: 0.6),
        size: (height != null && height! < 60) ? 20 : 36,
      ),
    );
  }

  static const int _maxDecodeDimension = 2048;

  Widget _wrapClip(Widget child) {
    final radius = borderRadius;
    if (radius != null && radius != BorderRadius.zero) {
      return ClipRRect(borderRadius: radius, child: child);
    }
    return child;
  }

  /// Exposed for unit tests & micro-optimization benchmarks (MO5).
  @visibleForTesting
  static (int?, int?) resolveMemCacheSizeForTest({
    required double? logicalWidth,
    required double? logicalHeight,
    required double dpr,
  }) =>
      _resolveMemCacheSize(
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        dpr: dpr,
      );

  static (int?, int?) _resolveMemCacheSize({
    // Photo cache - Sabrina
    // CachedPhoto uses a Cache-then-Network 2-level strategy (Flutter RAM ImageCache → cached_network_image disk cache).
    // It calculates memCacheWidth from widget dimensions × devicePixelRatio so thumbnails never blow up RAM, and renders a
    // category icon placeholder if an uncached photo fails offline
    required double? logicalWidth,
    required double? logicalHeight,
    required double dpr,
  }) {
    developer.Timeline.startSync('CachedPhoto.resolveDecodeBounds');
    try {
      final pxW = (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0)
          ? (logicalWidth * dpr).round().clamp(1, _maxDecodeDimension)
          : null;
      final pxH = (logicalHeight != null && logicalHeight.isFinite && logicalHeight > 0)
          ? (logicalHeight * dpr).round().clamp(1, _maxDecodeDimension)
          : null;
      if (pxW == null && pxH == null) return (null, null);
      // Pass at most one decode bound so ResizeImage preserves the photo's aspect ratio.
      if (pxW != null && (pxH == null || pxW >= pxH)) {
        return (pxW, null);
      }
      return (null, pxH);
    } finally {
      developer.Timeline.finishSync();
    }
  }

  /// [autoWidth] / [autoHeight] are the decode size worked out from the layout. An explicit
  /// [memCacheWidth] wins over them (and then no height bound is set, so the aspect ratio holds).
  Widget _buildNetworkImage(BuildContext context, int? autoWidth, int? autoHeight) {
    final explicitWidth = memCacheWidth;
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      cacheManager: ListingImageCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: explicitWidth ?? autoWidth,
      memCacheHeight: explicitWidth != null ? null : autoHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      placeholder: (context, url) => _buildPlaceholder(context),
      errorWidget: (context, url, error) => _buildPlaceholder(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _wrapClip(_buildPlaceholder(context));
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final hasFiniteW = width != null && width!.isFinite;
    final hasFiniteH = height != null && height!.isFinite;

    if (hasFiniteW && hasFiniteH) {
      final (memW, memH) = _resolveMemCacheSize(
        logicalWidth: width,
        logicalHeight: height,
        dpr: dpr,
      );
      return _wrapClip(_buildNetworkImage(context, memW, memH));
    }

    return _wrapClip(
      LayoutBuilder(
        builder: (context, constraints) {
          final resolvedW = hasFiniteW
              ? width
              : (constraints.hasBoundedWidth ? constraints.maxWidth : null);
          final resolvedH = hasFiniteH
              ? height
              : (constraints.hasBoundedHeight ? constraints.maxHeight : null);
          final (memW, memH) = _resolveMemCacheSize(
            logicalWidth: resolvedW,
            logicalHeight: resolvedH,
            dpr: dpr,
          );
          return _buildNetworkImage(context, memW, memH);
        },
      ),
    );
  }
}
