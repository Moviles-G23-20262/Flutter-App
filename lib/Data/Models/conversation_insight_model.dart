import '../../Domain/Entities/conversation_insight.dart';

class ConversationInsightModel extends ConversationInsight {
  const ConversationInsightModel({
    required super.conversationsAnalyzed,
    required super.medianMessages,
    required super.medianMinutes,
  });

  /// Parses GET /analytics/chat-to-meeting-point/
  factory ConversationInsightModel.fromJson(Map<String, dynamic> json) {
    final messages = json['messages_before_agreement'] as Map<String, dynamic>;
    final minutes = json['minutes_to_agreement'] as Map<String, dynamic>;
    return ConversationInsightModel(
      conversationsAnalyzed: json['conversations_analyzed'] as int,
      medianMessages: (messages['median'] as num).toDouble(),
      medianMinutes: (minutes['median'] as num).toDouble(),
    );
  }
}
