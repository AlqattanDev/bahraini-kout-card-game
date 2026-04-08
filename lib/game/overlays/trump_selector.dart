import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models/card.dart';
import '../../game/theme/kout_theme.dart';
import 'animated_press_button.dart';
import 'overlay_panel.dart';
import 'overlay_styles.dart';

class TrumpSelectorOverlay extends StatelessWidget {
  final void Function(String suit) onSelect;

  const TrumpSelectorOverlay({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return OverlayPanel(
      title: 'Select Trump Suit',
      titleStyle: const TextStyle(
        color: KoutTheme.accent,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
      content: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [for (final suit in Suit.values) _suitButton(suit)],
      ),
    );
  }

  Widget _suitButton(Suit suit) {
    return AnimatedPressButton(
      onPressed: () => onSelect(suit.name),
      hapticFeedback: () => HapticFeedback.mediumImpact(),
      delayDuration: OverlayStyles.animNormal,
      animationDuration: OverlayStyles.animFast,
      builder: (context, isPressed) {
        return AnimatedContainer(
          duration: OverlayStyles.animNormal,
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: KoutTheme.accent,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: isPressed
                ? [
                    BoxShadow(
                      color: KoutTheme.accent.withValues(alpha: 0.8),
                      blurRadius: 12.0,
                      spreadRadius: 4.0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: KoutTheme.table.withValues(alpha: 0.55),
                      blurRadius: 4.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              suit.symbol,
              style: TextStyle(
                fontSize: 32,
                color: KoutTheme.suitCardColor(suit),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
