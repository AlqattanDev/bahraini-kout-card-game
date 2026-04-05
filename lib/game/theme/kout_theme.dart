import 'dart:ui';
import 'package:flutter/material.dart' show TextStyle, FontWeight, ButtonStyle, ElevatedButton, EdgeInsets, RoundedRectangleBorder, BorderRadius, BorderSide;
import '../../shared/models/card.dart';
import '../../shared/models/game_state.dart';
import 'diwaniya_colors.dart';

class KoutTheme {
  static const Color primary = Color(0xFF425944);
  static const Color accent = Color(0xFF738C5A);
  static const Color table = Color(0xFF2F403E);
  static const Color textColor = Color(0xFFBACDD9);
  static const Color secondary = Color(0xFF516D73);
  static const Color cardBack = Color(0xFF425944);
  static const Color cardFace = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color teamAColor = Color(0xFF4A90D9);
  static const Color teamBColor = Color(0xFFD94A4A);

  /// Suit color for card faces and similar on-light-background contexts.
  static Color suitCardColor(Suit suit) =>
      suit.isRed ? const Color(0xFFCC0000) : const Color(0xFF111111);

  /// Team color lookup.
  static Color teamColor(Team team) =>
      team == Team.a ? teamAColor : teamBColor;
  static const double cardWidth = 70;
  static const double cardHeight = 100;
  static const double cardBorderRadius = 6;
  static const Color jokerColor = Color(0xFF1A1A1A);
  static const double cardCornerRankSize = 16.0;
  static const double cardCornerSuitSize = 14.0;
  static const double cardCenterSuitSize = 40.0;
  static const double cardShadowBlur = 6.0;
  static const double cardShadowOffsetX = 3.0;
  static const double cardShadowOffsetY = 4.0;
  static const Color cardShadowColor = Color(0x88000000);

  // Enhanced Diwaniya palette (delegates to DiwaniyaColors)
  static const Color goldAccent = DiwaniyaColors.goldAccent;
  static const Color goldHighlight = DiwaniyaColors.goldHighlight;
  static const Color cream = DiwaniyaColors.cream;

  // Increased card dimensions for better readability
  static const double cardWidthLarge = 80;
  static const double cardHeightLarge = 114;
  static const double cardCenterSuitSizeLarge = 42.0;

  // ---------------------------------------------------------------------------
  // Semantic colors
  // ---------------------------------------------------------------------------

  static const Color lossColor = Color(0xFFE57373);
  static const Color buttonForeground = Color(0xFF3B1A1B);
  static const Color progressBarBg = Color(0x33F5ECD7);

  // ---------------------------------------------------------------------------
  // Typography — font families
  // ---------------------------------------------------------------------------

  static const String monoFontFamily = 'IBMPlexMono';
  static const String arabicFontFamily = 'NotoKufiArabic';

  // ---------------------------------------------------------------------------
  // Typography — Latin
  // ---------------------------------------------------------------------------

  static TextStyle get headingStyle => const TextStyle(
        fontFamily: monoFontFamily,
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyStyle => const TextStyle(
        fontFamily: monoFontFamily,
        color: textColor,
        fontSize: 14,
      );

  // ---------------------------------------------------------------------------
  // Typography — Arabic
  // ---------------------------------------------------------------------------

  static TextStyle get arabicHeadingStyle => const TextStyle(
        fontFamily: arabicFontFamily,
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get arabicBodyStyle => const TextStyle(
        fontFamily: arabicFontFamily,
        color: textColor,
        fontSize: 14,
      );

  // ---------------------------------------------------------------------------
  // Shared button styles
  // ---------------------------------------------------------------------------

  /// Primary button: dark background, gold text/border, rounded.
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: accent, width: 1.5),
        ),
        textStyle: bodyStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );

  /// Secondary button: same shape, muted colors.
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: table,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: secondary, width: 1.5),
        ),
        textStyle: bodyStyle.copyWith(fontSize: 16),
      );

  // ---------------------------------------------------------------------------
  // Bilingual game terms
  //
  // Each entry is (englishLabel, arabicLabel).
  // ---------------------------------------------------------------------------

  static const Map<String, (String, String)> gameTerms = {
    'bab': ('Bab', 'باب'),
    'kout': ('Kout', 'كوت'),
    'malzoom': ('Malzoom', 'ملزوم'),
    'pass': ('Pass', 'باس'),
    'trump': ('Trump', 'حكم'),
    'yourTurn': ('Your turn', 'دورك'),
  };
}
