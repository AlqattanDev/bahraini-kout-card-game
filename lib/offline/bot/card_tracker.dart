import 'package:koutbh/shared/models/card.dart';

class CardTracker {
  final Set<GameCard> _played = {};
  final Map<int, Set<Suit>> _knownVoids = {};

  void recordPlay(int seat, GameCard card) {
    _played.add(card);
  }

  void inferVoid(int seat, Suit suit) {
    _knownVoids.putIfAbsent(seat, () => {}).add(suit);
  }

  Set<GameCard> get playedCards => Set.unmodifiable(_played);

  /// All cards NOT yet played and NOT in my hand.
  Set<GameCard> remainingCards(List<GameCard> myHand) {
    return GameCard.fullDeck().difference(_played).difference(myHand.toSet());
  }

  Map<int, Set<Suit>> get knownVoids => Map.unmodifiable(_knownVoids);

  int trumpsRemaining(Suit trumpSuit, List<GameCard> myHand) {
    return remainingCards(
      myHand,
    ).where((c) => !c.isJoker && c.suit == trumpSuit).length;
  }

  bool isHighestRemaining(GameCard card, List<GameCard> myHand) {
    if (card.isJoker) return true;
    final suit = card.suit!;
    final remaining = remainingCards(
      myHand,
    ).where((c) => !c.isJoker && c.suit == suit);
    if (remaining.isEmpty) return true;
    final highestRemaining = remaining
        .map((c) => c.rank!.value)
        .reduce((a, b) => a > b ? a : b);
    return card.rank!.value > highestRemaining;
  }

  bool isSuitExhausted(Suit suit, List<GameCard> myHand) {
    return remainingCards(
      myHand,
    ).where((c) => !c.isJoker && c.suit == suit).isEmpty;
  }

  void reset() {
    _played.clear();
    _knownVoids.clear();
  }
}
