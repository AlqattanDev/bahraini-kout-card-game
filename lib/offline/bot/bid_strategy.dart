import 'package:koutbh/shared/constants.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'hand_evaluator.dart';

class BidStrategy {
  static const Map<BidAmount, double> _thresholdByBid = {
    BidAmount.bab: 3.7,
    BidAmount.six: 4.3,
    BidAmount.seven: 5.0,
    BidAmount.kout: 5.8,
  };
  static const List<BidAmount> _descendingBidStrength = [
    BidAmount.kout,
    BidAmount.seven,
    BidAmount.six,
    BidAmount.bab,
  ];

  static BidAmount _higherBid(BidAmount a, BidAmount b) =>
      a.value >= b.value ? a : b;

  static BidAmount? _maxBid(BidAmount? a, BidAmount? b) {
    if (a == null) return b;
    if (b == null) return a;
    return _higherBid(a, b);
  }

  /// Shape-based minimum bid (floor). Null if no shape rule applies.
  static BidAmount? _shapeFloorForSuit(
    List<GameCard> suitCards,
    Suit suit,
    List<GameCard> hand,
    bool hasJoker,
  ) {
    final len = suitCards.length;
    final ranks = suitCards.map((c) => c.rank!).toSet();
    final hasA = ranks.contains(Rank.ace);
    final hasK = ranks.contains(Rank.king);
    final hasQ = ranks.contains(Rank.queen);
    final akq = hasA && hasK && hasQ;

    var offAces = 0;
    var offKings = 0;
    for (final c in hand) {
      if (c.isJoker || c.suit == suit) continue;
      if (c.rank == Rank.ace) offAces++;
      if (c.rank == Rank.king) offKings++;
    }

    if (len >= 7 && hasJoker) return BidAmount.kout;
    if (len >= 7) return BidAmount.seven;
    if (len >= 6 && hasJoker && akq) return BidAmount.kout;
    if (len >= 6 && hasJoker) return BidAmount.seven;
    if (len >= 6 && offAces >= 1 && offKings >= 1) return BidAmount.seven;
    if (len >= 6) return BidAmount.six;
    if (len >= 5 && hasJoker) return BidAmount.six;
    if (len >= 5 && offAces >= 1) return BidAmount.six;
    if (len >= 5) return BidAmount.bab;
    if (len >= 4 && hasJoker) return BidAmount.bab;
    if (len >= 4 && (offAces >= 1 || offKings >= 1)) return BidAmount.bab;
    if (akq && hasJoker && offAces >= 1) return BidAmount.bab;
    return null;
  }

  /// AKQ in a 3-card suit + Joker + off-suit Ace (top-heavy short suit).
  static BidAmount? _shapeFloorAkqJokerOffAce(
    Map<Suit, List<GameCard>> bySuit,
    List<GameCard> hand,
    bool hasJoker,
  ) {
    if (!hasJoker) return null;
    for (final entry in bySuit.entries) {
      final cards = entry.value;
      if (cards.length != 3) continue;
      final ranks = cards.map((c) => c.rank!).toSet();
      if (!ranks.contains(Rank.ace) ||
          !ranks.contains(Rank.king) ||
          !ranks.contains(Rank.queen)) {
        continue;
      }
      var offAces = 0;
      for (final c in hand) {
        if (c.isJoker || c.suit == entry.key) continue;
        if (c.rank == Rank.ace) offAces++;
      }
      if (offAces >= 1) return BidAmount.bab;
    }
    return null;
  }

  static BidAmount? computeShapeFloorBid(List<GameCard> hand) {
    final bySuit = HandEvaluator.suitDistribution(hand);
    final hasJoker = hand.any((c) => c.isJoker);
    BidAmount? best;
    for (final entry in bySuit.entries) {
      final candidate = _shapeFloorForSuit(
        entry.value,
        entry.key,
        hand,
        hasJoker,
      );
      best = _maxBid(best, candidate);
    }
    best = _maxBid(best, _shapeFloorAkqJokerOffAce(bySuit, hand, hasJoker));
    return best;
  }

  static BidAmount _demoteBid(BidAmount b) => switch (b) {
    BidAmount.kout => BidAmount.seven,
    BidAmount.seven => BidAmount.six,
    BidAmount.six => BidAmount.bab,
    BidAmount.bab => BidAmount.bab,
  };

  static BidAmount _promoteBid(BidAmount b) => switch (b) {
    BidAmount.bab => BidAmount.six,
    BidAmount.six => BidAmount.seven,
    BidAmount.seven => BidAmount.kout,
    BidAmount.kout => BidAmount.kout,
  };

  static BidAmount? _adjustFloorForDifficulty(
    BidAmount? floor,
    double difficultyAdjust,
  ) {
    if (floor == null) return null;
    if (difficultyAdjust <= -0.2) return _demoteBid(floor);
    if (difficultyAdjust >= 0.2) return _promoteBid(floor);
    return floor;
  }

