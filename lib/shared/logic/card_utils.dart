import 'package:koutbh/shared/models/card.dart';

/// Per-rank weights for trump *suit* strength accumulation in bot trump selection.
double trumpSuitStrengthWeight(Rank rank) {
  return switch (rank) {
    Rank.ace => 3.0,
    Rank.king => 2.0,
    Rank.queen => 1.5,
    Rank.jack => 1.0,
    _ => 0.5,
  };
}

/// Side-suit honor bonus while scoring a candidate trump suit (non-trump cards).
double trumpSideHonorBonus(Rank rank) {
  return switch (rank) {
    Rank.ace => 0.9,
    Rank.king => 0.5,
    _ => 0.0,
  };
}

Map<Suit, int> countBySuit(List<GameCard> hand) {
  final counts = <Suit, int>{};
  for (final card in hand) {
    if (card.isJoker) continue;
    counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
  }
  return counts;
}
