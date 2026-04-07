import 'package:koutbh/shared/models/card.dart';

Map<Suit, int> countBySuit(List<GameCard> hand) {
  final counts = <Suit, int>{};
  for (final card in hand) {
    if (card.isJoker) continue;
    counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
  }
  return counts;
}
