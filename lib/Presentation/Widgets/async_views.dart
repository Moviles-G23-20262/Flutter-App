import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'common_widgets.dart';

/// Shown while server data is on its way.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    return Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5));
  }
}

/// Shown when loading failed, with a retry.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: txMuted),
            const SizedBox(height: 12),
            Text('Could not load', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Try again',
              leadingIcon: const Icon(Icons.refresh_rounded, size: 16),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when there is simply nothing yet.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyView({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final borderSubtle = dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: borderSubtle),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.heading(txMuted, fontSize: AppTextStyles.sizeMd)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
            ],
          ],
        ),
      ),
    );
  }
}
