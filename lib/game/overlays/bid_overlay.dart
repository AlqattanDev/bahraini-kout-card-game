import 'package:flutter/material.dart';
import '../../shared/models/bid.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

class _BidChip extends StatefulWidget {
  final int value;
  final bool isKout;
  final VoidCallback onPressed;

  const _BidChip({
    required this.value,
    required this.isKout,
    required this.onPressed,
  });

  @override
  State<_BidChip> createState() => _BidChipState();
}

class _BidChipState extends State<_BidChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isKout = widget.isKout;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutBack,
        child: Container(
          width: isKout ? 64 : 52,
          height: isKout ? 64 : 52,
          decoration: BoxDecoration(
            color: isKout
                ? KoutTheme.accent.withValues(alpha: 0.15)
                : KoutTheme.primary,
            borderRadius: BorderRadius.circular(isKout ? 14 : 10),
            border: Border.all(
              color: isKout ? KoutTheme.accent : KoutTheme.accent.withValues(alpha: 0.5),
              width: isKout ? 2.0 : 1.5,
            ),
            boxShadow: isKout
                ? [
                    BoxShadow(
                      color: KoutTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${widget.value}',
              style: TextStyle(
                color: isKout ? KoutTheme.accent : KoutTheme.textColor,
                fontSize: isKout ? 28 : 22,
                fontWeight: FontWeight.bold,
                fontFamily: KoutTheme.monoFontFamily,
              ),
            ),
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
            Text(
              isForced ? 'You Must Bid' : 'Place Your Bid',
              style: KoutTheme.headingStyle.copyWith(
                color: KoutTheme.accent,
                fontSize: 18,
              ),
            ),
            OverlayStyles.sectionGap,
            if (currentHighBid != null) ...[
              Text(
                'Current: ${currentHighBid!.value}',
                style: KoutTheme.bodyStyle.copyWith(
                  color: KoutTheme.cream.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Bid chips — single number per chip, Kout gets special treatment
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < bids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _BidChip(
                    value: bids[i].value,
                    isKout: bids[i] == BidAmount.kout,
                    onPressed: () => onBid(bids[i].value),
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
                child: Text('Pass', style: KoutTheme.bodyStyle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
