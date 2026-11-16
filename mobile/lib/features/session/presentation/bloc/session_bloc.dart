import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/complete_session_usecase.dart';
import '../../domain/usecases/get_session_detail_usecase.dart';
import '../../domain/usecases/start_session_usecase.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final StartSessionUseCase _startSessionUseCase;
  final GetSessionDetailUseCase _getSessionDetailUseCase;
  final CompleteSessionUseCase _completeSessionUseCase;

  SessionBloc({
    required StartSessionUseCase startSessionUseCase,
    required GetSessionDetailUseCase getSessionDetailUseCase,
    required CompleteSessionUseCase completeSessionUseCase,
  })  : _startSessionUseCase = startSessionUseCase,
        _getSessionDetailUseCase = getSessionDetailUseCase,
        _completeSessionUseCase = completeSessionUseCase,
        super(SessionInitial()) {
    on<StartSessionRequested>(_onStartSessionRequested);
    on<GetSessionDetailRequested>(_onGetSessionDetailRequested);
    on<CompleteSessionRequested>(_onCompleteSessionRequested);
  }

  Future<void> _onStartSessionRequested(
    StartSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading(message: 'Initializing session with AI Tutor...'));
    try {
      final sessionId = await _startSessionUseCase(event.topic, event.targetLevel);
      emit(SessionCreated(
        sessionId: sessionId,
        topic: event.topic,
        targetLevel: event.targetLevel,
      ));
    } catch (e) {
      emit(SessionError('Failed to start session: $e'));
    }
  }

  Future<void> _onGetSessionDetailRequested(
    GetSessionDetailRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading(message: 'Fetching session summary...'));
    try {
      final session = await _getSessionDetailUseCase(event.sessionId);
      emit(SessionDetailLoaded(session));
    } catch (e) {
      emit(SessionError('Failed to load session details: $e'));
    }
  }

  Future<void> _onCompleteSessionRequested(
    CompleteSessionRequested event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading(message: 'Ending session & saving progress...'));
    try {
      await _completeSessionUseCase(event.sessionId, feedback: event.feedback);
      emit(SessionCompletedState(event.sessionId));
    } catch (e) {
      emit(SessionError('Failed to complete session: $e'));
    }
  }
}