  static bool _hasAkqInAnySuit(Map<Suit, List<GameCard>> bySuit) {
    for (final cards in bySuit.values) {
      final ranks = cards.map((c) => c.rank!).toSet();
      if (ranks.contains(Rank.ace) &&
          ranks.contains(Rank.king) &&
          ranks.contains(Rank.queen)) {
        return true;
      }
    }
    return false;
  }

  static bool _canCallKout({
    required List<GameCard> hand,
    required double adjustedStrength,
    required int longestSuitLen,
  }) {
    final hasJoker = hand.any((c) => c.isJoker);
    final aceCount = hand.where((c) => !c.isJoker && c.rank == Rank.ace).length;
    final bySuit = HandEvaluator.suitDistribution(hand);
    final hasAkqBlock = _hasAkqInAnySuit(bySuit);

    // Kout should require truly dominant shape/power, not just generic aggression.
    if (longestSuitLen >= 7) return true;
    if (hasJoker && longestSuitLen >= 6 && hasAkqBlock) return true;
    if (hasJoker && longestSuitLen >= 5 && aceCount >= 3) return true;
    return adjustedStrength >= 7.6;
  }

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

    double thresholdAdjust = difficultyAdjust;
    if (scores != null && myTeam != null) {
      final my = scores[myTeam] ?? 0;
      final opp = scores[myTeam.opponent] ?? 0;
      if (my + 5 - opp >= targetScore) {
        thresholdAdjust += 1.0;
      } else if (my + 5 >= targetScore) {
        thresholdAdjust += 0.8;
      } else if (opp >= 25 && my <= 5) {
        thresholdAdjust += 1.0;
      } else if (my >= 26) {
        thresholdAdjust += 0.5;
      } else if (opp >= 26) {
        thresholdAdjust += 0.5;
      }
    }

    if (bidHistory != null && mySeat != null) {
      final actedBefore = bidHistory.length;
      if (actedBefore == 0) {
        thresholdAdjust += 0.2;
      } else if (actedBefore == 2) {
        thresholdAdjust += 0.2;
      } else if (actedBefore >= 3) {
        thresholdAdjust += 0.3;
      }
    }

    if (bidHistory != null && mySeat != null) {
      final partnerSeat = (mySeat + 2) % 4;
      final partnerEntry = bidHistory
          .where((e) => e.seat == partnerSeat)
          .lastOrNull;
      if (partnerEntry != null && partnerEntry.action != 'pass') {
        thresholdAdjust += 0.5;
      } else if (partnerEntry?.action == 'pass') {
        thresholdAdjust -= 0.1;
      }
    }

    // Reward dominant shape so bots escalate beyond safe 5s on monster hands.
    final bySuit = HandEvaluator.suitDistribution(hand);
    final longestSuitLen = bySuit.values.fold<int>(
      0,
      (best, cards) => cards.length > best ? cards.length : best,
    );
    final hasJoker = hand.any((c) => c.isJoker);
    final aceCount = hand.where((c) => !c.isJoker && c.rank == Rank.ace).length;
    final kingCount =
        hand.where((c) => !c.isJoker && c.rank == Rank.king).length;
    final queenCount =
        hand.where((c) => !c.isJoker && c.rank == Rank.queen).length;

    final shapeBoost =
        (longestSuitLen >= 7)
            ? 0.8
            : (longestSuitLen == 6 && hasJoker)
            ? 0.5
            : 0.0;
    final powerCardBoost = (aceCount * 0.35) +
        (kingCount * 0.25) +
        (queenCount * 0.12) +
        (hasJoker ? 1.0 : 0.0);

    final adjustedStrength =
        strength.expectedWinners + thresholdAdjust + shapeBoost + powerCardBoost;
    final thresholdBid = _strengthToBid(adjustedStrength);
    final rawShape = computeShapeFloorBid(hand);
    final shapeFloor = _adjustFloorForDifficulty(rawShape, difficultyAdjust);
    var ceiling = _maxBid(shapeFloor, thresholdBid);
    if (ceiling == BidAmount.kout &&
        !_canCallKout(
          hand: hand,
          adjustedStrength: adjustedStrength,
          longestSuitLen: longestSuitLen,
        )) {
      ceiling = BidAmount.seven;
    }

    if (isForced) {
      final naturalBid = ceiling ?? BidAmount.bab;
      if (currentHighBid == null) return BidAction(naturalBid);
      final nextBid = BidAmount.nextAbove(currentHighBid);
      if (nextBid != null) return BidAction(nextBid);
      return BidAction(BidAmount.bab);
    }

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
              return BidAction(nextBid);
            }
          }
        }
      }
    }

    if (ceiling == null) {
      return PassAction();
    }

    if (currentHighBid == null) {
      return BidAction(ceiling);
    }

    if (ceiling.value > currentHighBid.value) {
      final nextBid = BidAmount.nextAbove(currentHighBid);
      if (nextBid != null && nextBid.value <= ceiling.value) {
        return BidAction(nextBid);
      }
    }

    return PassAction();
  }

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
