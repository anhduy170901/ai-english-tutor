import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/tutor_entities.dart';
import 'typing_indicator_dots.dart';

class RealtimeSubtitleView extends StatefulWidget {
  final String liveSubtitle;
  final List<TutorMessage> messageHistory;
  final TutorCallStatus status;

  const RealtimeSubtitleView({
    super.key,
    required this.liveSubtitle,
    required this.messageHistory,
    required this.status,
  });

  @override
  State<RealtimeSubtitleView> createState() => _RealtimeSubtitleViewState();
}

class _RealtimeSubtitleViewState extends State<RealtimeSubtitleView> {
  final ScrollController _scrollController = ScrollController();
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // If user is more than 60px away from bottom, consider them scrolled up
    final isScrolledUp = (maxScroll - currentScroll) > 60;
    if (isScrolledUp != _userScrolledUp) {
      setState(() {
        _userScrolledUp = isScrolledUp;
      });
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeSubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewMessage = widget.messageHistory.length != oldWidget.messageHistory.length;
    final hasContentChange = widget.messageHistory.isNotEmpty &&
        oldWidget.messageHistory.isNotEmpty &&
        widget.messageHistory.last.content != oldWidget.messageHistory.last.content;
    final hasNewSubtitle = widget.liveSubtitle != oldWidget.liveSubtitle;

    if (hasNewMessage || hasContentChange || hasNewSubtitle) {
      // If user sends a new message, reset scroll lock to follow
      if (hasNewMessage && widget.messageHistory.isNotEmpty && widget.messageHistory.last.isUser) {
        _userScrolledUp = false;
      }

      // Only auto-scroll to bottom if user is not reading earlier messages
      if (!_userScrolledUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      setState(() {
        _userScrolledUp = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.status == TutorCallStatus.speaking
                              ? AppColors.primaryLight
                              : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE TRANSCRIPT',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  if (widget.status == TutorCallStatus.speaking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Streaming',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full conversation history with paired User and Tutor bubbles
                      if (widget.messageHistory.isNotEmpty) ...[
                        for (final msg in widget.messageHistory) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: msg.isUser
                                ? RichText(
                                    text: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'You: ',
                                          style: TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        TextSpan(
                                          text: msg.content,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : (msg.isThinking && msg.content.isEmpty)
                                    // Typing indicator when Tutor is thinking
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Tutor: ',
                                            style: TextStyle(
                                              color: AppColors.primaryLight,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          TypingIndicatorDots(),
                                        ],
                                      )
                                    // Completed or streaming text
                                    : RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Tutor: ',
                                              style: TextStyle(
                                                color: AppColors.primaryLight,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            TextSpan(
                                              text: msg.content,
                                              style: TextStyle(
                                                color: msg.isStreaming
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                                fontWeight: msg.isStreaming
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                          ),
                        ],
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              'Press and hold the button below to introduce yourself or ask a question.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textMuted.withOpacity(0.8),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating button to jump back to newest messages when scrolled up
          if (_userScrolledUp)
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Newest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
