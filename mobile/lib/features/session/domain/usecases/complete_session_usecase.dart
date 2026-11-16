import '../repositories/session_repository.dart';

class CompleteSessionUseCase {
  final ISessionRepository _repository;
  CompleteSessionUseCase(this._repository);

  Future<void> call(String sessionId, {String? feedback}) {
    return _repository.completeSession(sessionId, feedback: feedback);
  }
}
