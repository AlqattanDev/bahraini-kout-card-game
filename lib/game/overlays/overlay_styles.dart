import 'package:flutter/material.dart';
import '../theme/kout_theme.dart';

/// Shared styles for game overlays (round result, game over, etc.).
///
/// Centralizes decoration, button, and color logic so overlays stay
/// consistent without duplicating style definitions.
abstract final class OverlayStyles {
  /// Standard overlay container decoration.
  static BoxDecoration panelDecoration({
    double alpha = 0.97,
    double borderWidth = 2.0,
    double borderRadius = 16.0,
    double blurRadius = 24.0,
  }) =>
      BoxDecoration(
        color: KoutTheme.primary.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: KoutTheme.accent, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: blurRadius,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Inner content box (e.g. trick breakdown, final score).
  static BoxDecoration infoBoxDecoration({double borderRadius = 10.0}) =>
      BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// Primary filled button style (Continue, Play Again).
  static ButtonStyle primaryButton({
    double borderRadius = 8.0,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.accent,
        foregroundColor: KoutTheme.buttonForeground,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );

  /// Secondary outlined button style (Back to Lobby).
  static ButtonStyle secondaryButton({
    double borderRadius = 10.0,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
  }) =>
      OutlinedButton.styleFrom(
        foregroundColor: KoutTheme.accent,
        side: const BorderSide(color: KoutTheme.accent, width: 1.5),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );

  /// Result headline color — green for win, red for loss.
  static Color resultColor(bool won) =>
      won ? KoutTheme.accent : KoutTheme.lossColor;

  // ---------------------------------------------------------------------------
  // Centralized spacing constants
  // ---------------------------------------------------------------------------

  /// Standard panel padding (used in overlay containers).
  static const EdgeInsets panelPadding =
      EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  /// Section/divider spacing between major content blocks.
  static const SizedBox sectionGap = SizedBox(height: 20);

  // ---------------------------------------------------------------------------
  // Text button style (for Pass, etc.)
  // ---------------------------------------------------------------------------

  /// Text button with border (Pass button, dismissible actions).
  static ButtonStyle textButton({
    double borderRadius = 8.0,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
  }) =>
      TextButton.styleFrom(
        foregroundColor: KoutTheme.textColor,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        side: const BorderSide(color: KoutTheme.textColor, width: 1),
      );
}
