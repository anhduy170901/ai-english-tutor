import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/tutor_entities.dart';

class AudioWaveVisualizer extends StatefulWidget {
  final TutorCallStatus status;
  final bool isRecording;
  final bool isPlaying;
  final Stream<double>? amplitudeStream;

  const AudioWaveVisualizer({
    super.key,
    required this.status,
    required this.isRecording,
    required this.isPlaying,
    this.amplitudeStream,
  });

  @override
  State<AudioWaveVisualizer> createState() => _AudioWaveVisualizerState();
}

class _AudioWaveVisualizerState extends State<AudioWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<double>? _amplitudeSub;
  double _targetAmplitude = 0.0;
  double _currentAmplitude = 0.0;
  double _phase = 0.0;

  @override
  void initState() {
    super.initState();
    _subscribeAmplitude();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    _ticker.repeat();
  }

  @override
  void didUpdateWidget(covariant AudioWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _subscribeAmplitude();
    }
    if (!widget.isRecording && !widget.isPlaying) {
      _targetAmplitude = 0.0;
    }
  }

  void _subscribeAmplitude() {
    _amplitudeSub?.cancel();
    _amplitudeSub = widget.amplitudeStream?.listen((amp) {
      if (widget.isRecording || widget.isPlaying) {
        _targetAmplitude = amp.clamp(0.0, 1.0);
      } else {
        _targetAmplitude = 0.0;
      }
    });
  }

  void _onTick() {
    // Fast attack (when sound arrives), smooth decay (when sound ceases)
    final double lerpSpeed = (_targetAmplitude > _currentAmplitude) ? 0.40 : 0.22;
    _currentAmplitude += (_targetAmplitude - _currentAmplitude) * lerpSpeed;

    if (_targetAmplitude == 0.0 && _currentAmplitude < 0.005) {
      _currentAmplitude = 0.0;
    }

    // Only progress wave phase if there is actual sound input
    if (_currentAmplitude > 0.01) {
      _phase += 0.15;
      if (_phase > 2 * pi * 100) _phase = 0.0;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 38),
      painter: WavePainter(
        amplitude: _currentAmplitude,
        phase: _phase,
        status: widget.status,
        isRecording: widget.isRecording,
        isPlaying: widget.isPlaying,
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double amplitude;
  final double phase;
  final TutorCallStatus status;
  final bool isRecording;
  final bool isPlaying;

  WavePainter({
    required this.amplitude,
    required this.phase,
    required this.status,
    required this.isRecording,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    const int barCount = 35;
    final barSpacing = width / barCount;
    final barWidth = barSpacing * 0.46;
    const double minDotSize = 4.0;
    final double maxBarHeight = height * 0.95;

    Color primaryColor;
    Color secondaryColor;

    final bool isUserActive = isRecording || status == TutorCallStatus.listening;
    final bool isAiActive = isPlaying || status == TutorCallStatus.speaking;

    if (isUserActive) {
      primaryColor = AppColors.accent;
      secondaryColor = AppColors.secondary;
    } else if (isAiActive) {
      primaryColor = AppColors.primaryLight;
      secondaryColor = const Color(0xFFC084FC);
    } else {
      primaryColor = AppColors.primary.withOpacity(0.35);
      secondaryColor = AppColors.secondary.withOpacity(0.20);
    }

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final x = i * barSpacing + barWidth / 2;
      final normalizedX = i / (barCount - 1);

      // Bell curve: center bars are naturally taller, edge bars smaller
      final bellFactor = sin(normalizedX * pi);

      double currentHeight;
      if (amplitude <= 0.005 || (!isUserActive && !isAiActive)) {
        // Flat baseline dots when silent or idle
        currentHeight = minDotSize;
      } else {
        // Multi-frequency natural audio dynamics based on REAL sound amplitude
        final harmonic = 0.50 + 0.32 * sin(i * 1.5 + phase) + 0.18 * cos(i * 2.4 - phase * 0.7);
        final dynamicSpread = bellFactor * harmonic.clamp(0.20, 1.0);
        currentHeight = minDotSize + (maxBarHeight - minDotSize) * amplitude * dynamicSpread;
      }

      paint.shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(x, centerY - currentHeight / 2, barWidth, currentHeight));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, centerY),
            width: barWidth,
            height: currentHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.phase != phase ||
        oldDelegate.status != status ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.isPlaying != isPlaying;
  }
}
