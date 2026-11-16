import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/learning_session.dart';

abstract class SessionState {}

class SessionInitial extends SessionState {}

class SessionLoading extends SessionState {
  final String? message;
  SessionLoading({this.message});
}

class SessionCreated extends SessionState {
  final String sessionId;
  final String topic;
  final CefrLevel targetLevel;
  SessionCreated({
    required this.sessionId,
    required this.topic,
    required this.targetLevel,
  });
}

class SessionDetailLoaded extends SessionState {
  final LearningSessionEntity session;
  SessionDetailLoaded(this.session);
}

class SessionCompletedState extends SessionState {
  final String sessionId;
  SessionCompletedState(this.sessionId);
}

class SessionError extends SessionState {
  final String message;
  SessionError(this.message);
}
