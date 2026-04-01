import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'hand_evaluator.dart';

class BidStrategy {
  static GameAction decideBid(
    List<GameCard> hand,
    BidAmount? currentHighBid, {
    bool isForced = false,
  }) {
    final strength = HandEvaluator.evaluate(hand);
    final maxBid = _strengthToBid(strength.expectedWinners);

    // Forced to bid — must return a BidAction, never PassAction
    if (isForced) {
      final naturalBid = maxBid ?? BidAmount.bab;
      if (currentHighBid == null) return BidAction(naturalBid);
      // Find smallest bid above current
      for (final bid in BidAmount.values) {
        if (bid.value > currentHighBid.value) return BidAction(bid);
      }
      return BidAction(BidAmount.bab);
    }

    if (maxBid == null) {
      return PassAction();
    }

    if (currentHighBid == null) {
      return BidAction(maxBid);
    }

    // Can we outbid?
    if (maxBid.value > currentHighBid.value) {
      for (final bid in BidAmount.values) {
        if (bid.value > currentHighBid.value && bid.value <= maxBid.value) {
          return BidAction(bid);
        }
      }
    }

    return PassAction();
  }

  static BidAmount? _strengthToBid(double expectedWinners) {
    // Partner contributes ~1.5 tricks, baked into thresholds
    if (expectedWinners >= 7.5) return BidAmount.kout;
    if (expectedWinners >= 6.5) return BidAmount.seven;
    if (expectedWinners >= 5.5) return BidAmount.six;
    if (expectedWinners >= 4.5) return BidAmount.bab;
    return null;
  }
}
