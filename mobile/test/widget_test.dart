import 'package:flutter_test/flutter_test.dart';
import 'package:ai_tutor_mobile/features/session/domain/entities/cefr_level.dart';
import 'package:ai_tutor_mobile/features/session/domain/entities/learning_session.dart';
import 'package:ai_tutor_mobile/features/voice_tutor/domain/entities/tutor_entities.dart';

void main() {
  group('Domain Entities Unit Tests', () {
    test('CefrLevel enum maps correctly', () {
      expect(CefrLevel.fromValue(0), CefrLevel.a1);
      expect(CefrLevel.fromValue(2), CefrLevel.b1);
      expect(CefrLevel.fromValue(4), CefrLevel.c1);
      expect(CefrLevel.fromValue(99), CefrLevel.b1); // fallback
    });

    test('LearningSessionEntity holds messages and calculates completion', () {
      final session = LearningSessionEntity(
        id: 'test-123',
        topic: 'IELTS Speaking',
        targetLevel: CefrLevel.b2,
        createdAt: DateTime.now(),
        messages: [
          SessionMessageEntity(
            id: 'm1',
            content: 'Hello, how can I help you today?',
            senderType: SenderType.tutor,
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(session.isCompleted, isFalse);
      expect(session.messages.length, 1);
      expect(session.messages.first.senderType, SenderType.tutor);
    });

    test('TutorMessage copyWith produces correct clone', () {
      final msg = TutorMessage(
        id: '1',
        content: 'I went to school yesterday.',
        isUser: true,
        timestamp: DateTime.now(),
      );

      final updated = msg.copyWith(content: 'I went to work yesterday.');
      expect(updated.id, '1');
      expect(updated.content, 'I went to work yesterday.');
      expect(updated.isUser, isTrue);
    });
  });
}
