import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/tutor_entities.dart';

class TutorStatusBadge extends StatelessWidget {
  final TutorCallStatus status;
  final String? customMessage;

  const TutorStatusBadge({
    super.key,
    required this.status,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData iconData;

    switch (status) {
      case TutorCallStatus.listening:
        badgeColor = AppColors.accent;
        iconData = Icons.graphic_eq_rounded;
        break;
      case TutorCallStatus.transcribing:
        badgeColor = AppColors.thinking;
        iconData = Icons.hearing_rounded;
        break;
      case TutorCallStatus.thinking:
        badgeColor = AppColors.thinking;
        iconData = Icons.psychology_rounded;
        break;
      case TutorCallStatus.speaking:
        badgeColor = AppColors.primaryLight;
        iconData = Icons.volume_up_rounded;
        break;
      case TutorCallStatus.connecting:
        badgeColor = AppColors.secondary;
        iconData = Icons.sync_rounded;
        break;
      case TutorCallStatus.error:
        badgeColor = AppColors.error;
        iconData = Icons.error_outline_rounded;
        break;
      case TutorCallStatus.idle:
      case TutorCallStatus.disconnected:
      default:
        badgeColor = AppColors.textSecondary;
        iconData = Icons.check_circle_outline_rounded;
        break;
    }

    final displayText = customMessage?.isNotEmpty == true ? customMessage! : status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: badgeColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badgeColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
