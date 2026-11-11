import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Reusable cached image widget for listings and chat photos.
///
/// Implements EC14: Caches images in memory and local disk (200 files, 30 days).
/// If an image fails to load while offline or has never been downloaded, it gracefully renders
/// a category placeholder icon instead of a broken empty box or crash.
class CachedPhoto extends StatelessWidget {
  final String? imageUrl;
  final String? category;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedPhoto({
    super.key,
    required this.imageUrl,
    this.category,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
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

  static (int?, int?) _resolveMemCacheSize({
    required double? logicalWidth,
    required double? logicalHeight,
    required double dpr,
  }) {
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
  }

  Widget _buildNetworkImage(BuildContext context, int? memCacheWidth, int? memCacheHeight) {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
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
