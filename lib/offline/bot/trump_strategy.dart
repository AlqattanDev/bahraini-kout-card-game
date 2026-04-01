import 'package:koutbh/shared/models/card.dart';

class TrumpStrategy {
  static Suit selectTrump(List<GameCard> hand) {
    final suitCounts = <Suit, int>{};
    final suitStrength = <Suit, double>{};

    for (final card in hand) {
      if (card.isJoker) continue;
      final suit = card.suit!;
      suitCounts[suit] = (suitCounts[suit] ?? 0) + 1;

      // Strength based on rank value
      double rankScore = 0.0;
      if (card.rank == Rank.ace) {
        rankScore = 3.0;
      } else if (card.rank == Rank.king) {
        rankScore = 2.0;
      } else if (card.rank == Rank.queen) {
        rankScore = 1.5;
      } else if (card.rank == Rank.jack) {
        rankScore = 1.0;
      } else {
        rankScore = 0.5;
      }

      suitStrength[suit] = (suitStrength[suit] ?? 0) + rankScore;
    }

    // If holding Joker, slightly prefer longer suits with weaker cards
    // (trump promotes them)
    final hasJoker = hand.any((c) => c.isJoker);

    Suit bestSuit = Suit.spades; // fallback
    double bestScore = -1;

    for (final suit in Suit.values) {
      final count = suitCounts[suit] ?? 0;
      if (count == 0) continue;

      final strength = suitStrength[suit] ?? 0;
      // Score = count * 2 + strength. Joker bonus for longer suits
      double score = count * 2.0 + strength;
      if (hasJoker && count >= 3) score += 1.0;

      if (score > bestScore) {
        bestScore = score;
        bestSuit = suit;
      }
    }

    return bestSuit;
  }
}
