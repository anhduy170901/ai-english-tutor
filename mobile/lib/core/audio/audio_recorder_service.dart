import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract class IAudioRecorderService {
  Stream<double> get amplitudeStream;
  Future<bool> hasPermission();
  Future<void> startRecording();
  Future<Uint8List?> stopRecording();
  Future<void> cancelRecording();
  Future<void> dispose();
}

class AudioRecorderService implements IAudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final _amplitudeController = StreamController<double>.broadcast();
  StreamSubscription? _ampSub;
  String? _currentFilePath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('[AudioRecorderService] Error checking permission: $e');
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    final permitted = await hasPermission();
    if (!permitted) {
      throw Exception('Microphone permission denied');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = '${tempDir.path}/user_speech_$timestamp.wav';

    // 16kHz, 16-bit, Mono WAV (ideal for Whisper.net STT)
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    await _audioRecorder.start(config, path: _currentFilePath!);
    _isRecording = true;
    debugPrint('[AudioRecorderService] Started recording to $_currentFilePath');

    _ampSub?.cancel();
    _ampSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amp) {
      if (!_isRecording) return;
      // amp.current is in dB: silence is around -60 dB to -45 dB.
      // Normal speech is around -35 dB to -10 dB.
      double normalized = 0.0;
      if (amp.current > -50.0) {
        normalized = ((amp.current + 50.0) / 45.0).clamp(0.0, 1.0);
      }
      _amplitudeController.add(normalized);
    });
  }

  @override
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) return null;

    _ampSub?.cancel();
    _ampSub = null;
    _amplitudeController.add(0.0);

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;

      final filePath = path ?? _currentFilePath;
      if (filePath == null) return null;

      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        debugPrint('[AudioRecorderService] Recorded ${bytes.lengthInBytes} bytes');
        // Clean up temp file
        try {
          await file.delete();
        } catch (_) {}
        return bytes;
      }
      return null;
    } catch (e) {
      debugPrint('[AudioRecorderService] Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<void> cancelRecording() async {
    _ampSub?.cancel();
    _ampSub = null;
    _amplitudeController.add(0.0);

    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        _isRecording = false;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('[AudioRecorderService] Error cancelling recording: $e');
        _isRecording = false;
      }
    }
  }

  @override
  Future<void> dispose() async {
    await cancelRecording();
    await _amplitudeController.close();
    _audioRecorder.dispose();
  }
}
