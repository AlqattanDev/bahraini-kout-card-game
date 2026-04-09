import 'package:koutbh/shared/constants.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/bot_settings.dart';
import 'hand_evaluator.dart';

class BidStrategy {
  // ---------------------------------------------------------------
  // Thresholds: effectiveTricks needed for each bid level
  // ---------------------------------------------------------------
  static const Map<BidAmount, double> _thresholds = {
    BidAmount.bab: 5.0,
    BidAmount.six: 6.0,
    BidAmount.seven: 7.0,
    BidAmount.kout: 8.0,
  };

  // ---------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------

  static GameAction decideBid(
    List<GameCard> hand,
    BidAmount? currentHighBid, {
    bool isForced = false,
    Map<Team, int>? scores,
    Team? myTeam,
    int? mySeat,
    List<({int seat, String action})>? bidHistory,
  }) {
    final strength = HandEvaluator.evaluate(hand);
    final partnerAction = _partnerAction(mySeat, bidHistory);
    final effectiveTricks =
        HandEvaluator.effectiveTricks(strength, partnerAction: partnerAction);

    // Desperation: lower thresholds when opponent could win soon.
    final desperationOffset = _desperationOffset(scores, myTeam);

    // Threshold bid: highest level effectiveTricks supports.
    final thresholdBid = _thresholdBid(effectiveTricks, desperationOffset);

    // Shape floor: minimum bid implied by suit length.
    final shapeFloor = _shapeFloor(hand);

    // Ceiling = max(threshold, shape floor), gated by Seven/Kout rules.
    var ceiling = _maxBid(thresholdBid, shapeFloor);
    ceiling = _applyGates(ceiling, hand, effectiveTricks);

    // --- Forced bid ---
    if (isForced) {
      return _forcedBid(ceiling, currentHighBid);
    }

    // --- Partner rule: never outbid partner unless going Kout ---
    if (_partnerBid(mySeat, bidHistory) && ceiling != BidAmount.kout) {
      return PassAction();
    }

    // --- No bid possible ---
    if (ceiling == null) {
      return PassAction();
    }

    // --- First bid (no existing high bid) ---
    if (currentHighBid == null) {
      return BidAction(ceiling);
    }

    // --- Outbid logic ---
    final nextBid = BidAmount.nextAbove(currentHighBid);
    if (nextBid == null) return PassAction(); // can't outbid kout

    // Must determine if this is an opponent's bid.
    final isOpponentBid = _isOpponentBid(mySeat, myTeam, bidHistory);

    if (isOpponentBid) {
      // Opponent contest: only outbid if effectiveTricks >= the new level.
      final adjustedET = effectiveTricks + desperationOffset;
      if (adjustedET >= nextBid.value.toDouble() &&
          nextBid.value <= ceiling.value) {
        return BidAction(nextBid);
      }
      return PassAction();
    }

    // Non-opponent bid (partner or unknown) that we haven't already filtered:
    // If we can go higher and our ceiling supports it, bid.
    if (nextBid.value <= ceiling.value) {
      return BidAction(nextBid);
    }

    return PassAction();
  }

  /// Shape floor for public testing (kept for backward compatibility).
  static BidAmount? computeShapeFloorBid(List<GameCard> hand) =>
      _shapeFloor(hand);

  // ---------------------------------------------------------------
  // Partner detection
  // ---------------------------------------------------------------

  /// Determine partner's action from bid history.
  static PartnerAction _partnerAction(
    int? mySeat,
    List<({int seat, String action})>? bidHistory,
  ) {
    if (mySeat == null || bidHistory == null) return PartnerAction.unknown;
    final partnerSeat = (mySeat + 2) % 4;
    final entry =
        bidHistory.where((e) => e.seat == partnerSeat).lastOrNull;
    if (entry == null) return PartnerAction.unknown;
    if (entry.action == 'pass') return PartnerAction.passed;
    return PartnerAction.bid;
  }

  /// Returns true if partner placed a bid (not pass).
  static bool _partnerBid(
    int? mySeat,
    List<({int seat, String action})>? bidHistory,
  ) {
    return _partnerAction(mySeat, bidHistory) == PartnerAction.bid;
  }

  // ---------------------------------------------------------------
  // Desperation
  // ---------------------------------------------------------------

  static double _desperationOffset(Map<Team, int>? scores, Team? myTeam) {
    if (scores == null || myTeam == null) return 0.0;
    final oppScore = scores[myTeam.opponent] ?? 0;
    if (oppScore >= targetScore - 10) {
      return BotSettings.desperationThreshold;
    }
    return 0.0;
  }

  // ---------------------------------------------------------------
  // Threshold bid
  // ---------------------------------------------------------------

