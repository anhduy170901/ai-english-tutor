import '../repositories/voice_tutor_repository.dart';

class ConnectVoiceHubUseCase {
  final IVoiceTutorRepository _repository;
  ConnectVoiceHubUseCase(this._repository);

  Future<void> call() => _repository.connect();
}
