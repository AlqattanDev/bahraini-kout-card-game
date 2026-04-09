import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/logic/card_utils.dart';
import 'package:koutbh/offline/bot/bot_settings.dart';

/// Per-rank weights for trump suit strength accumulation.
double _trumpSuitStrengthWeight(Rank rank) => switch (rank) {
  Rank.ace => 3.0,
  Rank.king => 2.0,
  Rank.queen => 1.5,
  Rank.jack => 1.0,
  _ => 0.5,
};

/// Side-suit honor bonus while scoring a candidate trump suit.
double _trumpSideHonorBonus(Rank rank) => switch (rank) {
  Rank.ace => 0.9,
  Rank.king => 0.5,
  _ => 0.0,
};

double _honorTiebreak(List<GameCard> suitCards) {
  double s = 0;
  for (final c in suitCards) {
    if (c.rank == Rank.ace) s += 3.0;
    if (c.rank == Rank.king) s += 2.0;
  }
  return s;
}

class TrumpStrategy {
  static Suit selectTrump(
    List<GameCard> hand, {
    BidAmount? bidLevel,
    double? lengthWeight,
    double? strengthWeight,
  }) {
    final suitCounts = countBySuit(hand);
    final suitStrength = <Suit, double>{};

    for (final card in hand) {
      if (card.isJoker) continue;
      final suit = card.suit!;

      suitStrength[suit] =
          (suitStrength[suit] ?? 0) + _trumpSuitStrengthWeight(card.rank!);
    }

    final validSuits = suitCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toSet();
    final candidates = validSuits.isNotEmpty
        ? validSuits
        : suitCounts.keys.toSet();

    double trumpScore(int count, double strength, BidAmount? bid) {
      final isKout = bid == BidAmount.kout;
      final lw = lengthWeight ?? (isKout ? 1.5 : BotSettings.trumpLengthWeight);
      final sw = strengthWeight ?? (isKout ? 2.0 : BotSettings.trumpStrengthWeight);
      return count * lw + strength * sw;
    }

    final hasJoker = hand.any((c) => c.isJoker);

    final scores = <Suit, double>{};
    for (final candidateSuit in candidates) {
      final count = suitCounts[candidateSuit] ?? 0;
      final strength = suitStrength[candidateSuit] ?? 0;

      double score = trumpScore(count, strength, bidLevel);

      if (hasJoker && count >= 3) score += 1.0;

      double sideStrength = 0.0;
      for (final card in hand) {
        if (!card.isJoker && card.suit != candidateSuit) {
          sideStrength += _trumpSideHonorBonus(card.rank!);
        }
      }
      score += sideStrength;

      for (final suit in Suit.values) {
        if (suit != candidateSuit && !suitCounts.containsKey(suit)) {
          score += 0.5;
        }
      }

      scores[candidateSuit] = score;
    }

    if (scores.isEmpty) return Suit.spades;

    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    const closeEpsilon = 0.5;
    final close = scores.entries
        .where((e) => (maxScore - e.value) <= closeEpsilon)
        .map((e) => e.key)
        .toList();

    // When several suits are nearly tied, prefer A/K honors; then length.
    if (close.length >= 2) {
      close.sort((a, b) {
        final tb =
            _honorTiebreak(
              hand.where((c) => !c.isJoker && c.suit == b).toList(),
            ).compareTo(
              _honorTiebreak(
                hand.where((c) => !c.isJoker && c.suit == a).toList(),
              ),
            );
        if (tb != 0) return tb;
        return (suitCounts[b] ?? 0).compareTo(suitCounts[a] ?? 0);
      });
      return close.first;
    }

    Suit bestSuit = Suit.spades;
    double bestScore = -1;

    for (final candidateSuit in candidates) {
      final score = scores[candidateSuit] ?? -1;
      if (score > bestScore) {
        bestScore = score;
        bestSuit = candidateSuit;
      }
    }

    return bestSuit;
  }
}
