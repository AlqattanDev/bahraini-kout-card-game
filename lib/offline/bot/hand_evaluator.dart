import 'package:koutbh/shared/models/card.dart';

class HandStrength {
  final double expectedWinners;
  final Suit? strongestSuit;
  const HandStrength({required this.expectedWinners, this.strongestSuit});
}

class HandEvaluator {
  static HandStrength evaluate(List<GameCard> hand, {Suit? trumpSuit}) {
    double score = 0.0;
    final suitCounts = <Suit, int>{};
    final suitStrength = <Suit, double>{};

    // Count suits
    for (final card in hand) {
      if (card.isJoker) continue;
      suitCounts[card.suit!] = (suitCounts[card.suit!] ?? 0) + 1;
    }

    for (final card in hand) {
      if (card.isJoker) {
        score += 1.0; // Guaranteed winner
        continue;
      }

      final suit = card.suit!;
      final rank = card.rank!;
      final count = suitCounts[suit] ?? 0;
      double cardScore = 0.0;

      // Ace
      if (rank == Rank.ace) {
        cardScore = 0.9;
      }
      // King
      else if (rank == Rank.king) {
        cardScore = count >= 3 ? 0.7 : 0.4;
      }
      // Queen
      else if (rank == Rank.queen) {
        cardScore = count >= 4 ? 0.4 : 0.15;
      }
      // Jack and 10
      else if (rank == Rank.jack || rank == Rank.ten) {
        cardScore = 0.1;
      }

      // Trump bonus for non-honor trump cards
      if (trumpSuit != null &&
          suit == trumpSuit &&
          rank.value < Rank.jack.value) {
        cardScore += 0.3;
      }

      score += cardScore;
      suitStrength[suit] = (suitStrength[suit] ?? 0) + cardScore;
    }

    // Long suit bonus
    for (final entry in suitCounts.entries) {
      if (entry.value >= 4) score += 0.3;
    }

    // Void suit bonus
    for (final suit in Suit.values) {
      if (!suitCounts.containsKey(suit)) score += 0.2;
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
}
