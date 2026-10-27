import '../entities/chat_agreement.dart';
import '../entities/conversation_insight.dart';
import '../repositories/conversation_insight_repository.dart';

class GetConversationInsightUseCase {
  final ConversationInsightRepository repository;

  GetConversationInsightUseCase(this.repository);

  Future<ConversationInsight> execute() => repository.getConversationInsight();
}


/// BQ4 for one chat, once its meeting point is confirmed.
class GetChatAgreementUseCase {
  final ConversationInsightRepository repository;

  GetChatAgreementUseCase(this.repository);

  Future<ChatAgreement> execute(String chatRoomId) => repository.getChatAgreement(chatRoomId);
}
