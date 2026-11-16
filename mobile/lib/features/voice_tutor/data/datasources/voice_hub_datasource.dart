import 'dart:typed_data';
import '../../../../core/network/signalr_service.dart';

abstract class IVoiceHubDataSource {
  Stream<String> get statusUpdates;
  Stream<String> get userTranscriptions;
  Stream<String> get subtitleTokens;
  Stream<Uint8List> get audioChunks;
  Stream<String> get turnCompletions;

  Future<void> connect();
  Future<void> disconnect();
  Future<String?> startSession(String topic, int level);
  Future<void> sendAudio(Uint8List bytes, {String? sessionId});
  Future<void> sendText(String text, {String? sessionId});
}

class VoiceHubDataSource implements IVoiceHubDataSource {
  final ISignalRService _signalRService;

  VoiceHubDataSource(this._signalRService);

  @override
  Stream<String> get statusUpdates => _signalRService.statusUpdates;

  @override
  Stream<String> get userTranscriptions => _signalRService.userTranscriptions;

  @override
  Stream<String> get subtitleTokens => _signalRService.subtitleTokens;

  @override
  Stream<Uint8List> get audioChunks => _signalRService.audioChunks;

  @override
  Stream<String> get turnCompletions => _signalRService.turnCompletions;

  @override
  Future<void> connect() => _signalRService.connect();

  @override
  Future<void> disconnect() => _signalRService.disconnect();

  @override
  Future<String?> startSession(String topic, int level) => _signalRService.startSession(topic, level);

  @override
  Future<void> sendAudio(Uint8List bytes, {String? sessionId}) => _signalRService.sendAudio(bytes, sessionId: sessionId);

  @override
  Future<void> sendText(String text, {String? sessionId}) => _signalRService.sendText(text, sessionId: sessionId);
}
