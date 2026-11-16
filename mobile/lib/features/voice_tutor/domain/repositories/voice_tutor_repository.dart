import 'dart:typed_data';

abstract class IVoiceTutorRepository {
  Stream<String> get statusStream;
  Stream<String> get userTranscribedTextStream;
  Stream<String> get subtitleTokenStream;
  Stream<Uint8List> get audioChunkStream;
  Stream<String> get turnCompletedStream;

  Future<void> connect();
  Future<void> disconnect();
  Future<String?> startSession(String topic, int level);
  Future<void> sendUserAudio(Uint8List audioBytes, {String? sessionId});
  Future<void> sendUserText(String text, {String? sessionId});
}
