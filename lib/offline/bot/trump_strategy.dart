import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';

class TrumpStrategy {
  static Suit selectTrump(
    List<GameCard> hand, {
    BidAmount? bidLevel,
    bool isForcedBid = false,
    double? lengthWeight,
    double? strengthWeight,
  }) {
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

    // Step 4.5: Forced-bid defensive trump — just pick longest suit
    if (isForcedBid) {
      Suit? longest;
      int maxCount = 0;
      for (final entry in suitCounts.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          longest = entry.key;
        }
      }
      return longest ?? Suit.spades;
    }

    // Step 4.1: Minimum count gate — prefer suits with 2+ cards
    final validSuits = suitCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toSet();
    final candidates =
        validSuits.isNotEmpty ? validSuits : suitCounts.keys.toSet();

    // Step 4.2: Bid-level aware scoring (with difficulty overrides)
    double trumpScore(int count, double strength, BidAmount? bid) {
      final isKout = bid == BidAmount.kout;
      final lw = lengthWeight ?? (isKout ? 1.5 : 2.0);
      final sw = strengthWeight ?? (isKout ? 2.0 : 1.0);
      return count * lw + strength * sw;
    }

    final hasJoker = hand.any((c) => c.isJoker);

    Suit bestSuit = Suit.spades; // fallback
    double bestScore = -1;

    for (final candidateSuit in candidates) {
      final count = suitCounts[candidateSuit] ?? 0;
      final strength = suitStrength[candidateSuit] ?? 0;

      double score = trumpScore(count, strength, bidLevel);

      // Joker bonus for longer suits
      if (hasJoker && count >= 3) score += 1.0;

      // Step 4.3: Side suit strength — Aces and Kings in other suits
      double sideStrength = 0.0;
      for (final card in hand) {
        if (!card.isJoker && card.suit != candidateSuit) {
          if (card.rank == Rank.ace) {
            sideStrength += 0.9;
          } else if (card.rank == Rank.king) {
            sideStrength += 0.5;
          }
        }
      }
      score += sideStrength;

      // Step 4.4: Ruff value — void non-trump suits
      for (final suit in Suit.values) {
        if (suit != candidateSuit && !suitCounts.containsKey(suit)) {
          score += 0.5;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestSuit = candidateSuit;
      }
    }

    return bestSuit;
  }
}
