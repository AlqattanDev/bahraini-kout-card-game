import 'package:flutter/material.dart';
import '../../shared/models/bid.dart';
import '../../game/theme/kout_theme.dart';
import 'animated_press_button.dart';
import 'overlay_panel.dart';
import 'overlay_styles.dart';

class _BidChip extends StatelessWidget {
  final int value;
  final bool isKout;
  final VoidCallback onPressed;

  const _BidChip({
    required this.value,
    required this.isKout,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPressButton(
      onPressed: onPressed,
      child: Container(
        width: isKout ? 64 : 52,
        height: isKout ? 64 : 52,
        decoration: BoxDecoration(
          color: isKout
              ? KoutTheme.accent.withValues(alpha: 0.15)
              : KoutTheme.primary,
          borderRadius: BorderRadius.circular(isKout ? 14 : 10),
          border: Border.all(
            color: isKout
                ? KoutTheme.accent
                : KoutTheme.accent.withValues(alpha: 0.5),
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
            '$value',
            style: TextStyle(
              color: isKout ? KoutTheme.accent : KoutTheme.textColor,
              fontSize: isKout ? 28 : 22,
              fontWeight: FontWeight.bold,
              fontFamily: KoutTheme.monoFontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredEntrance extends StatefulWidget {
  final int delayIndex;
  final Widget child;

  const _StaggeredEntrance({required this.delayIndex, required this.child});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayIndex * 60), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Opacity 0->1, scale 0.8->1.0 over 200ms
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _visible ? 1.0 : 0.0),
      duration: OverlayStyles.animNormal,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
        );
      },
      child: widget.child,
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

    return OverlayPanel(
      title: isForced ? 'You Must Bid' : 'Place Your Bid',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < bids.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                _StaggeredEntrance(
                  delayIndex: i,
                  child: _BidChip(
                    value: bids[i].value,
                    isKout: bids[i] == BidAmount.kout,
                    onPressed: () => onBid(bids[i].value),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: !isForced
          ? [
              TextButton(
                onPressed: onPass,
                style: OverlayStyles.textButton(),
                child: Text('Pass', style: KoutTheme.bodyStyle),
              ),
            ]
          : null,
    );
  }
}
