import 'card.dart';

class Deck {
  final List<GameCard> cards;
  Deck._(this.cards);

  factory Deck.fourPlayer() {
    final cards = <GameCard>[];
    const fullSuits = [Suit.spades, Suit.hearts, Suit.clubs];
    const fullRanks = Rank.values;

    for (final suit in fullSuits) {
      for (final rank in fullRanks) { cards.add(GameCard(suit: suit, rank: rank)); }
    }

    // Diamonds: all ranks except 7
    for (final rank in fullRanks) {
      if (rank != Rank.seven) { cards.add(GameCard(suit: Suit.diamonds, rank: rank)); }
    }

    cards.add(GameCard.joker());
    return Deck._(cards);
  }

  List<List<GameCard>> deal(int playerCount) {
    final shuffled = List<GameCard>.from(cards)..shuffle();
    final cardsPerPlayer = shuffled.length ~/ playerCount;
    return List.generate(
      playerCount,
      (i) => shuffled.sublist(i * cardsPerPlayer, (i + 1) * cardsPerPlayer),
    );
  }
}
