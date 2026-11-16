import 'dart:typed_data';
import '../../domain/repositories/voice_tutor_repository.dart';
import '../datasources/voice_hub_datasource.dart';

class VoiceTutorRepositoryImpl implements IVoiceTutorRepository {
  final IVoiceHubDataSource _dataSource;

  VoiceTutorRepositoryImpl(this._dataSource);

  @override
  Stream<String> get statusStream => _dataSource.statusUpdates;

  @override
  Stream<String> get userTranscribedTextStream => _dataSource.userTranscriptions;

  @override
  Stream<String> get subtitleTokenStream => _dataSource.subtitleTokens;

  @override
  Stream<Uint8List> get audioChunkStream => _dataSource.audioChunks;

  @override
  Stream<String> get turnCompletedStream => _dataSource.turnCompletions;

  @override
  Future<void> connect() => _dataSource.connect();

  @override
  Future<void> disconnect() => _dataSource.disconnect();

  @override
  Future<String?> startSession(String topic, int level) => _dataSource.startSession(topic, level);

  @override
  Future<void> sendUserAudio(Uint8List audioBytes, {String? sessionId}) {
    return _dataSource.sendAudio(audioBytes, sessionId: sessionId);
  }

  @override
  Future<void> sendUserText(String text, {String? sessionId}) {
    return _dataSource.sendText(text, sessionId: sessionId);
  }
}
