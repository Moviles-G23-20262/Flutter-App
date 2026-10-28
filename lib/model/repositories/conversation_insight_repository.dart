import '../entities/chat_agreement.dart';
import '../entities/conversation_insight.dart';

abstract class ConversationInsightRepository {
  Future<ConversationInsight> getConversationInsight();

  /// How long the chat [chatRoomId] took to agree on a meeting point.
  Future<ChatAgreement> getChatAgreement(String chatRoomId);
}
