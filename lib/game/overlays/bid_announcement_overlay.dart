import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_panel.dart';
import 'overlay_styles.dart';
import 'overlay_utils.dart';

/// Auto-dismissing overlay shown during BID_ANNOUNCEMENT phase.
///
/// Displays the winning bid value, trump suit, and bidder seat for ~3 seconds
/// before trick play begins. Removed automatically when the phase advances.
class BidAnnouncementOverlay extends StatefulWidget {
  final ClientGameState state;

  const BidAnnouncementOverlay({super.key, required this.state});

  @override
  State<BidAnnouncementOverlay> createState() => _BidAnnouncementOverlayState();
}

class _BidAnnouncementOverlayState extends State<BidAnnouncementOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _showBidValue = false;
  bool _showTrumpSuit = false;

  @override
  void initState() {
    super.initState();

    // Staggered fade-ins
    delayIfMounted(
      this,
      const Duration(milliseconds: 150),
      () => setState(() => _showBidValue = true),
    );
    delayIfMounted(
      this,
      OverlayStyles.animSlow,
      () => setState(() => _showTrumpSuit = true),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: OverlayStyles.animSlow * 2,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.state.currentBid?.isKout == true) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bidLabel = _bidLabel();
    final suitSymbol = widget.state.trumpSuit?.symbol ?? '?';
    final suitColor = widget.state.trumpSuit != null
        ? KoutTheme.suitCardColor(widget.state.trumpSuit!)
        : const Color(0xFFE0E0E0);
    final bidderSeat = widget.state.bidderUid != null
        ? widget.state.playerUids.indexOf(widget.state.bidderUid!)
        : -1;
    final bidderLabel = bidderSeat == widget.state.mySeatIndex
        ? 'You'
        : 'Player ${bidderSeat + 1}';

    final isKout = widget.state.currentBid?.isKout == true;

    return OverlayPanel(
      title: bidderLabel,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: _showBidValue ? 1.0 : 0.0,
            duration: OverlayStyles.animSlow,
            child: isKout
                ? AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Text(
                          bidLabel,
                          style: TextStyle(
                            color: KoutTheme.accent,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: KoutTheme.accent.withValues(alpha: 0.6),
                                blurRadius: (_pulseAnimation.value - 1.0) * 100,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Text(
                    bidLabel,
                    style: const TextStyle(
                      color: KoutTheme.accent,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _showTrumpSuit ? 1.0 : 0.0,
            duration: OverlayStyles.animSlow,
            child: Container(
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
          ),
        ],
      ),
    );
  }

  String _bidLabel() {
    final bid = widget.state.currentBid;
    if (bid == null) return 'Bid';
    if (bid.isKout) return 'Kout!';
    if (bid.value == 5) return 'Bab (5)';
    return 'Bid ${bid.value}';
  }
}
