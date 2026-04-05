import 'package:flutter/material.dart';
import '../../shared/models/card.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

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
        padding: OverlayStyles.panelPadding,
        decoration: OverlayStyles.panelDecoration(),
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
            OverlayStyles.sectionGap,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final suit in Suit.values) ...[
                  if (suit != Suit.values.first) const SizedBox(width: 12),
                  _suitButton(suit),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suitButton(Suit suit) {
    return ElevatedButton(
      onPressed: () => onSelect(suit.name),
      style: OverlayStyles.primaryButton(
        borderRadius: 10.0,
        padding: EdgeInsets.zero,
      ).copyWith(
        minimumSize: WidgetStateProperty.all(const Size(70, 70)),
        elevation: WidgetStateProperty.all(4),
      ),
      child: Text(
        suit.symbol,
        style: TextStyle(
          fontSize: 32,
          color: KoutTheme.suitCardColor(suit),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
