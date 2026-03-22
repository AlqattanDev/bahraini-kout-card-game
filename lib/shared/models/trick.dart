import 'card.dart';

class TrickPlay {
  final int playerIndex;
  final GameCard card;
  const TrickPlay({required this.playerIndex, required this.card});
}

class Trick {
  final int leadPlayerIndex;
  final List<TrickPlay> plays;
  const Trick({required this.leadPlayerIndex, required this.plays});

  Suit? get ledSuit {
    if (plays.isEmpty) return null;
    final leadCard = plays.first.card;
    return leadCard.isJoker ? null : leadCard.suit;
  }
}
