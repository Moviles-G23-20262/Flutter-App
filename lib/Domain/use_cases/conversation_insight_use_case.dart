import '../Entities/conversation_insight.dart';
import '../repositories/conversation_insight_repository.dart';

class GetConversationInsightUseCase {
  final ConversationInsightRepository repository;

  GetConversationInsightUseCase(this.repository);

  Future<ConversationInsight> execute() => repository.getConversationInsight();
}
