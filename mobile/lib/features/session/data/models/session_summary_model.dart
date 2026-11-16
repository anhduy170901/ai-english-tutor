import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/learning_session.dart';

class SessionSummaryModel extends SessionSummaryEntity {
  const SessionSummaryModel({
    required super.id,
    required super.topic,
    required super.targetLevel,
    required super.messageCount,
    required super.createdAt,
  });

  factory SessionSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['targetLevel'] ?? json['TargetLevel'] ?? 3;
    final levelVal = rawLevel is int ? rawLevel : int.tryParse(rawLevel.toString()) ?? 3;

    final rawCount = json['messageCount'] ?? json['MessageCount'] ?? 0;
    final countVal = rawCount is int ? rawCount : int.tryParse(rawCount.toString()) ?? 0;

    return SessionSummaryModel(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      topic: (json['topic'] ?? json['Topic'] ?? '').toString(),
      targetLevel: CefrLevel.fromValue(levelVal),
      messageCount: countVal,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['CreatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
