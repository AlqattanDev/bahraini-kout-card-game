import 'package:koutbh/shared/models/enums.dart';

// ---------------------------------------------------------------------------
// Game rules — single source of truth for domain constants
// ---------------------------------------------------------------------------

/// Score a team must reach to win the game.
const int targetScore = 31;

/// Total tricks played per round (32 cards / 4 players).
const int tricksPerRound = 8;

/// Number of players in a standard game.
const int playerCount = 4;

// ---------------------------------------------------------------------------
// Card encoding maps
// ---------------------------------------------------------------------------

const Map<Suit, String> suitInitial = {
  Suit.spades: 'S',
  Suit.hearts: 'H',
  Suit.clubs: 'C',
  Suit.diamonds: 'D',
};

const Map<String, Suit> initialToSuit = {
  'S': Suit.spades,
  'H': Suit.hearts,
  'C': Suit.clubs,
  'D': Suit.diamonds,
};

const Map<Rank, String> rankString = {
  Rank.ace: 'A',
  Rank.king: 'K',
  Rank.queen: 'Q',
  Rank.jack: 'J',
  Rank.ten: '10',
  Rank.nine: '9',
  Rank.eight: '8',
  Rank.seven: '7',
};

const Map<String, Rank> stringToRank = {
  'A': Rank.ace,
  'K': Rank.king,
  'Q': Rank.queen,
  'J': Rank.jack,
  '10': Rank.ten,
  '9': Rank.nine,
  '8': Rank.eight,
  '7': Rank.seven,
};
