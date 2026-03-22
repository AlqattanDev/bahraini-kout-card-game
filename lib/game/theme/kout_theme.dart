import 'dart:ui';
import 'package:flutter/material.dart' show TextStyle, FontWeight;
import 'package:google_fonts/google_fonts.dart';

class KoutTheme {
  static const Color primary = Color(0xFF5C1A1B);
  static const Color accent = Color(0xFFC9A84C);
  static const Color table = Color(0xFF3B2314);
  static const Color textColor = Color(0xFFF5ECD7);
  static const Color secondary = Color(0xFF8B5E3C);
  static const Color cardBack = Color(0xFF5C1A1B);
  static const Color cardFace = Color(0xFFFFFFF0);
  static const Color cardBorder = Color(0xFFFFFFFF);
  static const Color teamAColor = Color(0xFFC9A84C);
  static const Color teamBColor = Color(0xFF8B5E3C);
  static const double cardWidth = 70;
  static const double cardHeight = 100;
  static const double cardBorderRadius = 6;

  // ---------------------------------------------------------------------------
  // Typography — Latin
  // ---------------------------------------------------------------------------

  static TextStyle get headingStyle => GoogleFonts.ibmPlexMono(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyStyle => GoogleFonts.ibmPlexMono(
        color: textColor,
        fontSize: 14,
      );

  // ---------------------------------------------------------------------------
  // Typography — Arabic
  // ---------------------------------------------------------------------------

  static TextStyle get arabicHeadingStyle => GoogleFonts.notoKufiArabic(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get arabicBodyStyle => GoogleFonts.notoKufiArabic(
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
