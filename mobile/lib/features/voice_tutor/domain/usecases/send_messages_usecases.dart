import 'dart:typed_data';
import '../repositories/voice_tutor_repository.dart';

class SendAudioMessageUseCase {
  final IVoiceTutorRepository _repository;
  SendAudioMessageUseCase(this._repository);

  Future<void> call(Uint8List audioBytes, {String? sessionId}) {
    return _repository.sendUserAudio(audioBytes, sessionId: sessionId);
  }
}

class SendTextMessageUseCase {
  final IVoiceTutorRepository _repository;
  SendTextMessageUseCase(this._repository);

  Future<void> call(String text, {String? sessionId}) {
    return _repository.sendUserText(text, sessionId: sessionId);
  }
}
