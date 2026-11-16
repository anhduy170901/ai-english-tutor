import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/audio_recorder_service.dart';
import '../../../session/domain/entities/learning_session.dart';
import '../../../session/domain/usecases/get_session_detail_usecase.dart';
import '../../domain/entities/tutor_entities.dart';
import '../../domain/repositories/voice_tutor_repository.dart';
import 'voice_tutor_event.dart';
import 'voice_tutor_state.dart';

class VoiceTutorBloc extends Bloc<VoiceTutorEvent, VoiceTutorState> {
  final IVoiceTutorRepository _repository;
  final IAudioRecorderService _recorderService;
  final IAudioPlayerService _playerService;
  final GetSessionDetailUseCase _getSessionDetailUseCase;

  final _amplitudeController = StreamController<double>.broadcast();
  StreamSubscription? _statusSubscription;
  StreamSubscription? _userTranscriptionSubscription;
  StreamSubscription? _subtitleSubscription;
  StreamSubscription? _audioChunkSubscription;
  StreamSubscription? _turnCompletedSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _recorderAmpSubscription;
  StreamSubscription? _playerAmpSubscription;

  Stream<double> get amplitudeStream => _amplitudeController.stream;

  VoiceTutorBloc({
    required IVoiceTutorRepository repository,
    required IAudioRecorderService recorderService,
    required IAudioPlayerService playerService,
    required GetSessionDetailUseCase getSessionDetailUseCase,
  })  : _repository = repository,
        _recorderService = recorderService,
        _playerService = playerService,
        _getSessionDetailUseCase = getSessionDetailUseCase,
        super(const VoiceTutorState()) {
    on<InitializeVoiceCallEvent>(_onInitializeVoiceCall);
    on<PushToTalkStartEvent>(_onPushToTalkStart);
    on<PushToTalkStopEvent>(_onPushToTalkStop);
    on<StatusUpdateReceivedEvent>(_onStatusUpdateReceived);
    on<UserTranscribedTextReceivedEvent>(_onUserTranscribedTextReceived);
    on<SubtitleTokenReceivedEvent>(_onSubtitleTokenReceived);
    on<AudioChunkReceivedEvent>(_onAudioChunkReceived);
    on<TurnCompletedEvent>(_onTurnCompleted);
    on<SendTextMessageEvent>(_onSendTextMessage);
    on<AudioPlaybackStateChangedEvent>(_onAudioPlaybackStateChanged);
    on<DisconnectCallEvent>(_onDisconnectCall);

    _setupStreamListeners();
  }

  void _setupStreamListeners() {
    _statusSubscription = _repository.statusStream.listen(
      (status) => add(StatusUpdateReceivedEvent(status)),
    );

    _userTranscriptionSubscription = _repository.userTranscribedTextStream.listen(
      (text) => add(UserTranscribedTextReceivedEvent(text)),
    );

    _subtitleSubscription = _repository.subtitleTokenStream.listen(
      (token) => add(SubtitleTokenReceivedEvent(token)),
    );

    _audioChunkSubscription = _repository.audioChunkStream.listen(
      (chunk) => add(AudioChunkReceivedEvent(chunk)),
    );

    _turnCompletedSubscription = _repository.turnCompletedStream.listen(
      (full) => add(TurnCompletedEvent(full)),
    );

    _playerStateSubscription = _playerService.isPlayingStream.listen(
      (isPlaying) => add(AudioPlaybackStateChangedEvent(isPlaying)),
    );

    _recorderAmpSubscription = _recorderService.amplitudeStream.listen((amp) {
      if (state.isRecording) {
        _amplitudeController.add(amp);
      }
    });

    _playerAmpSubscription = _playerService.amplitudeStream.listen((amp) {
      if (state.isAudioPlaying) {
        _amplitudeController.add(amp);
      }
    });
  }

  Future<void> _onInitializeVoiceCall(
    InitializeVoiceCallEvent event,
    Emitter<VoiceTutorState> emit,
  ) async {
    emit(state.copyWith(
      callStatus: TutorCallStatus.connecting,
      statusMessage: 'Connecting to AI Voice Tutor...',
    ));

    try {
      await _repository.connect();

      String? activeSessionId = event.existingSessionId;
      var history = const <TutorMessage>[];

      if (activeSessionId == null || activeSessionId.isEmpty) {
        activeSessionId = await _repository.startSession(event.topic, event.level.value);
      } else {
        try {
          final session = await _getSessionDetailUseCase(activeSessionId);
          history = session.messages
              .map((m) => TutorMessage(
                    id: m.id,
                    content: m.content,
                    isUser: m.senderType == SenderType.user,
                    timestamp: m.createdAt,
                  ))
              .toList();
        } catch (_) {}
      }

      emit(state.copyWith(
        callStatus: TutorCallStatus.idle,
        sessionId: activeSessionId,
        messageHistory: history,
        statusMessage: 'Connected! Hold the button to start speaking.',
      ));
    } catch (e) {
      emit(state.copyWith(
        callStatus: TutorCallStatus.error,
        errorMessage: 'Connection failed: $e',
        statusMessage: 'Could not connect to voice service',
      ));
    }
  }

