import '../entities/chat_agreement.dart';

class ChatAgreementModel extends ChatAgreement {
  const ChatAgreementModel({required super.messagesToAgreement, required super.minutesToAgreement});

  /// Parses GET /analytics/chat-agreement/{chatRoomId}/ (`timeToAgreement` is in minutes).
  factory ChatAgreementModel.fromJson(Map<String, dynamic> json) => ChatAgreementModel(
        messagesToAgreement: json['messagesToAgreement'] as int,
        minutesToAgreement: (json['timeToAgreement'] as num).toDouble(),
      );
}
