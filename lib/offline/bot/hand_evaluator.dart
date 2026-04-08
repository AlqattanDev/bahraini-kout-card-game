import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/logic/card_utils.dart';

class HandStrength {
  final double expectedWinners;
  final Suit? strongestSuit;
  const HandStrength({required this.expectedWinners, this.strongestSuit});
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

  static HandStrength evaluate(List<GameCard> hand, {Suit? trumpSuit}) {
    double score = 0.0;
    final suitCounts = countBySuit(hand);
    final suitStrength = <Suit, double>{};

    for (final card in hand) {
      if (card.isJoker) {
        score += 1.0; // Guaranteed winner
        continue;
      }

      final suit = card.suit!;
      final rank = card.rank!;
      final count = suitCounts[suit] ?? 0;
      double cardScore = 0.0;

      // Honor valuation (Step 2.1)
      if (rank == Rank.ace) {
        cardScore = 0.9;
      } else if (rank == Rank.king) {
        cardScore = count >= 3 ? 0.8 : 0.6;
      } else if (rank == Rank.queen) {
        cardScore = count >= 3 ? 0.5 : 0.3;
      } else if (rank == Rank.jack) {
        cardScore = 0.2;
      } else if (rank == Rank.ten) {
        cardScore = 0.1;
      }

      // Trump honor bonus (Step 2.2)
      if (trumpSuit != null && suit == trumpSuit) {
        if (rank == Rank.ace) {
          cardScore += 0.5;
        } else if (rank == Rank.king) {
          cardScore += 0.4;
        } else if (rank == Rank.queen) {
          cardScore += 0.3;
        } else if (rank == Rank.jack) {
          cardScore += 0.2;
        } else {
          cardScore += 0.3;
        }
      }

      score += cardScore;
      suitStrength[suit] = (suitStrength[suit] ?? 0) + cardScore;
    }

    // Suit texture scoring (Step 2.3)
    score += _suitTextureBonus(hand);

    // Long suit bonus
    for (final entry in suitCounts.entries) {
      if (entry.value >= 4) score += 0.3;
    }

    // Void and ruffing potential (Step 2.4+2.5)
    final hasAnyTrump = hand.any(
      (c) => !c.isJoker && trumpSuit != null && c.suit == trumpSuit,
    );

    for (final suit in Suit.values) {
      if (!suitCounts.containsKey(suit)) {
        if (suit == trumpSuit) {
          // Void in trump: bad. No bonus.
        } else if (hasAnyTrump) {
          score += 0.3; // ruffing potential
        } else {
          score += 0.1; // void but no trump
        }
      }
    }

    // Find strongest suit
    Suit? strongest;
    double bestStrength = -1;
    for (final entry in suitStrength.entries) {
      final combined = entry.value + (suitCounts[entry.key] ?? 0) * 0.1;
      if (combined > bestStrength) {
        bestStrength = combined;
        strongest = entry.key;
      }
    }

    return HandStrength(
      expectedWinners: score.clamp(0.0, 8.0),
      strongestSuit: strongest,
    );
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
