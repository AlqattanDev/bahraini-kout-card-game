enum GamePhase {
  waiting,
  dealing,
  bidding,
  trumpSelection,
  bidAnnouncement,
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

/// Produces a short display name from a UID.
/// Offline bot UIDs like "bot_1" become "Bot 1".
/// Online UIDs get first 6 chars.
String shortUid(String uid) {
  if (uid.startsWith('bot_')) {
    final num = uid.substring(4);
    return 'Bot $num';
  }
  if (uid.length <= 8) return uid;
  return uid.substring(0, 6);
}

/// Next seat in counter-clockwise (right-to-left) order: 0→3→2→1.
int nextSeat(int seatIndex, {int playerCount = 4}) =>
    (seatIndex - 1 + playerCount) % playerCount;

/// Losing team deals. Dealer only rotates when the losing team flips.
int nextDealerSeat(int currentDealer, Map<Team, int> scores) {
  final scoreA = scores[Team.a] ?? 0;
  final scoreB = scores[Team.b] ?? 0;
  if (scoreA == scoreB) return currentDealer;
  final losingTeam = scoreA < scoreB ? Team.a : Team.b;
  if (teamForSeat(currentDealer) == losingTeam) return currentDealer;
  return nextSeat(currentDealer);
}
