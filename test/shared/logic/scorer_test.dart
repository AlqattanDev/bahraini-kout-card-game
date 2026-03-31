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

    test('kout failure (7 tricks) → +16 to opponent', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 7, Team.b: 1},
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 16);
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

    test('joker lead → +10 to opponent (same as poison joker)', () {
      // When a player leads the Joker, their team loses the round.
      // Uses the same scoring path as poison joker.
      final result = Scorer.calculatePoisonJokerResult(
        biddingTeam: Team.b,
        poisonTeam: Team.a, // Team A led the Joker
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 10);
    });
  });

  group('Scorer.applyScore (tug-of-war)', () {
    test('from zero: points go to winning team', () {
      final scores = Scorer.applyScore(
        scores: {Team.a: 0, Team.b: 0},
        winningTeam: Team.a,
        points: 5,
      );
      expect(scores[Team.a], 5);
      expect(scores[Team.b], 0);
    });

    test('adds to leading team when same team wins', () {
      final scores = Scorer.applyScore(
        scores: {Team.a: 7, Team.b: 0},
        winningTeam: Team.a,
        points: 5,
      );
      expect(scores[Team.a], 12);
      expect(scores[Team.b], 0);
    });

    test('deducts from opponent first, remainder to winner', () {
      // Team A leads 7, Team B wins 10 → net: 0 + 10 - 7 = 3 for B
      final scores = Scorer.applyScore(
        scores: {Team.a: 7, Team.b: 0},
        winningTeam: Team.b,
        points: 10,
      );
      expect(scores[Team.a], 0);
      expect(scores[Team.b], 3);
    });

    test('exact cancel results in 0-0', () {
      final scores = Scorer.applyScore(
        scores: {Team.a: 5, Team.b: 0},
        winningTeam: Team.b,
        points: 5,
      );
      expect(scores[Team.a], 0);
      expect(scores[Team.b], 0);
    });

    test('partial deduction stays with original leader', () {
      // Team A leads 10, Team B wins 3 → net: 10 - 3 = 7 for A still
      final scores = Scorer.applyScore(
        scores: {Team.a: 10, Team.b: 0},
        winningTeam: Team.b,
        points: 3,
      );
      expect(scores[Team.a], 7);
      expect(scores[Team.b], 0);
    });
  });

  group('Scorer.applyKout', () {
    test('kout instant win sets winner to 31', () {
      final scores = Scorer.applyKout(winningTeam: Team.a);
      expect(scores[Team.a], 31);
      expect(scores[Team.b], 0);
    });

    test('kout instant loss sets opponent to 31', () {
      final scores = Scorer.applyKout(winningTeam: Team.b);
      expect(scores[Team.a], 0);
      expect(scores[Team.b], 31);
    });
  });

  group('Scorer.checkGameOver', () {
    test('game over when team reaches 31', () {
      final winner = Scorer.checkGameOver({Team.a: 31, Team.b: 0});
      expect(winner, Team.a);
    });

    test('game over when team exceeds 31', () {
      final winner = Scorer.checkGameOver({Team.a: 0, Team.b: 35});
      expect(winner, Team.b);
    });

    test('game not over below 31', () {
      final winner = Scorer.checkGameOver({Team.a: 20, Team.b: 0});
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

  group('Scorer.isRoundDecided', () {
    test('bidder reaches bid → decided', () {
      expect(
        Scorer.isRoundDecided(
            bidValue: 5, biddingTeam: Team.a, tricksWon: {Team.a: 5, Team.b: 2}),
        isTrue,
      );
    });

    test('opponent kills bid → decided', () {
      // Bid 5: opponent needs > 3 tricks to kill (i.e. 4+)
      expect(
        Scorer.isRoundDecided(
            bidValue: 5, biddingTeam: Team.a, tricksWon: {Team.a: 2, Team.b: 4}),
        isTrue,
      );
    });

    test('not yet decided → false', () {
      expect(
        Scorer.isRoundDecided(
            bidValue: 5, biddingTeam: Team.a, tricksWon: {Team.a: 4, Team.b: 3}),
        isFalse,
      );
    });

    test('bid 8 (kout) only decided at 8 wins or 1 opponent win', () {
      expect(
        Scorer.isRoundDecided(
            bidValue: 8, biddingTeam: Team.a, tricksWon: {Team.a: 7, Team.b: 0}),
        isFalse,
      );
      expect(
        Scorer.isRoundDecided(
            bidValue: 8, biddingTeam: Team.a, tricksWon: {Team.a: 8, Team.b: 0}),
        isTrue,
      );
      expect(
        Scorer.isRoundDecided(
            bidValue: 8, biddingTeam: Team.a, tricksWon: {Team.a: 0, Team.b: 1}),
        isTrue,
      );
    });

    test('bid 6: opponent needs > 2 tricks', () {
      expect(
        Scorer.isRoundDecided(
            bidValue: 6, biddingTeam: Team.b, tricksWon: {Team.a: 2, Team.b: 3}),
        isFalse,
      );
      expect(
        Scorer.isRoundDecided(
            bidValue: 6, biddingTeam: Team.b, tricksWon: {Team.a: 3, Team.b: 3}),
        isTrue,
      );
    });
  });
}