  Future<void> _onPushToTalkStart(
    PushToTalkStartEvent event,
    Emitter<VoiceTutorState> emit,
  ) async {
    await _playerService.stop();

    try {
      await _recorderService.startRecording();
      emit(state.copyWith(
        callStatus: TutorCallStatus.listening,
        isRecording: true,
        statusMessage: 'Listening to your speech...',
        liveSubtitle: '',
      ));
    } catch (e) {
      emit(state.copyWith(
        statusMessage: 'Mic error: $e',
        isRecording: false,
      ));
    }
  }

  Future<void> _onPushToTalkStop(
    PushToTalkStopEvent event,
    Emitter<VoiceTutorState> emit,
  ) async {
    if (!state.isRecording) return;

    _amplitudeController.add(0.0);

    emit(state.copyWith(
      isRecording: false,
      callStatus: TutorCallStatus.transcribing,
      statusMessage: 'Transcribing speech with Whisper...',
    ));

    try {
      final audioBytes = await _recorderService.stopRecording();
      if (audioBytes == null || audioBytes.isEmpty) {
        emit(state.copyWith(
          callStatus: TutorCallStatus.idle,
          statusMessage: 'No speech detected. Please speak again.',
        ));
        return;
      }

      await _repository.sendUserAudio(audioBytes, sessionId: state.sessionId);
    } catch (e) {
      emit(state.copyWith(
        callStatus: TutorCallStatus.idle,
        statusMessage: 'Error sending voice message: $e',
      ));
    }
  }

  void _onStatusUpdateReceived(
    StatusUpdateReceivedEvent event,
    Emitter<VoiceTutorState> emit,
  ) {
    var newStatus = state.callStatus;
    final statusLower = event.status.toLowerCase();

    if (statusLower.contains('thinking')) {
      newStatus = TutorCallStatus.thinking;
    } else if (statusLower.contains('transcribing')) {
      newStatus = TutorCallStatus.transcribing;
    } else if (statusLower.contains('could not detect') ||
               statusLower.contains('try speaking again') ||
               statusLower.contains('error') ||
               statusLower.contains('unavailable') ||
               statusLower.contains('ready') ||
               statusLower.contains('idle')) {
      newStatus = TutorCallStatus.idle;
    }

    emit(state.copyWith(
      statusMessage: event.status,
      callStatus: newStatus,
    ));
  }

  void _onUserTranscribedTextReceived(
    UserTranscribedTextReceivedEvent event,
    Emitter<VoiceTutorState> emit,
  ) {
    final now = DateTime.now();
    final userMsg = TutorMessage(
      id: 'user_${now.millisecondsSinceEpoch}',
      content: event.text,
      isUser: true,
      timestamp: now,
    );

    final tutorPlaceholder = TutorMessage(
      id: 'tutor_${now.millisecondsSinceEpoch}',
      content: '',
      isUser: false,
      timestamp: now,
      isThinking: true,
    );

    emit(state.copyWith(
      messageHistory: [...state.messageHistory, userMsg, tutorPlaceholder],
      callStatus: TutorCallStatus.thinking,
      statusMessage: 'AI is formulating response...',
      liveSubtitle: '',
    ));
  }

  void _onSubtitleTokenReceived(
    SubtitleTokenReceivedEvent event,
    Emitter<VoiceTutorState> emit,
  ) {
    final updatedSubtitle = state.liveSubtitle + event.token;

    final updatedHistory = List<TutorMessage>.from(state.messageHistory);

    // Stream into the currently active streaming Tutor message, or the earliest waiting Tutor message (FIFO)
    int targetIndex = updatedHistory.indexWhere((m) => !m.isUser && m.isStreaming);
    if (targetIndex == -1) {
      targetIndex = updatedHistory.indexWhere((m) => !m.isUser && m.isThinking);
    }

    if (targetIndex != -1) {
      final target = updatedHistory[targetIndex];
      updatedHistory[targetIndex] = target.copyWith(
        content: target.content + event.token,
        isThinking: false,
        isStreaming: true,
      );
    } else {
      updatedHistory.add(TutorMessage(
        id: 'tutor_${DateTime.now().millisecondsSinceEpoch}',
        content: event.token,
        isUser: false,
        timestamp: DateTime.now(),
        isStreaming: true,
        isThinking: false,
      ));
    }

    emit(state.copyWith(
      messageHistory: updatedHistory,
      liveSubtitle: updatedSubtitle,
      callStatus: TutorCallStatus.speaking,
    ));
  }

