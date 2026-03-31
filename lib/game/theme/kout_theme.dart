import 'dart:ui';
import 'package:flutter/material.dart' show TextStyle, FontWeight;

class KoutTheme {
  static const Color primary = Color(0xFF425944);
  static const Color accent = Color(0xFF738C5A);
  static const Color table = Color(0xFF2F403E);
  static const Color textColor = Color(0xFFBACDD9);
  static const Color secondary = Color(0xFF516D73);
  static const Color cardBack = Color(0xFF425944);
  static const Color cardFace = Color(0xFFFFFFF0);
  static const Color cardBorder = Color(0xFF738C5A);
  static const Color teamAColor = Color(0xFF4A90D9);
  static const Color teamBColor = Color(0xFFD94A4A);
  static const double cardWidth = 70;
  static const double cardHeight = 100;
  static const double cardBorderRadius = 6;

  // ---------------------------------------------------------------------------
  // Semantic colors
  // ---------------------------------------------------------------------------

  static const Color lossColor = Color(0xFFE57373);
  static const Color buttonForeground = Color(0xFF3B1A1B);
  static const Color progressBarBg = Color(0x33F5ECD7);

  // ---------------------------------------------------------------------------
  // Typography — Latin
  // ---------------------------------------------------------------------------

  static TextStyle get headingStyle => const TextStyle(
        fontFamily: 'IBMPlexMono',
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyStyle => const TextStyle(
        fontFamily: 'IBMPlexMono',
        color: textColor,
        fontSize: 14,
      );

  // ---------------------------------------------------------------------------
  // Typography — Arabic
  // ---------------------------------------------------------------------------

  static TextStyle get arabicHeadingStyle => const TextStyle(
        fontFamily: 'NotoKufiArabic',
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get arabicBodyStyle => const TextStyle(
        fontFamily: 'NotoKufiArabic',
        color: textColor,
        fontSize: 14,
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
