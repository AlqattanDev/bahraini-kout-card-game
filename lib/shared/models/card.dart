enum Suit { spades, hearts, clubs, diamonds }

enum Rank {
  ace(14),
  king(13),
  queen(12),
  jack(11),
  ten(10),
  nine(9),
  eight(8),
  seven(7);

  const Rank(this.value);
  final int value;
}

// Internal encoding maps — kept private to this file.
// The public equivalents live in lib/shared/constants.dart.
const _suitInitial = {
  Suit.spades: 'S',
  Suit.hearts: 'H',
  Suit.clubs: 'C',
  Suit.diamonds: 'D',
};

const _initialToSuit = {
  'S': Suit.spades,
  'H': Suit.hearts,
  'C': Suit.clubs,
  'D': Suit.diamonds,
};

const _rankString = {
  Rank.ace: 'A',
  Rank.king: 'K',
  Rank.queen: 'Q',
  Rank.jack: 'J',
  Rank.ten: '10',
  Rank.nine: '9',
  Rank.eight: '8',
  Rank.seven: '7',
};

const _stringToRank = {
  'A': Rank.ace,
  'K': Rank.king,
  'Q': Rank.queen,
  'J': Rank.jack,
  '10': Rank.ten,
  '9': Rank.nine,
  '8': Rank.eight,
  '7': Rank.seven,
};

class GameCard {
  final Suit? suit;
  final Rank? rank;
  final bool isJoker;

  const GameCard({required Suit suit, required Rank rank})
      : suit = suit,
        rank = rank,
        isJoker = false;

  const GameCard._joker()
      : suit = null,
        rank = null,
        isJoker = true;

  factory GameCard.joker() => const GameCard._joker();

  String encode() {
    if (isJoker) return 'JO';
    return '${_suitInitial[suit!]}${_rankString[rank!]}';
  }

  factory GameCard.decode(String encoded) {
    if (encoded == 'JO') return GameCard.joker();
    final suitChar = encoded.substring(0, 1);
    final rankStr = encoded.substring(1);
    final suit = _initialToSuit[suitChar];
    final rank = _stringToRank[rankStr];
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

  @override
  String toString() => encode();
}
