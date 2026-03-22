enum GamePhase {
  waiting,
  dealing,
  bidding,
  trumpSelection,
  playing,
  roundScoring,
  gameOver,
}

enum Team {
  a,
  b;

  Team get opponent => this == Team.a ? Team.b : Team.a;
}

Team teamForSeat(int seatIndex) => seatIndex.isEven ? Team.a : Team.b;

int nextSeat(int seatIndex, {int playerCount = 4}) =>
    (seatIndex + 1) % playerCount;
