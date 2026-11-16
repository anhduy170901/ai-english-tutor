import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

abstract class IAudioPlayerService {
  Stream<bool> get isPlayingStream;
  Stream<double> get amplitudeStream;
  bool get isPlaying;
  Future<void> enqueueAudioChunk(Uint8List chunk);
  Future<void> stop();
  Future<void> dispose();
}

class AudioPlayerService implements IAudioPlayerService {
  bool _isSetup = false;
  bool _isStarted = false;
  final _isPlayingController = StreamController<bool>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  final List<double> _amplitudeQueue = [];
  Timer? _amplitudeTimer;

  // flutter_bloc only guarantees sequential handling *within* a single event type —
  // AudioChunkReceivedEvent and SendTextMessageEvent/PushToTalkStartEvent are handled
  // independently, so a stop() triggered by a barge-in can run concurrently with an
  // enqueueAudioChunk() still awaiting a native feed() call. Without this queue, that
  // race lets release() tear down the native session mid-feed, surfacing as
  // "PlatformException(Setup, must call setup first)" — this funnels every public
  // operation through one linear chain so they can never interleave.
  Future<void> _opQueue = Future.value();

  Future<void> _synchronized(Future<void> Function() operation) {
    final result = _opQueue.then((_) => operation());
    _opQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  bool get isPlaying => _isStarted;

  void _startAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isStarted) {
        timer.cancel();
        _amplitudeTimer = null;
        _amplitudeQueue.clear();
        _amplitudeController.add(0.0);
        return;
      }

      if (_amplitudeQueue.isNotEmpty) {
        final amp = _amplitudeQueue.removeAt(0);
        _amplitudeController.add(amp);
      } else {
        _amplitudeController.add(0.0);
      }
    });
  }

  void _stopAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudeQueue.clear();
    _amplitudeController.add(0.0);
  }

  void _enqueueChunkAmplitudes(ByteData byteData) {
    const int sliceBytes = 2400; // 50ms at 24kHz 16-bit mono
    final totalBytes = byteData.lengthInBytes;

    for (int offset = 0; offset < totalBytes; offset += sliceBytes) {
      final length = (offset + sliceBytes <= totalBytes) ? sliceBytes : totalBytes - offset;
      final sampleCount = length ~/ 2;
      if (sampleCount <= 0) continue;

      double sumSquares = 0.0;
      for (int i = 0; i < length - 1; i += 2) {
        final sample = byteData.getInt16(offset + i, Endian.little);
        sumSquares += sample * sample;
      }
      final rms = sqrt(sumSquares / sampleCount);
      // Kokoro voice RMS typically ranges from 800 to 5000.
      final normalized = (rms / 4500.0).clamp(0.0, 1.0);
      _amplitudeQueue.add(normalized);
    }
  }

  Future<void> _ensureSetup() async {
    if (_isSetup) return;
    await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(4000);
    FlutterPcmSound.setFeedCallback((remainingFrames) {
      if (remainingFrames == 0) {
        if (_isStarted) {
          _isStarted = false;
          _isPlayingController.add(false);
          _stopAmplitudeTimer();
        }
      }
    });
    _isSetup = true;
  }

  @override
  Future<void> enqueueAudioChunk(Uint8List chunk) {
    if (chunk.isEmpty) return Future.value();

    return _synchronized(() async {
      try {
        await _ensureSetup();

        // Backend guarantees even byte length.
        final Uint8List safeBytes = (chunk.offsetInBytes == 0 && chunk.lengthInBytes == chunk.buffer.lengthInBytes)
            ? chunk
            : Uint8List.fromList(chunk);

        final byteData = safeBytes.buffer.asByteData(safeBytes.offsetInBytes, safeBytes.lengthInBytes);

        // Queue calculated RMS amplitudes for this chunk
        _enqueueChunkAmplitudes(byteData);

        await FlutterPcmSound.feed(
          PcmArrayInt16(bytes: byteData),
        );

        if (!_isStarted) {
          FlutterPcmSound.start();
          _isStarted = true;
          _isPlayingController.add(true);
          _startAmplitudeTimer();
        }
      } catch (e) {
        debugPrint('[AudioPlayerService] Dropped a chunk after a setup/feed error: $e');
        _isSetup = false;
        _stopAmplitudeTimer();
      }
    });
  }

  @override
  Future<void> stop() {
    return _synchronized(() async {
      _isStarted = false;
      _isPlayingController.add(false);
      _stopAmplitudeTimer();
      if (_isSetup) {
        try {
          await FlutterPcmSound.release();
        } catch (e) {
          debugPrint('[AudioPlayerService] Error releasing PCM sound: $e');
        }
        _isSetup = false;
      }
    });
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _isPlayingController.close();
    await _amplitudeController.close();
  }
}
