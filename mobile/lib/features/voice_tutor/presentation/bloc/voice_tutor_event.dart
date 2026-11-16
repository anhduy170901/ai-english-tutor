import 'dart:typed_data';
import '../../../session/domain/entities/cefr_level.dart';

abstract class VoiceTutorEvent {}

class InitializeVoiceCallEvent extends VoiceTutorEvent {
  final String topic;
  final CefrLevel level;
  final String? existingSessionId;
  InitializeVoiceCallEvent({
    required this.topic,
    required this.level,
    this.existingSessionId,
  });
}

class PushToTalkStartEvent extends VoiceTutorEvent {}

class PushToTalkStopEvent extends VoiceTutorEvent {}

class StatusUpdateReceivedEvent extends VoiceTutorEvent {
  final String status;
  StatusUpdateReceivedEvent(this.status);
}

class UserTranscribedTextReceivedEvent extends VoiceTutorEvent {
  final String text;
  UserTranscribedTextReceivedEvent(this.text);
}

class SubtitleTokenReceivedEvent extends VoiceTutorEvent {
  final String token;
  SubtitleTokenReceivedEvent(this.token);
}

class AudioChunkReceivedEvent extends VoiceTutorEvent {
  final Uint8List chunk;
  AudioChunkReceivedEvent(this.chunk);
}

class TurnCompletedEvent extends VoiceTutorEvent {
  final String fullResponse;
  TurnCompletedEvent(this.fullResponse);
}

class SendTextMessageEvent extends VoiceTutorEvent {
  final String text;
  SendTextMessageEvent(this.text);
}

class AudioPlaybackStateChangedEvent extends VoiceTutorEvent {
  final bool isPlaying;
  AudioPlaybackStateChangedEvent(this.isPlaying);
}

class DisconnectCallEvent extends VoiceTutorEvent {}
