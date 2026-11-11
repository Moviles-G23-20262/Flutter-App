import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Reusable cached image widget for listings and chat photos.
///
/// Implements EC14: Caches images in memory and local disk (200 files, 30 days).
/// If an image fails to load while offline or has never been downloaded, it gracefully renders
/// a category placeholder icon instead of a broken empty box or crash.
///
/// A photo is usually shown much smaller than it was uploaded, so [memCacheWidth] and
/// [maxWidthDiskCache] (both in pixels, both optional) make the image be resized before it is kept
/// in the memory cache and in the disk cache. Small thumbnails then do not hold full-size bitmaps.
class CachedPhoto extends StatelessWidget {
  final String? imageUrl;
  final String? category;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Width in pixels the decoded image is limited to in the memory cache; null keeps it as is.
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

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: _buildPlaceholder(context),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        maxWidthDiskCache: maxWidthDiskCache,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      ),
    );
  }
}
