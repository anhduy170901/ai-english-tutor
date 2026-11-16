import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';
import '../utils/app_logger.dart';

abstract class ISignalRService {
  HubConnectionState get state;
  Stream<String> get statusUpdates;
  Stream<String> get userTranscriptions;
  Stream<String> get subtitleTokens;
  Stream<Uint8List> get audioChunks;
  Stream<String> get turnCompletions;

  Future<void> connect();
  Future<void> disconnect();
  Future<String?> startSession(String topic, int level);
  Future<void> sendAudio(Uint8List audioBytes, {String? sessionId});
  Future<void> sendText(String text, {String? sessionId});
}

class SignalRService implements ISignalRService {
  HubConnection? _hubConnection;

  static const _uuid = Uuid();
  // The id of the turn we're currently listening for — set the instant a new
  // ProcessUserAudio/ProcessUserText is sent, before the server even receives it. Any
  // ReceiveAudioChunk/ReceiveSubtitleToken tagged with an older turn id (still in flight
  // over the network when a barge-in happened) is dropped instead of contaminating the
  // new turn's audio/subtitle — see VoiceHub.BeginNewTurn for the server side of this.
  String? _currentTurnId;

  final _statusController = StreamController<String>.broadcast();
  final _userTranscriptionController = StreamController<String>.broadcast();
  final _subtitleTokenController = StreamController<String>.broadcast();
  final _audioChunkController = StreamController<Uint8List>.broadcast();
  final _turnCompletionController = StreamController<String>.broadcast();

  @override
  HubConnectionState get state => _hubConnection?.state ?? HubConnectionState.Disconnected;

  @override
  Stream<String> get statusUpdates => _statusController.stream;

  @override
  Stream<String> get userTranscriptions => _userTranscriptionController.stream;

  @override
  Stream<String> get subtitleTokens => _subtitleTokenController.stream;

  @override
  Stream<Uint8List> get audioChunks => _audioChunkController.stream;

  @override
  Stream<String> get turnCompletions => _turnCompletionController.stream;

  @override
  Future<void> connect() async {
    if (_hubConnection?.state == HubConnectionState.Connected) return;

    final hubUrl = ApiConstants.hubUrl;
    AppLogger.info('Connecting to SignalR Hub: $hubUrl ...');

    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    // Register event listeners
    _hubConnection!.on('StatusUpdate', _onStatusUpdate);
    _hubConnection!.on('UserTranscribedText', _onUserTranscribedText);
    _hubConnection!.on('ReceiveSubtitleToken', _onReceiveSubtitleToken);
    _hubConnection!.on('ReceiveAudioChunk', _onReceiveAudioChunk);
    _hubConnection!.on('TurnCompleted', _onTurnCompleted);

    _hubConnection!.onclose(({error}) {
      AppLogger.warning('SignalR Hub closed. Error: $error');
      _statusController.add('Connection closed');
    });

    _hubConnection!.onreconnecting(({error}) {
      AppLogger.warning('SignalR Reconnecting... Error: $error');
      _statusController.add('Reconnecting...');
    });

    _hubConnection!.onreconnected(({connectionId}) {
      AppLogger.info('SignalR Reconnected with ID: $connectionId');
      _statusController.add('Reconnected');
    });

    try {
      await _hubConnection!.start();
      AppLogger.info('SignalR Connected successfully. State: ${_hubConnection?.state}');
    } catch (e) {
      AppLogger.signalrError('connect() to $hubUrl', e);
      rethrow;
    }
  }

  void _onStatusUpdate(List<dynamic>? arguments) {
    if (arguments != null && arguments.isNotEmpty) {
      final msg = arguments[0].toString();
      AppLogger.signalrEvent('StatusUpdate', msg);
      _statusController.add(msg);
    }
  }

  void _onUserTranscribedText(List<dynamic>? arguments) {
    if (arguments != null && arguments.isNotEmpty) {
      final text = arguments[0].toString();
      AppLogger.signalrEvent('UserTranscribedText', text);
      _userTranscriptionController.add(text);
    }
  }