  Future<void> _onAudioChunkReceived(
    AudioChunkReceivedEvent event,
    Emitter<VoiceTutorState> emit,
  ) async {
    await _playerService.enqueueAudioChunk(event.chunk);
  }

  void _onTurnCompleted(
    TurnCompletedEvent event,
    Emitter<VoiceTutorState> emit,
  ) {
    final updatedHistory = List<TutorMessage>.from(state.messageHistory);

    // Complete the earliest uncompleted Tutor turn (FIFO)
    int targetIndex = updatedHistory.indexWhere((m) => !m.isUser && (m.isStreaming || m.isThinking));

    if (targetIndex != -1) {
      final target = updatedHistory[targetIndex];
      final finalContent = event.fullResponse.isNotEmpty ? event.fullResponse : target.content;
      updatedHistory[targetIndex] = target.copyWith(
        content: finalContent,
        isThinking: false,
        isStreaming: false,
      );
    } else if (event.fullResponse.isNotEmpty) {
      updatedHistory.add(TutorMessage(
        id: 'tutor_${DateTime.now().millisecondsSinceEpoch}',
        content: event.fullResponse,
        isUser: false,
        timestamp: DateTime.now(),
        isThinking: false,
        isStreaming: false,
      ));
    }

    emit(state.copyWith(
      messageHistory: updatedHistory,
      statusMessage: 'Turn completed',
      liveSubtitle: '',
    ));
  }

  Future<void> _onSendTextMessage(
    SendTextMessageEvent event,
    Emitter<VoiceTutorState> emit,
  ) async {
    await _playerService.stop();

    final now = DateTime.now();
    final userMsg = TutorMessage(
      id: 'user_${now.millisecondsSinceEpoch}',
      content: event.text,
      isUser: true,
      timestamp: now,
    );

    final tutorPlaceholder = TutorMessage(
      id: 'tutor_${now.millisecondsSinceEpoch}',
      content: '',
      isUser: false,
      timestamp: now,
      isThinking: true,
    );

    emit(state.copyWith(
      messageHistory: [...state.messageHistory, userMsg, tutorPlaceholder],
      callStatus: TutorCallStatus.thinking,
      statusMessage: 'AI is thinking...',
      liveSubtitle: '',
    ));

    try {
      await _repository.sendUserText(event.text, sessionId: state.sessionId);
    } catch (e) {
      emit(state.copyWith(
        callStatus: TutorCallStatus.idle,
        statusMessage: 'Failed to send text: $e',
      ));
    }
  }

  void _onAudioPlaybackStateChanged(
    AudioPlaybackStateChangedEvent event,
    Emitter<VoiceTutorState> emit,
  ) {
    if (!event.isPlaying) {
      _amplitudeController.add(0.0);
    }

    final newCallStatus = event.isPlaying
        ? TutorCallStatus.speaking
        : (state.callStatus == TutorCallStatus.speaking ? TutorCallStatus.idle : state.callStatus);

    emit(state.copyWith(
      isAudioPlaying: event.isPlaying,
      callStatus: newCallStatus,
      statusMessage: event.isPlaying ? 'Tutor is speaking...' : 'Ready to listen',
    ));
  }

  Future<void> _onDisconnectCall(
    DisconnectCallEvent event,
    Emitter<VoiceTutorState> emit,
  ) async {
    await _playerService.stop();
    await _repository.disconnect();
    emit(state.copyWith(
      callStatus: TutorCallStatus.disconnected,
      statusMessage: 'Call ended',
    ));
  }

  @override
  Future<void> close() async {
    await _statusSubscription?.cancel();
    await _userTranscriptionSubscription?.cancel();
    await _subtitleSubscription?.cancel();
    await _audioChunkSubscription?.cancel();
    await _turnCompletedSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _recorderAmpSubscription?.cancel();
    await _playerAmpSubscription?.cancel();
    await _amplitudeController.close();
    await _playerService.stop();
    await _recorderService.cancelRecording();
    return super.close();
  }
}
