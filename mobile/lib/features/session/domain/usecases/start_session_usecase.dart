import '../entities/cefr_level.dart';
import '../repositories/session_repository.dart';

class StartSessionUseCase {
  final ISessionRepository _repository;
  StartSessionUseCase(this._repository);

  Future<String> call(String topic, CefrLevel level) {
    return _repository.startSession(topic, level);
  }
}
