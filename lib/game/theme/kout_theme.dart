import 'dart:ui';
import 'package:flutter/material.dart' show TextStyle, FontWeight;
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
  static const Color teamAColor = Color(0xFF4A90D9);
  static const Color teamBColor = Color(0xFFD94A4A);

  /// Suit color for card faces and similar on-light-background contexts.
  static Color suitCardColor(Suit suit) =>
      suit.isRed ? const Color(0xFFCC0000) : const Color(0xFF111111);

  /// Suit color for HUD/dark-background contexts — all suits must be visible.
  /// Black suits get cream/gold instead of black.
  static Color suitHudColor(Suit suit) =>
      suit.isRed ? const Color(0xFFCC0000) : DiwaniyaColors.goldAccent;

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

}
