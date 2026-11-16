import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../voice_tutor/presentation/bloc/voice_tutor_bloc.dart';
import '../../../voice_tutor/presentation/pages/voice_call_page.dart';
import '../../domain/entities/cefr_level.dart';
import '../../domain/entities/learning_session.dart';
import '../../domain/usecases/get_active_sessions_usecase.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_event.dart';
import '../bloc/session_state.dart';

class TopicSelectionPage extends StatefulWidget {
  const TopicSelectionPage({super.key});

  @override
  State<TopicSelectionPage> createState() => _TopicSelectionPageState();
}

class _TopicSelectionPageState extends State<TopicSelectionPage> {
  CefrLevel _selectedLevel = CefrLevel.b1;
  String _selectedTopic = 'Casual Conversation & Daily Life';
  final TextEditingController _customTopicController = TextEditingController();

  List<SessionSummaryEntity> _activeSessions = [];
  bool _loadingActiveSessions = true;

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
  }

  Future<void> _loadActiveSessions() async {
    try {
      final sessions = await sl<GetActiveSessionsUseCase>()();
      if (!mounted) return;
      setState(() {
        _activeSessions = sessions;
        _loadingActiveSessions = false;
      });
    } catch (_) {
      // Resuming is a convenience feature — fail silently and just show
      // the "start new session" flow if the list can't be fetched.
      if (!mounted) return;
      setState(() => _loadingActiveSessions = false);
    }
  }

  void _resumeSession(SessionSummaryEntity session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<VoiceTutorBloc>(),
          child: VoiceCallPage(
            topic: session.topic,
            level: session.targetLevel,
            sessionId: session.id,
          ),
        ),
      ),
    );
  }

  final List<Map<String, dynamic>> _topics = [
    {
      'title': 'Casual Conversation & Daily Life',
      'icon': Icons.chat_bubble_outline_rounded,
      'description': 'Chat about hobbies, weather, food, and daily routines.',
      'gradient': const [Color(0xFF6366F1), Color(0xFF818CF8)],
    },
    {
      'title': 'IELTS Speaking Practice',
      'icon': Icons.school_rounded,
      'description': 'Simulate IELTS Part 1, 2, and 3 with instant grammar tips.',
      'gradient': const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    },
    {
      'title': 'Job Interview Simulation',
      'icon': Icons.business_center_rounded,
      'description': 'Prepare for behavioral and technical English questions.',
      'gradient': const [Color(0xFF10B981), Color(0xFF059669)],
    },
    {
      'title': 'Tech Talk & Engineering',
      'icon': Icons.terminal_rounded,
      'description': 'Discuss software design, AI, architecture, and coding.',
      'gradient': const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    },
    {
      'title': 'Travel & Airport Scenarios',
      'icon': Icons.flight_takeoff_rounded,
      'description': 'Check-in, booking hotels, ordering food, and asking directions.',
      'gradient': const [Color(0xFFF59E0B), Color(0xFFEF4444)],
    },
  ];

  @override
  void dispose() {
    _customTopicController.dispose();
    super.dispose();
  }

  void _startSession() {
    final topic = _customTopicController.text.trim().isNotEmpty
        ? _customTopicController.text.trim()
        : _selectedTopic;

    context.read<SessionBloc>().add(
          StartSessionRequested(
            topic: topic,
            targetLevel: _selectedLevel,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listener: (context, state) {
        if (state is SessionCreated) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => sl<VoiceTutorBloc>(),
                child: VoiceCallPage(
                  topic: state.topic,
                  level: state.targetLevel,
                  sessionId: state.sessionId,
                ),
              ),
            ),
          );
        } else if (state is SessionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Branding Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.record_voice_over_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI English Tutor',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text(
                                    'Real-time Voice Conversation',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: AppColors.accent),
                            SizedBox(width: 6),
                            Text(
                              '<1s Latency',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),

                  if (!_loadingActiveSessions && _activeSessions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'CONTINUE A SESSION',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _activeSessions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final session = _activeSessions[index];
                          return InkWell(
                            onTap: () => _resumeSession(session),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          session.targetLevel.code,
                                          style: const TextStyle(
                                            color: AppColors.primaryLight,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.play_circle_fill_rounded,
                                          color: AppColors.accent.withOpacity(0.8), size: 16),
                                    ],
                                  ),
                                  Text(
                                    session.topic,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${session.messageCount} msgs · ${DateFormat('MMM d, HH:mm').format(session.createdAt.toLocal())}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // CEFR Level Selector Title
                  const Text(
                    '1. SELECT YOUR CEFR LEVEL',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CEFR Chips Horizontal List
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CefrLevel.values.map((level) {
                        final isSelected = level == _selectedLevel;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${level.code} - ${level.label}'),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedLevel = level);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Level Description Pill
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _selectedLevel.description,
                      style: TextStyle(
                        color: AppColors.secondary.withOpacity(0.9),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Topic Selection Title
                  const Text(
                    '2. SELECT PRACTICE TOPIC',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Topic Cards
                  ..._topics.map((t) {
                    final isSelected = _selectedTopic == t['title'];
                    final List<Color> gradient = t['gradient'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTopic = t['title'];
                            _customTopicController.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? gradient.first.withOpacity(0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? gradient.first
                                  : Colors.white.withOpacity(0.06),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: gradient.first.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  t['icon'] as IconData,
                                  color: gradient.first,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['title'] as String,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t['description'] as String,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: gradient.first, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // Custom Topic Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: _customTopicController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.edit_note_rounded, color: AppColors.secondary),
                        hintText: 'Or enter custom topic (e.g. Crypto, Cooking)...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onChanged: (text) {
                        if (text.isNotEmpty) {
                          setState(() => _selectedTopic = text);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Start Call Button
                  BlocBuilder<SessionBloc, SessionState>(
                    builder: (context, state) {
                      final isLoading = state is SessionLoading;

                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isLoading ? null : _startSession,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.call_rounded, color: Colors.white),
                                        SizedBox(width: 10),
                                        Text(
                                          'Start Voice Tutoring Call',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
