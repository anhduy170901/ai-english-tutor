enum TutorCallStatus {
  disconnected('Disconnected', 'Tap connect to begin'),
  connecting('Connecting...', 'Establishing low-latency link'),
  idle('Ready to Listen', 'Hold Push-to-Talk to speak'),
  listening('Listening...', 'Release when you finish speaking'),
  transcribing('Transcribing speech...', 'Whisper AI is processing your voice'),
  thinking('AI is thinking...', 'Formulating response & corrections'),
  speaking('Tutor is speaking...', 'Listen to pronunciation & explanation'),
  error('Connection Error', 'Please check server status');

  final String label;
  final String description;
  const TutorCallStatus(this.label, this.description);
}

class TutorMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;
  final bool isThinking;

  const TutorMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isStreaming = false,
    this.isThinking = false,
  });

  TutorMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    bool? isStreaming,
    bool? isThinking,
  }) {
    return TutorMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}
