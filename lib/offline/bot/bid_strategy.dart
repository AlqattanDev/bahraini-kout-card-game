import 'package:koutbh/shared/constants.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'hand_evaluator.dart';

class BidStrategy {
  static const Map<BidAmount, double> _thresholdByBid = {
    BidAmount.bab: 4.5,
    BidAmount.six: 5.5,
    BidAmount.seven: 6.5,
    BidAmount.kout: 7.5,
  };
  static const List<BidAmount> _descendingBidStrength = [
    BidAmount.kout,
    BidAmount.seven,
    BidAmount.six,
    BidAmount.bab,
  ];

  static GameAction decideBid(
    List<GameCard> hand,
    BidAmount? currentHighBid, {
    bool isForced = false,
    Map<Team, int>? scores,
    Team? myTeam,
    int? mySeat,
    List<({int seat, String action})>? bidHistory,
    double difficultyAdjust = 0.0,
  }) {
    final strength = HandEvaluator.evaluate(hand);

    // Step 3.1 — Score-aware threshold adjustment
    // Positive = more aggressive (pretend hand is stronger)
    double thresholdAdjust = difficultyAdjust;
    if (scores != null && myTeam != null) {
      final my = scores[myTeam] ?? 0;
      final opp = scores[myTeam.opponent] ?? 0;
      if (my + 5 - opp >= targetScore) {
        thresholdAdjust += 1.0; // any bid wins the game
      } else if (my + 5 >= targetScore) {
        thresholdAdjust += 0.8; // Bab alone reaches target
      } else if (opp >= 25 && my <= 5) {
        thresholdAdjust += 1.0; // desperate — must bid to survive
      } else if (my >= 26) {
        thresholdAdjust += 0.5;
      } else if (opp >= 26) {
        thresholdAdjust += 0.5;
      }
    }

    // Step 3.2 — Position-aware bidding
    if (bidHistory != null && mySeat != null) {
      final actedBefore = bidHistory.length;
      if (actedBefore == 0) {
        thresholdAdjust -= 0.3; // first to bid, no info → conservative
      } else if (actedBefore == 1) {
        // no adjustment
      } else if (actedBefore == 2) {
        thresholdAdjust += 0.2; // more info
      } else if (actedBefore >= 3) {
        thresholdAdjust += 0.3; // last, max info → aggressive
      }
    }

    // Step 3.3 — Partner inference from bid history
    if (bidHistory != null && mySeat != null) {
      final partnerSeat = (mySeat + 2) % 4;
      final partnerEntry = bidHistory
          .where((e) => e.seat == partnerSeat)
          .lastOrNull;
      if (partnerEntry != null && partnerEntry.action != 'pass') {
        thresholdAdjust += 0.3; // partner bid → reliable
      } else if (partnerEntry?.action == 'pass') {
        thresholdAdjust -= 0.3; // partner passed → weak
      }
    }

    final adjustedStrength = strength.expectedWinners + thresholdAdjust;
    final maxBid = _strengthToBid(adjustedStrength);

    // Forced to bid — must return a BidAction, never PassAction
    // Step 3.4: isForcedBid flag propagates to GameContext for play strategy (Phase 6.6)
    if (isForced) {
      final naturalBid = maxBid ?? BidAmount.bab;
      if (currentHighBid == null) return BidAction(naturalBid);
      // Find smallest bid above current
      final nextBid = BidAmount.nextAbove(currentHighBid);
      if (nextBid != null) return BidAction(nextBid);
      return BidAction(BidAmount.bab);
    }

    // Step 3.6 — Tactical overbidding: steal from opponent
    if (currentHighBid != null && bidHistory != null && mySeat != null) {
      final lastBidder = bidHistory.where((e) => e.action != 'pass').lastOrNull;
      if (lastBidder != null) {
        final isOpponentBid = teamForSeat(lastBidder.seat) != myTeam;
        if (isOpponentBid) {
          final nextBidValue = currentHighBid.value + 1;
          final nextBid = BidAmount.values
              .where((b) => b.value == nextBidValue)
              .firstOrNull;
          if (nextBid != null) {
            final nextThreshold = _bidThreshold(nextBid);
            if (adjustedStrength > nextThreshold + 0.3) {
              return BidAction(nextBid); // comfortable margin — overbid
            }
          }
        }
      }
    }

    if (maxBid == null) {
      return PassAction();
    }

    if (currentHighBid == null) {
      return BidAction(maxBid);
    }

    // Can we outbid?
    if (maxBid.value > currentHighBid.value) {
      final nextBid = BidAmount.nextAbove(currentHighBid);
      if (nextBid != null && nextBid.value <= maxBid.value) {
        return BidAction(nextBid);
      }
    }

    return PassAction();
  }

  // TODO: Phase 3.5 — fuzzy thresholds for Aggressive bots (needs BotDifficulty from Phase 9)

  static BidAmount? _strengthToBid(double expectedWinners) {
    for (final bid in _descendingBidStrength) {
      final threshold = _thresholdByBid[bid];
      if (threshold != null && expectedWinners >= threshold) {
        return bid;
      }
    }
    return null;
  }

  static double _bidThreshold(BidAmount bid) {
    return _thresholdByBid[bid]!;
  }
}
