import 'package:flutter/material.dart';
import '../../shared/models/bid.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

class AnimatedBidButton extends StatefulWidget {
  final String number;
  final (String, String) label;
  final VoidCallback onPressed;

  const AnimatedBidButton({
    super.key,
    required this.number,
    required this.label,
    required this.onPressed,
  });

  @override
  State<AnimatedBidButton> createState() => _AnimatedBidButtonState();
}

class _AnimatedBidButtonState extends State<AnimatedBidButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed();
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
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutBack,
        child: ElevatedButton(
          onPressed: () {},
          style: OverlayStyles.primaryButton(
            borderRadius: 10.0,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ).copyWith(
            minimumSize: WidgetStateProperty.all(const Size(68, 68)),
            elevation: WidgetStateProperty.all(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.number,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.label.$1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                widget.label.$2,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BidOverlay extends StatelessWidget {
  final void Function(int amount) onBid;
  final VoidCallback onPass;
  final BidAmount? currentHighBid;
  final bool isForced;

  const BidOverlay({
    super.key,
    required this.onBid,
    required this.onPass,
    this.currentHighBid,
    this.isForced = false,
  });

  List<BidAmount> get _availableBids {
    if (currentHighBid == null) return BidAmount.values.toList();
    return BidAmount.values
        .where((b) => b.value > currentHighBid!.value)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bids = _availableBids;

    return OverlayAnimationWrapper(
      child: Container(
        padding: OverlayStyles.panelPadding,
        decoration: OverlayStyles.panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heading
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isForced ? 'You Must Bid' : 'Place Your Bid',
                  style: KoutTheme.headingStyle.copyWith(
                    color: KoutTheme.accent,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isForced ? 'لازم تختار' : 'ضع مزايدتك',
                  style: KoutTheme.arabicHeadingStyle.copyWith(
                    color: KoutTheme.accent,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            OverlayStyles.sectionGap,
            if (currentHighBid != null) ...[
              Text(
                'Current High Bid: ${currentHighBid!.value}',
                style: KoutTheme.bodyStyle.copyWith(
                  color: KoutTheme.cream.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Bid buttons — only show bids higher than current
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < bids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _bidButton(
                    '${bids[i].value}',
                    _labelForBid(bids[i]),
                    bids[i].value,
                  ),
                ],
              ],
            ),
            // Pass button — hidden when forced
            if (!isForced) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onPass,
                style: OverlayStyles.textButton(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      KoutTheme.gameTerms['pass']!.$1,
                      style: KoutTheme.bodyStyle,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      KoutTheme.gameTerms['pass']!.$2,
                      style: KoutTheme.arabicBodyStyle,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String) _labelForBid(BidAmount bid) {
    return switch (bid) {
      BidAmount.bab => KoutTheme.gameTerms['bab']!,
      BidAmount.six => ('6', '٦'),
      BidAmount.seven => ('7', '٧'),
      BidAmount.kout => KoutTheme.gameTerms['kout']!,
    };
  }

  Widget _bidButton(String number, (String, String) label, int amount) {
    return AnimatedBidButton(
      number: number,
      label: label,
      onPressed: () => onBid(amount),
    );
  }
}
