import 'package:flutter/material.dart';

/// Amber banner displayed at the top of screens when offline.
///
/// Indicates whether saved data is being shown, displays the age of the local copy,
/// or provides a retry button when no local cache exists.
class OfflineBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isWaitingForWifi;

  const OfflineBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.isWaitingForWifi = false,
  });

  factory OfflineBanner.forCache({
    Key? key,
    required String? formattedAge,
    String noun = 'listings',
    VoidCallback? onRetry,
  }) {
    final text = (formattedAge != null && formattedAge.isNotEmpty)
        ? "You're offline. Showing $noun saved $formattedAge."
        : "You're offline. Showing $noun saved on this phone.";
    return OfflineBanner(key: key, message: text, onRetry: onRetry);
  }

  factory OfflineBanner.firstLaunchOffline({
    Key? key,
    String noun = 'listings',
    required VoidCallback onRetry,
  }) {
    return OfflineBanner(
      key: key,
      message: 'Connect once to load $noun.',
      onRetry: onRetry,
    );
  }

  factory OfflineBanner.waitingForWifi({
    Key? key,
    VoidCallback? onSendNow,
  }) {
    return OfflineBanner(
      key: key,
      message: "Waiting for Wi-Fi. Turn on 'Use mobile data' in Profile to send now.",
      onRetry: onSendNow,
      isWaitingForWifi: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    const amberBg = Color(0xFFFFF3CD);
    const amberBorder = Color(0xFFFFEEBA);
    const amberText = Color(0xFF856404);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: amberBg,
        border: Border(
          bottom: BorderSide(color: amberBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWaitingForWifi ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            size: 16,
            color: amberText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: const Key('offline-banner-text'),
              style: const TextStyle(
                color: amberText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                isWaitingForWifi ? 'Send now' : 'Retry',
                style: const TextStyle(
                  color: amberText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
