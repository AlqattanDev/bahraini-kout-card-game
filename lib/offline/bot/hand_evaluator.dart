import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/logic/card_utils.dart';
import 'package:koutbh/offline/bot/bot_settings.dart';

enum PartnerAction { unknown, bid, passed }

class HandStrength {
  final double personalTricks;
  final Suit? strongestSuit;
  const HandStrength({required this.personalTricks, this.strongestSuit});
}

class HandEvaluator {
  /// Non-joker cards grouped by suit (empty suits omitted).
  static Map<Suit, List<GameCard>> suitDistribution(List<GameCard> hand) {
    final map = <Suit, List<GameCard>>{};
    for (final c in hand) {
      if (c.isJoker) continue;
      map.putIfAbsent(c.suit!, () => []).add(c);
    }
    return map;
  }

  /// Base trick probability for a card (no trump).
  static double _baseProbability(Rank rank) => switch (rank) {
    Rank.ace => 0.85,
    Rank.king => 0.65,
    Rank.queen => 0.35,
    Rank.jack => 0.15,
    _ => 0.05, // 10 and below
  };

  /// Bonus added when the card is in the prospective trump suit.
  static double _trumpBonus(Rank rank) => switch (rank) {
    Rank.ace => 0.15,
    Rank.king => 0.25,
    Rank.queen => 0.25,
    Rank.jack => 0.25,
    _ => 0.30, // 10 and below
  };

  static HandStrength evaluate(List<GameCard> hand) {
    if (hand.isEmpty) {
      return const HandStrength(personalTricks: 0.0);
    }

    final bySuit = suitDistribution(hand);
    final suitCounts = countBySuit(hand);

    // Step 1: Find strongest suit by raw trick potential (sum of base probs).
    final rawPotential = <Suit, double>{};
    for (final entry in bySuit.entries) {
      double sum = 0.0;
      for (final card in entry.value) {
        sum += _baseProbability(card.rank!);
      }
      rawPotential[entry.key] = sum;
    }

    Suit? strongest;
    double bestPotential = -1;
    for (final entry in rawPotential.entries) {
      if (entry.value > bestPotential) {
        bestPotential = entry.value;
        strongest = entry.key;
      }
    }

    // Step 2: Score each card with base + trump bonus for strongest suit.
    double score = 0.0;

    for (final card in hand) {
      if (card.isJoker) {
        score += 1.0; // Guaranteed trick
        continue;
      }

      final rank = card.rank!;
      final suit = card.suit!;
      double cardScore = _baseProbability(rank);
      if (suit == strongest) {
        cardScore += _trumpBonus(rank);
      }
      score += cardScore;
    }

    // Step 3: Suit texture bonuses.
    score += _suitTextureBonus(hand);

    // Step 4: Long suit bonus — +0.1 per card beyond 3 for suits with 4+.
    for (final entry in suitCounts.entries) {
      if (entry.value >= 4) {
        score += (entry.value - 3) * 0.1;
      }
    }

    // Step 5: Void bonuses.
    final hasTrump = strongest != null && (suitCounts[strongest] ?? 0) > 0;
    for (final suit in Suit.values) {
      if (suitCounts.containsKey(suit)) continue;
      // This suit is void.
      if (suit == strongest) continue; // Void in own trump: no bonus.
      if (hasTrump) {
        score += 1.0; // Ruffing potential
      } else {
        score += 0.1; // Void but no trump
      }
    }

    return HandStrength(
      personalTricks: score.clamp(0.0, 8.0),
      strongestSuit: strongest,
    );
  }

  /// Partner-adjusted effective tricks, clamped to 0.0-8.0.
  static double effectiveTricks(
    HandStrength strength, {
    required PartnerAction partnerAction,
  }) {
    final partnerEstimate = switch (partnerAction) {
      PartnerAction.unknown => BotSettings.partnerEstimateDefault,
      PartnerAction.bid => BotSettings.partnerEstimateBid,
      PartnerAction.passed => BotSettings.partnerEstimatePass,
    };
    return (strength.personalTricks + partnerEstimate).clamp(0.0, 8.0);
  }

  static double _suitTextureBonus(List<GameCard> hand) {
    double bonus = 0.0;
    final bySuit = <Suit, List<Rank>>{};
    for (final c in hand) {
      if (c.isJoker) continue;
      bySuit.putIfAbsent(c.suit!, () => []).add(c.rank!);
    }
    for (final ranks in bySuit.values) {
      final hasAce = ranks.contains(Rank.ace);
      final hasKing = ranks.contains(Rank.king);
      final hasQueen = ranks.contains(Rank.queen);
      if (hasAce && hasKing && hasQueen) {
        bonus += 0.5;
      } else if (hasAce && hasKing) {
        bonus += 0.3;
      } else if (hasKing && hasQueen && !hasAce) {
        bonus += 0.2;
      }
    }
    return bonus;
  }
}
