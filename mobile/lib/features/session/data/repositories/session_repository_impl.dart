import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/learning_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/session_remote_datasource.dart';

class SessionRepositoryImpl implements ISessionRepository {
  final ISessionRemoteDataSource _remoteDataSource;

  SessionRepositoryImpl(this._remoteDataSource);

  @override
  Future<String> startSession(String topic, CefrLevel level) {
    return _remoteDataSource.startSession(topic, level.value);
  }

  @override
  Future<LearningSessionEntity> getSessionDetail(String sessionId) {
    return _remoteDataSource.getSessionDetail(sessionId);
  }

  @override
  Future<void> completeSession(String sessionId, {String? feedback}) {
    return _remoteDataSource.completeSession(sessionId, feedback: feedback);
  }

  @override
  Future<List<SessionSummaryEntity>> getActiveSessions() {
    return _remoteDataSource.getActiveSessions();
  }
}
