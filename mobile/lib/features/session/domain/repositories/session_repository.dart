import '../entities/cefr_level.dart';
import '../entities/learning_session.dart';

abstract class ISessionRepository {
  Future<String> startSession(String topic, CefrLevel level);
  Future<LearningSessionEntity> getSessionDetail(String sessionId);
  Future<void> completeSession(String sessionId, {String? feedback});
  Future<List<SessionSummaryEntity>> getActiveSessions();
}
