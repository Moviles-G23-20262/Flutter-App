import 'package:flutter/material.dart';
import '../../Domain/Entities/conversation_insight.dart';
import '../../theme/app_theme.dart';
import 'common_widgets.dart';

/// Chat-header card: "Most chats agree after ~N messages" + progress of this chat.
class ConversationInsightCard extends StatelessWidget {
  final ConversationInsight insight;
  final int messagesSoFar;

  const ConversationInsightCard({
    super.key,
    required this.insight,
    required this.messagesSoFar,
  });

  @override
  Widget build(BuildContext context) {
    if (!insight.hasData) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    final target = insight.medianMessages.ceil().clamp(1, 1000);
    final progress = (messagesSoFar / target).clamp(0.0, 1.0);
    final minutes = insight.medianMinutes.round();

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most chats agree on a meeting point after ~$target messages (about $minutes min)',
            style: AppTextStyles.body(txPrimary,
                fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            color: accentHi,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text('$messagesSoFar of ~$target messages so far',
              style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
        ],
      ),
    );
  }
}
