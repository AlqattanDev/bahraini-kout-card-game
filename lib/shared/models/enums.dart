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
