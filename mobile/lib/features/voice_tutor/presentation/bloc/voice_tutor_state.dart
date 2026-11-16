import '../../domain/entities/tutor_entities.dart';

class VoiceTutorState {
  final TutorCallStatus callStatus;
  final String? sessionId;
  final String? statusMessage;
  final String liveSubtitle;
  final List<TutorMessage> messageHistory;
  final bool isAudioPlaying;
  final bool isRecording;
  final String? errorMessage;

  const VoiceTutorState({
    this.callStatus = TutorCallStatus.disconnected,
    this.sessionId,
    this.statusMessage,
    this.liveSubtitle = '',
    this.messageHistory = const [],
    this.isAudioPlaying = false,
    this.isRecording = false,
    this.errorMessage,
  });

  VoiceTutorState copyWith({
    TutorCallStatus? callStatus,
    String? sessionId,
    String? statusMessage,
    String? liveSubtitle,
    List<TutorMessage>? messageHistory,
    bool? isAudioPlaying,
    bool? isRecording,
    String? errorMessage,
  }) {
    return VoiceTutorState(
      callStatus: callStatus ?? this.callStatus,
      sessionId: sessionId ?? this.sessionId,
      statusMessage: statusMessage ?? this.statusMessage,
      liveSubtitle: liveSubtitle ?? this.liveSubtitle,
      messageHistory: messageHistory ?? this.messageHistory,
      isAudioPlaying: isAudioPlaying ?? this.isAudioPlaying,
      isRecording: isRecording ?? this.isRecording,
      errorMessage: errorMessage,
    );
  }
}
