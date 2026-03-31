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

  /// Tug-of-war scoring: points first reduce the opponent's score,
  /// then the remainder goes to the winning team.
  /// Invariant: only one team ever has a non-zero score.
  static Map<Team, int> applyScore({
    required Map<Team, int> scores,
    required Team winningTeam,
    required int points,
  }) {
    final losingTeam = winningTeam.opponent;
    final net = (scores[winningTeam] ?? 0) + points - (scores[losingTeam] ?? 0);
    if (net >= 0) {
      return {winningTeam: net, losingTeam: 0};
    } else {
      return {winningTeam: 0, losingTeam: -net};
    }
  }

  /// Kout instant win: sets the winning team to 31 regardless of current score.
  static Map<Team, int> applyKout({required Team winningTeam}) {
    return {winningTeam: 31, winningTeam.opponent: 0};
  }

  static Team? checkGameOver(Map<Team, int> scores) {
    for (final team in Team.values) {
      if ((scores[team] ?? 0) >= 31) return team;
    }
    return null;
  }

  /// Returns true when the round outcome is mathematically decided:
  /// bidder reached their bid, or opponent has enough tricks to kill it.
  static bool isRoundDecided({
    required int bidValue,
    required Team biddingTeam,
    required Map<Team, int> tricksWon,
  }) {
    final bidderTricks = tricksWon[biddingTeam] ?? 0;
    final opponentTricks = tricksWon[biddingTeam.opponent] ?? 0;
    return bidderTricks >= bidValue || opponentTricks > 8 - bidValue;
  }
}
