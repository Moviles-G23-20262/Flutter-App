/// BQ4 answer shown to buyer and seller (Type 2): how long chats usually take
/// to agree on a meeting point.
class ConversationInsight {
  final int conversationsAnalyzed;
  final double medianMessages;
  final double medianMinutes;

  const ConversationInsight({
    required this.conversationsAnalyzed,
    required this.medianMessages,
    required this.medianMinutes,
  });

  bool get hasData => conversationsAnalyzed > 0;
}
