import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0F111A);
  static const Color surface = Color(0xFF181B26);
  static const Color surfaceLight = Color(0xFF222634);
  static const Color card = Color(0xFF1E2230);

  // Brand Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF06B6D4); // Cyan / Electric Blue
  static const Color accent = Color(0xFF10B981); // Emerald Green
  static const Color pinkAccent = Color(0xFFEC4899);

  // Status Colors
  static const Color listening = Color(0xFF10B981);
  static const Color thinking = Color(0xFFF59E0B);
  static const Color speaking = Color(0xFF6366F1);
  static const Color error = Color(0xFFEF4444);

  // Text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient speakingGradient = LinearGradient(
    colors: [Color(0xFF818CF8), Color(0xFFC084FC), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient listeningGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0D0F17), Color(0xFF131722)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
