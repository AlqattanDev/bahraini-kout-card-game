import 'package:koutbh/shared/models/card.dart';

/// Sorts a hand for display: alternating black/red suits, rank high→low, jokers last.
/// Matches the order used for the local player's hand.
List<GameCard> sortHandForDisplay(List<GameCard> hand, Suit? trumpSuit) {
  final jokers = hand.where((c) => c.isJoker).toList();
  final suited = hand.where((c) => !c.isJoker).toList();

  final presentSuits = suited.map((c) => c.suit!).toSet();

  const blackSuits = [Suit.clubs, Suit.spades];
  const redSuits = [Suit.diamonds, Suit.hearts];
  final blacks = blackSuits.where(presentSuits.contains).toList();
  final reds = redSuits.where(presentSuits.contains).toList();

  final suitOrder = <Suit>[];
  final List<Suit> first;
  final List<Suit> second;
  if (reds.length > blacks.length) {
    first = reds;
    second = blacks;
  } else {
    first = blacks;
    second = reds;
  }
  final maxLen = first.length > second.length ? first.length : second.length;
  for (int i = 0; i < maxLen; i++) {
    if (i < first.length) suitOrder.add(first[i]);
    if (i < second.length) suitOrder.add(second[i]);
  }

  suited.sort((a, b) {
    final suitCmp = suitOrder.indexOf(a.suit!).compareTo(suitOrder.indexOf(b.suit!));
    if (suitCmp != 0) return suitCmp;
    return b.rank!.value.compareTo(a.rank!.value);
  });

  return [...suited, ...jokers];
}

Map<Suit, int> countBySuit(List<GameCard> hand) {
  final counts = <Suit, int>{};
  for (final card in hand) {
    if (card.isJoker) continue;
    counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
  }
  return counts;
}