  /// Highest bid level supported by effectiveTricks (with desperation offset).
  static BidAmount? _thresholdBid(double effectiveTricks, double offset) {
    final adjusted = effectiveTricks + offset;
    BidAmount? best;
    for (final bid in BidAmount.values) {
      final threshold = _thresholds[bid]!;
      if (adjusted >= threshold) {
        best = bid;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------
  // Shape floor
  // ---------------------------------------------------------------

  static BidAmount? _shapeFloor(List<GameCard> hand) {
    final bySuit = HandEvaluator.suitDistribution(hand);
    final hasJoker = hand.any((c) => c.isJoker);
    BidAmount? best;

    for (final entry in bySuit.entries) {
      final len = entry.value.length;
      final ranks = entry.value.map((c) => c.rank!).toSet();
      final hasA = ranks.contains(Rank.ace);
      final hasK = ranks.contains(Rank.king);
      final hasQ = ranks.contains(Rank.queen);
      final akq = hasA && hasK && hasQ;

      BidAmount? floor;
      if (len >= 7 && hasJoker) {
        floor = BidAmount.kout;
      } else if (len >= 7) {
        floor = BidAmount.seven;
      } else if (len >= 6 && hasJoker && akq) {
        floor = BidAmount.kout;
      } else if (len >= 6 && hasJoker) {
        floor = BidAmount.seven;
      } else if (len >= 6) {
        floor = BidAmount.six;
      } else if (len >= 5 && hasJoker) {
        floor = BidAmount.six;
      } else if (len >= 5) {
        floor = BidAmount.bab;
      }

      best = _maxBid(best, floor);
    }

    return best;
  }

  // ---------------------------------------------------------------
  // Gates
  // ---------------------------------------------------------------

  /// Apply Seven and Kout gates: demote ceiling if gates not passed.
  static BidAmount? _applyGates(
    BidAmount? ceiling,
    List<GameCard> hand,
    double effectiveTricks,
  ) {
    if (ceiling == null) return null;

    // Kout gate
    if (ceiling == BidAmount.kout && !_passesKoutGate(hand, effectiveTricks)) {
      ceiling = BidAmount.seven;
    }

    // Seven gate
    if (ceiling == BidAmount.seven && !_passesSevenGate(hand)) {
      ceiling = BidAmount.six;
    }

    return ceiling;
  }

  /// Seven gate: only bid Seven if ONE of:
  /// - 6+ cards in strongest suit
  /// - Joker + 5+ cards in a suit with A-K
  /// - 3+ Aces + Joker
  static bool _passesSevenGate(List<GameCard> hand) {
    final bySuit = HandEvaluator.suitDistribution(hand);
    final hasJoker = hand.any((c) => c.isJoker);

    // 6+ cards in any suit
    for (final cards in bySuit.values) {
      if (cards.length >= 6) return true;
    }

    // Joker + 5+ cards in a suit with A-K
    if (hasJoker) {
      for (final cards in bySuit.values) {
        if (cards.length >= 5) {
          final ranks = cards.map((c) => c.rank!).toSet();
          if (ranks.contains(Rank.ace) && ranks.contains(Rank.king)) {
            return true;
          }
        }
      }
    }

    // 3+ Aces + Joker
    if (hasJoker) {
      final aceCount =
          hand.where((c) => !c.isJoker && c.rank == Rank.ace).length;
      if (aceCount >= 3) return true;
    }

    return false;
  }

  /// Kout gate: must pass ONE of:
  /// - Longest suit >= 7
  /// - Joker + 6+ cards + AKQ block in some suit
  /// - Joker + 5+ cards + 3 Aces
  /// - effectiveTricks >= 7.6
  static bool _passesKoutGate(List<GameCard> hand, double effectiveTricks) {
    final bySuit = HandEvaluator.suitDistribution(hand);
    final hasJoker = hand.any((c) => c.isJoker);
    final aceCount =
        hand.where((c) => !c.isJoker && c.rank == Rank.ace).length;

    // Longest suit >= 7
    for (final cards in bySuit.values) {
      if (cards.length >= 7) return true;
    }

    if (hasJoker) {
      for (final cards in bySuit.values) {
        final ranks = cards.map((c) => c.rank!).toSet();

        // Joker + 6+ cards + AKQ block
        if (cards.length >= 6 &&
            ranks.contains(Rank.ace) &&
            ranks.contains(Rank.king) &&
            ranks.contains(Rank.queen)) {
          return true;
        }

        // Joker + 5+ cards + 3 Aces
        if (cards.length >= 5 && aceCount >= 3) return true;
      }
    }

    // effectiveTricks >= 7.6
    if (effectiveTricks >= 7.6) return true;

    return false;
  }

  // ---------------------------------------------------------------
  // Forced bid
  // ---------------------------------------------------------------

  static GameAction _forcedBid(BidAmount? ceiling, BidAmount? currentHighBid) {
    final naturalBid = ceiling ?? BidAmount.bab;
    if (currentHighBid == null) return BidAction(naturalBid);
    final nextBid = BidAmount.nextAbove(currentHighBid);
    if (nextBid != null && ceiling != null && nextBid.value <= ceiling.value) {
      return BidAction(nextBid);
    }
    // Forced: must bid at least the minimum legal.
    if (nextBid != null) return BidAction(nextBid);
    return BidAction(BidAmount.bab);
  }

  // ---------------------------------------------------------------
  // Opponent detection
  // ---------------------------------------------------------------

  /// Returns true if the current high bid was placed by an opponent.
  static bool _isOpponentBid(
    int? mySeat,
    Team? myTeam,
    List<({int seat, String action})>? bidHistory,
  ) {
    if (mySeat == null || myTeam == null || bidHistory == null) return false;
    final lastBidder =
        bidHistory.where((e) => e.action != 'pass').lastOrNull;
    if (lastBidder == null) return false;
    return teamForSeat(lastBidder.seat) != myTeam;
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  static BidAmount? _maxBid(BidAmount? a, BidAmount? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.value >= b.value ? a : b;
  }
}
