import '../Entities/conversation_insight.dart';

abstract class ConversationInsightRepository {
  Future<ConversationInsight> getConversationInsight();
}
