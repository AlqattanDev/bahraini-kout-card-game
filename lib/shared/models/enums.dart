enum Suit {
  spades,
  hearts,
  clubs,
  diamonds;

  String get symbol => switch (this) {
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.clubs => '♣',
        Suit.diamonds => '♦',
      };

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

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

  String get label => switch (this) {
        Rank.ace => 'A',
        Rank.king => 'K',
        Rank.queen => 'Q',
        Rank.jack => 'J',
        Rank.ten => '10',
        Rank.nine => '9',
        Rank.eight => '8',
        Rank.seven => '7',
      };
}
