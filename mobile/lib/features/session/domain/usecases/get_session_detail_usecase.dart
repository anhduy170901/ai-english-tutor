import '../entities/learning_session.dart';
import '../repositories/session_repository.dart';

class GetSessionDetailUseCase {
  final ISessionRepository _repository;
  GetSessionDetailUseCase(this._repository);

  Future<LearningSessionEntity> call(String sessionId) {
    return _repository.getSessionDetail(sessionId);
  }
}