  void _onReceiveSubtitleToken(List<dynamic>? arguments) {
    if (arguments != null && arguments.length >= 2) {
      final token = arguments[0].toString();
      final turnId = arguments[1].toString();
      if (turnId != _currentTurnId) return; // stale turn, interrupted by a newer one
      _subtitleTokenController.add(token);
    }
  }

  void _onReceiveAudioChunk(List<dynamic>? arguments) {
    if (arguments != null && arguments.length >= 2) {
      final raw = arguments[0];
      final turnId = arguments[1].toString();
      if (turnId != _currentTurnId) return; // stale turn, interrupted by a newer one

      Uint8List? bytes;

      if (raw is Uint8List) {
        bytes = raw;
      } else if (raw is List) {
        bytes = Uint8List.fromList(raw.cast<int>());
      } else if (raw is String) {
        // Handle base64 encoded byte array in JSON serialization
        try {
          bytes = base64Decode(raw);
        } catch (_) {}
      }

      if (bytes != null && bytes.isNotEmpty) {
        _audioChunkController.add(bytes);
      }
    }
  }

  void _onTurnCompleted(List<dynamic>? arguments) {
    if (arguments != null && arguments.isNotEmpty) {
      final fullResponse = arguments[0].toString();
      AppLogger.signalrEvent('TurnCompleted', fullResponse);
      _turnCompletionController.add(fullResponse);
    }
  }

  @override
  Future<String?> startSession(String topic, int level) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      await connect();
    }
    AppLogger.signalrInvoke('StartSession', [topic, level]);
    try {
      final result = await _hubConnection!.invoke('StartSession', args: [topic, level]);
      AppLogger.info('StartSession Result: $result');
      return result?.toString();
    } catch (e) {
      AppLogger.signalrError('invoke(StartSession)', e);
      rethrow;
    }
  }

  @override
  Future<void> sendAudio(Uint8List audioBytes, {String? sessionId}) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      await connect();
    }
    final turnId = _uuid.v4();
    // Set synchronously, before anything is even sent over the wire — this is what makes the
    // stale-turn filter in _onReceive* race-proof against a chunk from the previous turn that's
    // still crossing the network at this exact moment.
    _currentTurnId = turnId;
    final List<Object> args = sessionId != null ? [audioBytes, turnId, sessionId] : [audioBytes, turnId];
    AppLogger.signalrInvoke('ProcessUserAudio', ['${audioBytes.length} bytes', 'turnId: $turnId', 'sessionId: $sessionId']);
    try {
      // send() (fire-and-forget) instead of invoke(): ProcessUserAudio can run for many
      // seconds (STT+LLM+TTS) and all real results/errors arrive via server-pushed events
      // (StatusUpdate, ReceiveAudioChunk, TurnCompleted...). invoke() would await the
      // *entire* turn's completion here — and since Bloc processes events sequentially,
      // that silently blocked a second push-to-talk from ever reaching the server while
      // the first turn was still being generated, so barge-in never had a chance to fire.
      await _hubConnection!.send('ProcessUserAudio', args: args);
      AppLogger.info('ProcessUserAudio sent.');
    } catch (e) {
      AppLogger.signalrError('send(ProcessUserAudio)', e);
      rethrow;
    }
  }

  @override
  Future<void> sendText(String text, {String? sessionId}) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      await connect();
    }
    final turnId = _uuid.v4();
    _currentTurnId = turnId;
    final List<Object> args = sessionId != null ? [text, turnId, sessionId] : [text, turnId];
    AppLogger.signalrInvoke('ProcessUserText', ['text: "$text"', 'turnId: $turnId', 'sessionId: $sessionId']);
    try {
      // Fire-and-forget — see the comment in sendAudio() for why this must not be invoke().
      await _hubConnection!.send('ProcessUserText', args: args);
      AppLogger.info('ProcessUserText sent.');
    } catch (e) {
      AppLogger.signalrError('send(ProcessUserText)', e);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      AppLogger.info('Disconnecting SignalR Hub...');
      await _hubConnection!.stop();
      _hubConnection = null;
    }
  }
}
