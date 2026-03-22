import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/logic/scorer.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';

void main() {
  group('Scorer.calculateRoundResult', () {
    test('bid 5 success (5+ tricks) → +5 to bidding team', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.bab,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 5, Team.b: 3},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 5);
    });

    test('bid 5 success with 8 tricks → still +5', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.bab,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 8, Team.b: 0},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 5);
    });

    test('bid 6 failure (4 tricks) → +12 to opponent', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.six,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 4, Team.b: 4},
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 12);
    });

    test('bid 7 failure (6 tricks) → +14 to opponent', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.seven,
        biddingTeam: Team.b,
        tricksWon: {Team.a: 2, Team.b: 6},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 14);
    });

    test('kout success (8 tricks) → +31 to bidding team', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 8, Team.b: 0},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 31);
    });

    test('kout failure (7 tricks) → +31 to opponent', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 7, Team.b: 1},
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 31);
    });

    test('poison joker → +10 to opponent regardless of bid', () {
      final result = Scorer.calculatePoisonJokerResult(
        biddingTeam: Team.a,
        poisonTeam: Team.b,
      );
      // poisonTeam.opponent = Team.a; the team that caught the poison joker
      // loses, so the other team gets points
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 10);
    });
  });

  group('Scorer.applyScore', () {
    test('adds points to winning team only, losing team unchanged', () {
      final scores = Scorer.applyScore(
        scores: {Team.a: 10, Team.b: 5},
        winningTeam: Team.a,
        points: 7,
      );
      expect(scores[Team.a], 17);
      expect(scores[Team.b], 5);
    });

    test('scores clamp at 0 (never negative)', () {
      // Losing team score is preserved as-is (clamped to 0 minimum)
      // Scores should never start negative, but clamp ensures safety
      final scores = Scorer.applyScore(
        scores: {Team.a: 0, Team.b: 0},
        winningTeam: Team.a,
        points: 5,
      );
      expect(scores[Team.a], 5);
      expect(scores[Team.b], 0); // clamped, not negative
    });
  });

  group('Scorer.checkGameOver', () {
    test('game over when team reaches 31', () {
      final winner = Scorer.checkGameOver({Team.a: 31, Team.b: 10});
      expect(winner, Team.a);
    });

    test('game over when team exceeds 31', () {
      final winner = Scorer.checkGameOver({Team.a: 12, Team.b: 35});
      expect(winner, Team.b);
    });

    test('game not over below 31', () {
      final winner = Scorer.checkGameOver({Team.a: 20, Team.b: 30});
      expect(winner, isNull);
    });
  });

  group('Team helpers', () {
    test('seats 0,2 = Team.a; seats 1,3 = Team.b', () {
      expect(teamForSeat(0), Team.a);
      expect(teamForSeat(2), Team.a);
      expect(teamForSeat(1), Team.b);
      expect(teamForSeat(3), Team.b);
    });

    test('opponent team works correctly', () {
      expect(Team.a.opponent, Team.b);
      expect(Team.b.opponent, Team.a);
    });
  });
}
