import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF1A2234);
  static const Color cardBackground = Color(0xFF0F172A);

  // Accent / Brand
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Lovable Design Tokens
  static const Color lovableGreen = Color(0xFF10B981);
  static const Color lovableGreenLight = Color(0xFFD1FAE5);
  static const Color lovableTeal = Color(0xFF06B6D4);
  static const Color lovableTealDark = Color(0xFF004D40);
  static const Color lovableCard = Color(0xFF111927);
  static const Color lovableCardBorder = Color(0xFF1F2937);

  // Risk Colors
  static const Color riskLow = Color(0xFF10B981);       // Green
  static const Color riskModerate = Color(0xFFF59E0B); // Amber
  static const Color riskHigh = Color(0xFFF97316);      // Orange
  static const Color riskCritical = Color(0xFFEF4444);  // Red

  // Text
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);

  // Border / Divider
  static const Color border = Color(0xFF1E293B);
  static const Color borderGlass = Color(0x26FFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentIndigo, accentViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A2234), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lovableGradient = LinearGradient(
    colors: [lovableGreen, lovableTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient lovableWeatherGradient = LinearGradient(
    colors: [Color(0xFF0D3F43), Color(0xFF09252B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme Tokens (Pure White + Green->Teal->Cyan Gradient)
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceElevated = Color(0xFFF8FAFC);
  static const Color lightCardBackground = Colors.white;
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTeal = Color(0xFF14B8A6);

  /// The green → teal → cyan gradient used in the "AI Analyze Route" button
  static const LinearGradient lightHighlightGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundFor(BuildContext context) =>
      isDark(context) ? const Color(0xFF090D16) : lightBackground;

  static Color surfaceFor(BuildContext context) =>
      isDark(context) ? lovableCard : lightSurface;

  static Color surfaceElevatedFor(BuildContext context) =>
      isDark(context) ? surfaceElevated : lightSurfaceElevated;

  static Color borderFor(BuildContext context) =>
      isDark(context) ? lovableCardBorder : lightCardBorder;

  static Color textPrimaryFor(BuildContext context) =>
      isDark(context) ? Colors.white : lightTextPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;

  static Color textMutedFor(BuildContext context) =>
      isDark(context) ? const Color(0xFF64748B) : lightTextMuted;

  static LinearGradient weatherCardGradientFor(BuildContext context) =>
      isDark(context)
          ? const LinearGradient(
              colors: [Color(0xFF09373D), Color(0xFF07242A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : lightHighlightGradient;

  static LinearGradient radarHeroGradientFor(BuildContext context) =>
      isDark(context)
          ? const LinearGradient(
              colors: [Color(0xFF0A373E), Color(0xFF072126)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : lightHighlightGradient;

  static LinearGradient recommendationGradientFor(BuildContext context) =>
      isDark(context)
          ? const LinearGradient(
              colors: [Color(0xFF132035), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : lightHighlightGradient;

  static LinearGradient activeTimelineGradientFor(BuildContext context) =>
      isDark(context)
          ? const LinearGradient(
              colors: [Color(0xFF152238), Color(0xFF1A2B47)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : lightHighlightGradient;

  static List<BoxShadow> cardShadowFor(BuildContext context) => isDark(context)
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      : [
          const BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
          const BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];

  static Color riskColor(double score) {
    if (score <= 25) return riskLow;
    if (score <= 50) return riskModerate;
    if (score <= 75) return riskHigh;
    return riskCritical;
  }

  static String riskLabel(double score) {
    if (score <= 25) return 'Low';
    if (score <= 50) return 'Moderate';
    if (score <= 75) return 'High';
    return 'Critical';
  }
}
