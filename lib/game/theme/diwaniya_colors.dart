import 'dart:ui';

/// Centralized Diwaniya-themed color palette for the entire game UI.
class DiwaniyaColors {
  DiwaniyaColors._();

  // Background
  static const Color backgroundTile = Color(0xFF3D5A6E);
  static const Color backgroundTileDark = Color(0xFF263845);
  static const Color vignette = Color(0xFF0F1A22);

  // Table surface (3D perspective trapezoid)
  static const Color tableSurfaceCenter = Color(0xFF4A5C4A);
  static const Color tableSurfaceEdge = Color(0xFF2B3A2B);
  static const Color tableFelt = Color(0xFF3A4D3A);
  static const Color tableBorder = Color(0xFF3B2314);

  // Diwaniya accent colors
  static const Color goldAccent = Color(0xFFC9A84C);
  static const Color goldHighlight = Color(0xFFE0C060);
  static const Color burgundy = Color(0xFF5C1A1B);
  static const Color cream = Color(0xFFF5ECD7);
  static const Color darkWood = Color(0xFF3B2314);

  // Player interaction
  static const Color activeTurnRing = Color(0xFF4ADE80);
  static const Color actionBadgeBg = Color(0xE6222222);
  static const Color actionBadgePassBg = Color(0xE6441111);
  static const Color actionBadgeBorder = Color(0xFF555555);

  // Name label pill backgrounds
  static const Color nameLabelTeamA = Color(0xCC2A5FAA);
  static const Color nameLabelTeamB = Color(0xCCAA2A2A);

  // Score HUD
  static const Color scoreHudBg = Color(0xE62A1A14);      // dark wood-brown
  static const Color scoreHudBorder = Color(0xFF6B5A3A);   // muted gold-brown

  // Card enhancements
  static const Color faceCardGradientTop = Color(0xFFFFFDF8);
  static const Color faceCardGradientBottom = Color(0xFFF5F0E8);

  // Avatar palette
  static const Color avatarSkyBg = Color(0xFF8FBFE0);
  static const Color avatarEyeBlack = Color(0xFF1A1A1A);
  static const Color avatarMouthBrown = Color(0xFF8B4513);
  static const Color avatarSunglassLens = Color(0xFF111111);
  static const Color avatarSunglassFrame = Color(0xFF222222);

  // General UI
  static const Color passRed = Color(0xFFCC4444);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color nearBlack = Color(0xFF1A1A1A);
  static const Color tileHighlight = Color(0x05FFFFFF);
}
