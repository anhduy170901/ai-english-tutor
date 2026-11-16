import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../session/domain/entities/cefr_level.dart';
import '../../../session/presentation/pages/session_summary_page.dart';
import '../../domain/entities/tutor_entities.dart';
import '../bloc/voice_tutor_bloc.dart';
import '../bloc/voice_tutor_event.dart';
import '../bloc/voice_tutor_state.dart';
import '../widgets/audio_wave_visualizer.dart';
import '../widgets/push_to_talk_button.dart';
import '../widgets/realtime_subtitle_view.dart';
import '../widgets/tutor_status_badge.dart';

class VoiceCallPage extends StatefulWidget {
  final String topic;
  final CefrLevel level;
  final String? sessionId;

  const VoiceCallPage({
    super.key,
    required this.topic,
    required this.level,
    this.sessionId,
  });

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  final TextEditingController _textInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<VoiceTutorBloc>().add(
          InitializeVoiceCallEvent(
            topic: widget.topic,
            level: widget.level,
            existingSessionId: widget.sessionId,
          ),
        );
  }

  @override
  void dispose() {
    _textInputController.dispose();
    super.dispose();
  }

  void _showEndSessionDialog(BuildContext context, String? sessionId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Tutoring Session?'),
        content: const Text(
          'Would you like to wrap up this conversation and view your feedback & grammar summary?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Continue Session'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<VoiceTutorBloc>().add(DisconnectCallEvent());
              if (sessionId != null && sessionId.isNotEmpty) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionSummaryPage(sessionId: sessionId),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('End & Review'),
          ),
        ],
      ),
    );
  }

  void _sendTextMessage() {
    final text = _textInputController.text.trim();
    if (text.isEmpty) return;
    _textInputController.clear();
    context.read<VoiceTutorBloc>().add(SendTextMessageEvent(text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceTutorBloc, VoiceTutorState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSpeaking = state.callStatus == TutorCallStatus.speaking;
        final isListening = state.isRecording || state.callStatus == TutorCallStatus.listening;
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Custom App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _showEndSessionDialog(context, state.sessionId),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.topic,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.level.code,
                                      style: const TextStyle(
                                        color: AppColors.primaryLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.level.label,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showEndSessionDialog(context, state.sessionId),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.error.withOpacity(0.15),
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Status Badge
                  TutorStatusBadge(
                    status: state.callStatus,
                    customMessage: state.statusMessage,
                  ).animate().fadeIn().scale(duration: 200.ms),

                  if (!isKeyboardOpen) ...[
                    const SizedBox(height: 12),

                    // Central AI Tutor Avatar / Glowing Sphere
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Animated Outer Glow
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: isSpeaking ? 130 : (isListening ? 120 : 110),
                            height: isSpeaking ? 130 : (isListening ? 120 : 110),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isSpeaking
                                  ? AppColors.speakingGradient
                                  : (isListening
                                      ? AppColors.listeningGradient
                                      : AppColors.primaryGradient),
                              boxShadow: [
                                BoxShadow(
                                  color: (isSpeaking
                                          ? AppColors.primaryLight
                                          : (isListening ? AppColors.accent : AppColors.primary))
                                      .withOpacity(0.45),
                                  blurRadius: isSpeaking ? 40 : 25,
                                  spreadRadius: isSpeaking ? 10 : 3,
                                ),
                              ],
                            ),
                          ),
                          // Inner Core
                          Container(
                            width: 86,
                            height: 86,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                            ),
                            child: Icon(
                              isSpeaking
                                  ? Icons.graphic_eq_rounded
                                  : (isListening ? Icons.hearing_rounded : Icons.auto_awesome_rounded),
                              size: 36,
                              color: isSpeaking
                                  ? AppColors.primaryLight
                                  : (isListening ? AppColors.accent : AppColors.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Dynamic Audio Wave Visualizer
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AudioWaveVisualizer(
                        status: state.callStatus,
                        isRecording: state.isRecording,
                        isPlaying: state.isAudioPlaying,
                        amplitudeStream: context.read<VoiceTutorBloc>().amplitudeStream,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Realtime Subtitle View
                  Expanded(
                    child: RealtimeSubtitleView(
                      liveSubtitle: state.liveSubtitle,
                      messageHistory: state.messageHistory,
                      status: state.callStatus,
                    ),
                  ),

                  if (!isKeyboardOpen) ...[
                    const SizedBox(height: 10),

                    // Push To Talk Button
                    PushToTalkButton(
                      status: state.callStatus,
                      isRecording: state.isRecording,
                      onPressedStart: () {
                        context.read<VoiceTutorBloc>().add(PushToTalkStartEvent());
                      },
                      onPressedStop: () {
                        context.read<VoiceTutorBloc>().add(PushToTalkStopEvent());
                      },
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Text fallback input bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: TextField(
                              controller: _textInputController,
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Or type a message to tutor...',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                              ),
                              onSubmitted: (_) => _sendTextMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sendTextMessage,
                          icon: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
