import '../models/bid.dart';
import '../models/game_state.dart';

class RoundResult {
  final Team winningTeam;
  final int pointsAwarded;
  const RoundResult({required this.winningTeam, required this.pointsAwarded});
}

class Scorer {
  static RoundResult calculateRoundResult({
    required BidAmount bid,
    required Team biddingTeam,
    required Map<Team, int> tricksWon,
  }) {
    final biddingTeamTricks = tricksWon[biddingTeam] ?? 0;
    final success = biddingTeamTricks >= bid.value;
    if (success) {
      return RoundResult(
          winningTeam: biddingTeam, pointsAwarded: bid.successPoints);
    } else {
      return RoundResult(
          winningTeam: biddingTeam.opponent,
          pointsAwarded: bid.failurePoints);
    }
  }

  static RoundResult calculatePoisonJokerResult({
    required Team biddingTeam,
    required Team poisonTeam,
  }) {
    return RoundResult(winningTeam: poisonTeam.opponent, pointsAwarded: 10);
  }

  static Map<Team, int> applyScore({
    required Map<Team, int> scores,
    required Team winningTeam,
    required int points,
  }) {
    return {
      for (final team in Team.values)
        team: team == winningTeam
            ? (scores[team] ?? 0) + points
            : (scores[team] ?? 0).clamp(0, 999),
    };
  }

  static Team? checkGameOver(Map<Team, int> scores) {
    for (final team in Team.values) {
      if ((scores[team] ?? 0) >= 31) return team;
    }
    return null;
  }
}
