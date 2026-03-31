import 'package:flutter/material.dart';
import '../../shared/models/bid.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';

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
            const SizedBox(height: 20),
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
                style: TextButton.styleFrom(
                  foregroundColor: KoutTheme.textColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 10),
                  side: const BorderSide(
                      color: KoutTheme.textColor, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
    return ElevatedButton(
      onPressed: () => onBid(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.accent,
        foregroundColor: const Color(0xFF3B1A1B),
        minimumSize: const Size(68, 68),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ).copyWith(
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? KoutTheme.accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label.$1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label.$2,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
