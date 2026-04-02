import 'dart:math';

import 'package:koutbh/shared/models/bid.dart';

/// Shared timing constants used by both the game controller and UI.
abstract final class GameTiming {
  /// How long a human player has to act before auto-play kicks in.
  static const Duration humanTurnTimeout = Duration(seconds: 15);

  /// Deal animation pause.
  static const Duration dealDelay = Duration(milliseconds: 300);

  /// Pause after a card is played so the user can see it.
  static const Duration cardPlayDelay = Duration(milliseconds: 1500);

  /// Pause after a trick resolves before starting the next.
  static const Duration trickResolutionDelay = Duration(seconds: 2);

  /// Pause before scoring overlay transitions.
  static const Duration scoringDelay = Duration(seconds: 2);

  /// Pause for the bid/trump announcement overlay before trick play begins.
  static const Duration bidAnnouncementDelay = Duration(seconds: 3);

  /// Bot thinking range: [botThinkingMinMs, botThinkingMinMs + botThinkingRangeMs).
  static const int botThinkingMinMs = 3000;
  static const int botThinkingRangeMs = 2000;

  static final _rng = Random();

  /// Context-aware bot thinking delay that varies by game situation.
  static Duration botThinkingDelay({
    required int legalMoves,
    required int trickNumber,
    bool isBidding = false,
    BidAmount? bidAmount,
    bool isForcedBid = false,
    bool isPassing = false,
  }) {
    int ms;
    if (isBidding) {
      if (isPassing) {
        ms = 800 + _rng.nextInt(400);
      } else if (isForcedBid) {
        ms = 1000 + _rng.nextInt(1000);
      } else if (bidAmount == BidAmount.seven || bidAmount == BidAmount.kout) {
        ms = 2500 + _rng.nextInt(1500);
      } else {
        ms = 1500 + _rng.nextInt(1000);
      }
    } else {
      if (legalMoves == 1) {
        ms = 500 + _rng.nextInt(500);
      } else if (trickNumber >= 7) {
        ms = 2000 + _rng.nextInt(2000);
      } else {
        ms = 1500 + _rng.nextInt(2000);
      }
    }
    return Duration(milliseconds: ms);
  }
}
