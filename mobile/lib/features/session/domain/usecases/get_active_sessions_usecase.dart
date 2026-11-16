import '../entities/learning_session.dart';
import '../repositories/session_repository.dart';

class GetActiveSessionsUseCase {
  final ISessionRepository _repository;
  GetActiveSessionsUseCase(this._repository);

  Future<List<SessionSummaryEntity>> call() {
    return _repository.getActiveSessions();
  }
}
