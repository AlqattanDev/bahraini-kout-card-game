import '../models/card.dart';
import '../models/trick.dart';

class TrickResolver {
  static int resolve(Trick trick, {required Suit trumpSuit}) {
    final plays = trick.plays;
    if (plays.length != 4) {
      throw ArgumentError('Trick must have exactly 4 plays, got ${plays.length}');
    }

    // Rule 1: Joker always wins
    for (final play in plays) {
      if (play.card.isJoker) return play.playerIndex;
    }

    final ledSuit = trick.ledSuit!;

    // Rule 2: Highest trump wins (if any trump played)
    final trumpPlays = plays.where((p) => !p.card.isJoker && p.card.suit == trumpSuit).toList();
    if (trumpPlays.isNotEmpty) {
      trumpPlays.sort((a, b) => b.card.rank!.value.compareTo(a.card.rank!.value));
      return trumpPlays.first.playerIndex;
    }

    // Rule 3: Highest card of led suit wins
    final ledSuitPlays = plays.where((p) => !p.card.isJoker && p.card.suit == ledSuit).toList();
    ledSuitPlays.sort((a, b) => b.card.rank!.value.compareTo(a.card.rank!.value));
    return ledSuitPlays.first.playerIndex;
  }

  static bool beats(GameCard a, GameCard b, Suit? trumpSuit, Suit? ledSuit) {
    if (a.isJoker) return true;
    if (b.isJoker) return false;

    // Trump beats non-trump
    if (trumpSuit != null) {
      if (a.suit == trumpSuit && b.suit != trumpSuit) return true;
      if (a.suit != trumpSuit && b.suit == trumpSuit) return false;
      if (a.suit == trumpSuit && b.suit == trumpSuit) {
        return a.rank!.value > b.rank!.value;
      }
    }

    // Same suit comparison
    if (a.suit == b.suit) return a.rank!.value > b.rank!.value;

    // Led suit beats non-led, non-trump
    if (ledSuit != null) {
      if (a.suit == ledSuit && b.suit != ledSuit) return true;
      if (a.suit != ledSuit && b.suit == ledSuit) return false;
    }

    return false;
  }
}
