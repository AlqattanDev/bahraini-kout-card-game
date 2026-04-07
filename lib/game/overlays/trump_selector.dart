import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models/card.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

/// Flutter overlay shown during TRUMP_SELECTION phase for the winning bidder.
///
/// Displays 4 suit buttons with suit symbols. Hearts/diamonds in red,
/// spades/clubs in black (dark on gold button).
class AnimatedSuitButton extends StatefulWidget {
  final Suit suit;
  final VoidCallback onSelect;

  const AnimatedSuitButton({
    super.key,
    required this.suit,
    required this.onSelect,
  });

  @override
  State<AnimatedSuitButton> createState() => _AnimatedSuitButtonState();
}

class _AnimatedSuitButtonState extends State<AnimatedSuitButton> {
  bool _isPressed = false;
  bool _hasSelected = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_hasSelected) return;
    _hasSelected = true;
    HapticFeedback.mediumImpact();
    setState(() => _isPressed = false);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        widget.onSelect();
      }
    });
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: KoutTheme.accent.withValues(alpha: 0.8),
                    blurRadius: 12.0,
                    spreadRadius: 4.0,
                  )
                ]
              : [],
        ),
        child: ElevatedButton(
          // Pass empty onPressed, as GestureDetector handles tap
          onPressed: () {},
          style: OverlayStyles.primaryButton(
            borderRadius: 10.0,
            padding: EdgeInsets.zero,
          ).copyWith(
            minimumSize: WidgetStateProperty.all(const Size(70, 70)),
            elevation: WidgetStateProperty.all(4),
          ),
          child: Text(
            widget.suit.symbol,
            style: TextStyle(
              fontSize: 32,
              color: KoutTheme.suitCardColor(widget.suit),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

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
    return AnimatedSuitButton(
      suit: suit,
      onSelect: () => onSelect(suit.name),
    );
  }
}
