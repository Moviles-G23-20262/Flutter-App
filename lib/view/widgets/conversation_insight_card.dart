import 'package:flutter/material.dart';
import '../../model/entities/chat_agreement.dart';
import '../../model/entities/conversation_insight.dart';
import '../../app/theme/app_theme.dart';
import 'common_widgets.dart';

/// Chat-header card (BQ4). While the chat has no meeting yet: "Most chats agree after ~N
/// messages" + progress of this chat. Once the meeting is confirmed ([agreement] set): how long
/// this chat took, next to the typical one when [insight] is known.
class ConversationInsightCard extends StatelessWidget {
  final ConversationInsight? insight;
  final ChatAgreement? agreement;
  final int messagesSoFar;

  const ConversationInsightCard({
    super.key,
    this.insight,
    this.agreement,
    this.messagesSoFar = 0,
  });

  @override
  Widget build(BuildContext context) {
    final agreement = this.agreement;
    if (agreement != null) return _buildAgreement(context, agreement);

    final insight = this.insight;
    if (insight == null || !insight.hasData) return const SizedBox.shrink();

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

  Widget _buildAgreement(BuildContext context, ChatAgreement agreement) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final messages = agreement.messagesToAgreement;
    final minutes = agreement.minutesToAgreement.round();
    final typical = insight;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You agreed on a meeting point after $messages ${messages == 1 ? 'message' : 'messages'} '
            '(${minutes < 1 ? 'less than a minute' : '$minutes min'})',
            style: AppTextStyles.body(txPrimary,
                fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
          ),
          if (typical != null && typical.hasData) ...[
            const SizedBox(height: 4),
            Text(
              'Most chats take ~${typical.medianMessages.ceil()} messages (about ${typical.medianMinutes.round()} min)',
              style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
            ),
          ],
        ],
      ),
    );
  }
}
