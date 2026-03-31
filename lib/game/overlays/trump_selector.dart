import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';

/// Flutter overlay shown during TRUMP_SELECTION phase for the winning bidder.
///
/// Displays 4 suit buttons with suit symbols. Hearts/diamonds in red,
/// spades/clubs in black (dark on gold button).
class TrumpSelectorOverlay extends StatelessWidget {
  final void Function(String suit) onSelect;

  const TrumpSelectorOverlay({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return OverlayAnimationWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: KoutTheme.primary.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KoutTheme.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Trump Suit',
              style: TextStyle(
                color: KoutTheme.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _suitButton('♠', 'spades', isRed: false),
                const SizedBox(width: 12),
                _suitButton('♥', 'hearts', isRed: true),
                const SizedBox(width: 12),
                _suitButton('♣', 'clubs', isRed: false),
                const SizedBox(width: 12),
                _suitButton('♦', 'diamonds', isRed: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suitButton(String symbol, String suit, {required bool isRed}) {
    final symbolColor = isRed ? const Color(0xFFCC0000) : const Color(0xFF111111);

    return ElevatedButton(
      onPressed: () => onSelect(suit),
      style: ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.accent,
        minimumSize: const Size(70, 70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
      ).copyWith(
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? KoutTheme.accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 32,
          color: symbolColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
