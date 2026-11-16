import '../../domain/entities/cefr_level.dart';

abstract class SessionEvent {}

class StartSessionRequested extends SessionEvent {
  final String topic;
  final CefrLevel targetLevel;
  StartSessionRequested({required this.topic, required this.targetLevel});
}

class GetSessionDetailRequested extends SessionEvent {
  final String sessionId;
  GetSessionDetailRequested(this.sessionId);
}

class CompleteSessionRequested extends SessionEvent {
  final String sessionId;
  final String? feedback;
  CompleteSessionRequested({required this.sessionId, this.feedback});
}
