import 'cefr_level.dart';

enum SenderType {
  // Values match backend AiEnglishTutor.Domain.Enums.SenderType exactly (1-based),
  // otherwise every message from a resumed session gets mislabeled (see CefrLevel for
  // the same class of bug).
  user(1, 'User'),
  tutor(2, 'Tutor');

  final int value;
  final String label;
  const SenderType(this.value, this.label);

  static SenderType fromValue(int val) {
    return SenderType.values.firstWhere((e) => e.value == val, orElse: () => SenderType.user);
  }
}

class SessionMessageEntity {
  final String id;
  final String content;
  final SenderType senderType;
  final DateTime createdAt;

  const SessionMessageEntity({
    required this.id,
    required this.content,
    required this.senderType,
    required this.createdAt,
  });
}

class LearningSessionEntity {
  final String id;
  final String topic;
  final CefrLevel targetLevel;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? overallFeedback;
  final List<SessionMessageEntity> messages;

  const LearningSessionEntity({
    required this.id,
    required this.topic,
    required this.targetLevel,
    required this.createdAt,
    this.completedAt,
    this.overallFeedback,
    this.messages = const [],
  });

  bool get isCompleted => completedAt != null;
}

/// Lightweight summary used to list resumable sessions (GET /api/sessions/active).
class SessionSummaryEntity {
  final String id;
  final String topic;
  final CefrLevel targetLevel;
  final int messageCount;
  final DateTime createdAt;

  const SessionSummaryEntity({
    required this.id,
    required this.topic,
    required this.targetLevel,
    required this.messageCount,
    required this.createdAt,
  });
}
