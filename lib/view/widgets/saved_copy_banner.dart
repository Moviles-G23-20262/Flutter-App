import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'formatters.dart';

/// "You're offline. Showing the copy saved 2h ago." above a list that came from the phone.
class SavedCopyBanner extends StatelessWidget {
  final DateTime savedAt;
  final Future<void> Function()? onRetry;

  const SavedCopyBanner({super.key, required this.savedAt, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final warning = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkWarning
        : AppColors.lightWarning;
    final age = timeAgo(savedAt);
    return Material(
      color: warning.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: warning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You're offline. Showing the copy saved ${age == 'just now' ? age : age.toLowerCase()}.",
                key: const Key('saved-copy-banner-text'),
                style: AppTextStyles.body(warning, fontSize: AppTextStyles.sizeXs),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: warning,
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
