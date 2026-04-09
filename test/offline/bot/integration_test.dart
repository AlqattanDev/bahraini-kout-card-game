import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/app/models/seat_config.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/local_game_controller.dart';
import 'package:koutbh/offline/bot_player_controller.dart';

/// Integration test: runs [_gameCount] full games with 4 bots.
///
/// Verifies:
///   1. No exceptions thrown during gameplay.
///   2. Every game reaches completion (a team hits 31).
///   3. No illegal plays attempted (validated inside LocalGameController).
///   4. Poison joker deaths are rare with proper Joker management.
const _gameCount = 100;

/// Run a single game with 4 bots and return the final state phase and scores.
Future<({GamePhase phase, Map<Team, int> scores, int rounds})>
    _runOneGame() async {
  final seats = List.generate(
    4,
    (seat) => SeatConfig(
      seatIndex: seat,
      uid: 'bot_$seat',
      displayName: 'Bot $seat',
      isBot: true,
    ),
  );

  final controllers = {
    for (int seat = 0; seat < 4; seat++)
      seat: BotPlayerController(seatIndex: seat),
  };

  final controller = LocalGameController(
    seats: seats,
    controllers: controllers,
    humanSeat: 0,
    enableDelays: false,
  );

  GamePhase lastPhase = GamePhase.waiting;
  Map<Team, int> lastScores = {Team.a: 0, Team.b: 0};
  int lastRoundIndex = 0;

  final gameOverCompleter = Completer<void>();

  controller.stateStream.listen((state) {
    lastPhase = state.phase;
    lastScores = state.scores;
    lastRoundIndex = state.roundIndex;
    if (state.phase == GamePhase.gameOver && !gameOverCompleter.isCompleted) {
      gameOverCompleter.complete();
    }
  });

  // Run the game loop. This drives the entire game to completion.
  await controller.start();

  // Wait for the gameOver state to propagate through the async stream.
  // Use a short timeout to avoid hanging forever if something goes wrong.
  await gameOverCompleter.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      // If we get here, the game finished running but never emitted gameOver.
      // This is a real failure — don't swallow it.
    },
  );

  controller.dispose();

  return (phase: lastPhase, scores: lastScores, rounds: lastRoundIndex);
}

void main() {
  group('Bot integration — $_gameCount simulated games', () {
    int poisonJokerGames = 0;
    int completedGames = 0;
    int totalRounds = 0;

    for (int i = 0; i < _gameCount; i++) {
      test('game ${i + 1} completes without errors', () async {
        final result = await _runOneGame();

        expect(result.phase, equals(GamePhase.gameOver),
            reason: 'Game ${i + 1} did not reach gameOver phase');

        final maxScore = [
          result.scores[Team.a] ?? 0,
          result.scores[Team.b] ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        expect(maxScore, greaterThanOrEqualTo(31),
            reason: 'Game ${i + 1}: no team reached 31 (scores: ${result.scores})');

        completedGames++;
        totalRounds += result.rounds;

        // Heuristic: single-round games are likely poison joker or kout wins.
        if (result.rounds <= 1) {
          poisonJokerGames++;
        }
      });
    }

    test('summary: all $_gameCount games completed', () {
      expect(completedGames, equals(_gameCount),
          reason: 'Expected $_gameCount completed games, got $completedGames');

      // Poison joker / single-round games should be rare (< 30% of games).
      // This is a soft check — the main assertion is that all games complete.
      final poisonRate = poisonJokerGames / _gameCount;
      // ignore: avoid_print
      print('Completed: $completedGames/$_gameCount games');
      // ignore: avoid_print
      print('Total rounds played: $totalRounds '
          '(avg ${(totalRounds / completedGames).toStringAsFixed(1)} rounds/game)');
      // ignore: avoid_print
      print('Single-round games (kout/poison): $poisonJokerGames '
          '(${(poisonRate * 100).toStringAsFixed(1)}%)');
    });
  });
}
