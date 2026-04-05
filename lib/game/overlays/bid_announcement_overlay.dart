import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

/// Auto-dismissing overlay shown during BID_ANNOUNCEMENT phase.
///
/// Displays the winning bid value, trump suit, and bidder seat for ~3 seconds
/// before trick play begins. Removed automatically when the phase advances.
class BidAnnouncementOverlay extends StatelessWidget {
  final ClientGameState state;

  const BidAnnouncementOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bidLabel = _bidLabel();
    final suitSymbol = state.trumpSuit?.symbol ?? '?';
    final suitColor = state.trumpSuit != null
        ? KoutTheme.suitCardColor(state.trumpSuit!)
        : const Color(0xFFE0E0E0);
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : -1;
    final bidderLabel = bidderSeat == state.mySeatIndex
        ? 'You'
        : 'Player ${bidderSeat + 1}';

    return OverlayAnimationWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
        decoration: OverlayStyles.panelDecoration(),
        // Note: padding uses 32H instead of standard 28H to fit 3-line content
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              bidderLabel,
              style: const TextStyle(
                color: KoutTheme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bidLabel,
              style: const TextStyle(
                color: KoutTheme.accent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            // Trump suit display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: OverlayStyles.infoBoxDecoration(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Trump',
                    style: TextStyle(
                      color: KoutTheme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    suitSymbol,
                    style: TextStyle(
                      fontSize: 40,
                      color: suitColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bidLabel() {
    final bid = state.currentBid;
    if (bid == null) return 'Bid';
    if (bid.isKout) return 'Kout!';
    if (bid.value == 5) return 'Bab (5)';
    return 'Bid ${bid.value}';
  }

}
