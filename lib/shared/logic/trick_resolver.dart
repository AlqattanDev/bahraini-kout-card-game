import '../models/card.dart';
import '../models/trick.dart';

class TrickResolver {
  static int resolve(Trick trick, {required Suit trumpSuit}) {
    final plays = trick.plays;
    assert(plays.length == 4, 'Trick must have exactly 4 plays');

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
}
