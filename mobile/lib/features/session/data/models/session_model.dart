import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/learning_session.dart';

class MessageModel extends SessionMessageEntity {
  const MessageModel({
    required super.id,
    required super.content,
    required super.senderType,
    required super.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Backend MessageDto's property is named "Sender" (-> "sender" in JSON), not "senderType".
    final senderRaw = json['sender'] ?? json['Sender'] ?? 1;
    final senderVal = senderRaw is int ? senderRaw : (senderRaw.toString().toLowerCase() == 'tutor' ? 2 : 1);

    return MessageModel(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      content: (json['content'] ?? json['Content'] ?? '').toString(),
      senderType: SenderType.fromValue(senderVal),
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['CreatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class SessionModel extends LearningSessionEntity {
  const SessionModel({
    required super.id,
    required super.topic,
    required super.targetLevel,
    required super.createdAt,
    super.completedAt,
    super.overallFeedback,
    super.messages,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['targetLevel'] ?? json['TargetLevel'] ?? 3;
    final levelVal = rawLevel is int ? rawLevel : int.tryParse(rawLevel.toString()) ?? 3;

    final rawMessages = json['messages'] ?? json['Messages'] ?? [];
    final List<SessionMessageEntity> parsedMessages = [];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map<String, dynamic>) {
          parsedMessages.add(MessageModel.fromJson(item));
        }
      }
    }

    return SessionModel(
      id: (json['id'] ?? json['Id'] ?? json['sessionId'] ?? json['SessionId'] ?? '').toString(),
      topic: (json['topic'] ?? json['Topic'] ?? '').toString(),
      targetLevel: CefrLevel.fromValue(levelVal),
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['CreatedAt'] ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null || json['CompletedAt'] != null
          ? DateTime.tryParse(json['completedAt'] ?? json['CompletedAt'])
          : null,
      overallFeedback: json['overallFeedback'] ?? json['OverallFeedback'],
      messages: parsedMessages,
    );
  }
}
