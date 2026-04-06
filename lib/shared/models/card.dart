import 'package:koutbh/shared/models/enums.dart';
import 'package:koutbh/shared/constants.dart';

export 'package:koutbh/shared/models/enums.dart';

class GameCard {
  final Suit? suit;
  final Rank? rank;
  final bool isJoker;

  const GameCard({required this.suit, required this.rank}) : isJoker = false;

  const GameCard._joker()
      : suit = null,
        rank = null,
        isJoker = true;

  factory GameCard.joker() => const GameCard._joker();

  String encode() {
    if (isJoker) return 'JO';
    return '${suitInitial[suit!]}${rankString[rank!]}';
  }

  factory GameCard.decode(String encoded) {
    if (encoded == 'JO') return GameCard.joker();
    final suitChar = encoded.substring(0, 1);
    final rankStr = encoded.substring(1);
    final suit = initialToSuit[suitChar];
    final rank = stringToRank[rankStr];
    if (suit == null || rank == null) {
      throw ArgumentError('Invalid card encoding: $encoded');
    }
    return GameCard(suit: suit, rank: rank);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GameCard) return false;
    if (isJoker && other.isJoker) return true;
    if (isJoker != other.isJoker) return false;
    return suit == other.suit && rank == other.rank;
  }

  @override
  int get hashCode {
    if (isJoker) return 'JO'.hashCode;
    return Object.hash(suit, rank);
  }

  static final Set<GameCard> _cachedFullDeck = Set.unmodifiable(() {
    final cards = <GameCard>{};
    const fullSuits = [Suit.spades, Suit.hearts, Suit.clubs];
    for (final suit in fullSuits) {
      for (final rank in Rank.values) {
        cards.add(GameCard(suit: suit, rank: rank));
      }
    }
    // Diamonds: all ranks except 7
    for (final rank in Rank.values) {
      if (rank != Rank.seven) {
        cards.add(GameCard(suit: Suit.diamonds, rank: rank));
      }
    }
    cards.add(GameCard.joker());
    return cards;
  }());

  /// The full 32-card koutbh deck as an unmodifiable set.
  /// ⚡ Bolt optimization: Cached to prevent O(N) reallocation on every call.
  static Set<GameCard> fullDeck() => _cachedFullDeck;

  @override
  String toString() => isJoker ? 'Joker' : '${rank!.name} of ${suit!.name}';
}
