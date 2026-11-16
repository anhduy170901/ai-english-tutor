import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/tutor_entities.dart';

class PushToTalkButton extends StatefulWidget {
  final TutorCallStatus status;
  final bool isRecording;
  final VoidCallback onPressedStart;
  final VoidCallback onPressedStop;

  const PushToTalkButton({
    super.key,
    required this.status,
    required this.isRecording,
    required this.onPressedStart,
    required this.onPressedStop,
  });

  @override
  State<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<PushToTalkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.status == TutorCallStatus.connecting) return;

    HapticFeedback.mediumImpact();
    setState(() => _isPressed = true);
    widget.onPressedStart();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isPressed) return;

    HapticFeedback.lightImpact();
    setState(() => _isPressed = false);
    widget.onPressedStop();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    widget.onPressedStop();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.isRecording || widget.status == TutorCallStatus.listening;
    final isBusy = widget.status == TutorCallStatus.thinking ||
        widget.status == TutorCallStatus.transcribing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Pulsing Halo Ring
              if (isListening)
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 98 * _scaleAnimation.value,
                      height: 98 * _scaleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withOpacity(0.25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Main Circular Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isListening
                      ? AppColors.listeningGradient
                      : (isBusy ? null : AppColors.primaryGradient),
                  color: isBusy ? AppColors.surfaceLight : null,
                  boxShadow: [
                    BoxShadow(
                      color: (isListening ? AppColors.accent : AppColors.primary)
                          .withOpacity(0.4),
                      blurRadius: _isPressed ? 24 : 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isListening
                        ? Icons.mic
                        : (isBusy ? Icons.hourglass_top_rounded : Icons.mic_none_rounded),
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            isListening
                ? 'RELEASE TO SEND'
                : (isBusy
                    ? 'AI IS WORKING...'
                    : 'HOLD TO SPEAK'),
            key: ValueKey('${isListening}_$isBusy'),
            style: TextStyle(
              color: isListening
                  ? AppColors.accent
                  : (isBusy ? AppColors.thinking : AppColors.textSecondary),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
