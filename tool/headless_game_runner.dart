// ignore_for_file: avoid_print
import 'dart:io';
import 'package:bahraini_kout/app/models/seat_config.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/offline/local_game_controller.dart';
import 'package:bahraini_kout/offline/bot_player_controller.dart';
import 'package:bahraini_kout/offline/player_controller.dart';

/// Headless bot-vs-bot game simulator.
///
/// Usage: dart run tool/headless_game_runner.dart --games=100
Future<void> main(List<String> args) async {
  int gameCount = 10;
  for (final arg in args) {
    if (arg.startsWith('--games=')) {
      gameCount = int.parse(arg.substring('--games='.length));
    }
  }

  print('Running $gameCount headless games...\n');

  final seats = [
    const SeatConfig(seatIndex: 0, uid: 'bot_0', displayName: 'Bot 0', isBot: true),
    const SeatConfig(seatIndex: 1, uid: 'bot_1', displayName: 'Bot 1', isBot: true),
    const SeatConfig(seatIndex: 2, uid: 'bot_2', displayName: 'Bot 2', isBot: true),
    const SeatConfig(seatIndex: 3, uid: 'bot_3', displayName: 'Bot 3', isBot: true),
  ];

  int teamAWins = 0;
  int teamBWins = 0;
  int totalRounds = 0;
  int errors = 0;
  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < gameCount; i++) {
    try {
      final controllers = <int, PlayerController>{
        for (final seat in seats) seat.seatIndex: BotPlayerController(seatIndex: seat.seatIndex),
      };

      final controller = LocalGameController(
        seats: seats,
        controllers: controllers,
        humanSeat: 0,
        enableDelays: false,
      );

      int roundCount = 0;
      Team? winner;

      controller.stateStream.listen((state) {
        if (state.phase == GamePhase.dealing) roundCount++;
        if (state.phase == GamePhase.gameOver) {
          final scoreA = state.scores[Team.a] ?? 0;
          final scoreB = state.scores[Team.b] ?? 0;
          if (scoreA >= 31) winner = Team.a;
          if (scoreB >= 31) winner = Team.b;
        }

        // Assertions
        assert((state.scores[Team.a] ?? 0) >= 0, 'Team A score negative');
        assert((state.scores[Team.b] ?? 0) >= 0, 'Team B score negative');
        assert(state.myHand.length <= 8, 'Hand exceeds 8 cards');
      });

      await controller.start();
      controller.dispose();

      totalRounds += roundCount;
      if (winner == Team.a) {
        teamAWins++;
      } else if (winner == Team.b) {
        teamBWins++;
      }

      if ((i + 1) % 10 == 0 || i == gameCount - 1) {
        stdout.write('\rCompleted ${i + 1}/$gameCount games');
      }
    } catch (e, st) {
      errors++;
      print('\nError in game ${i + 1}: $e');
      print(st);
    }
  }

  stopwatch.stop();
  print('\n');
  print('=' * 50);
  print('Results ($gameCount games, ${stopwatch.elapsed.inSeconds}s)');
  print('=' * 50);
  print('Team A wins: $teamAWins (${(teamAWins / gameCount * 100).toStringAsFixed(1)}%)');
  print('Team B wins: $teamBWins (${(teamBWins / gameCount * 100).toStringAsFixed(1)}%)');
  print('Avg rounds per game: ${(totalRounds / gameCount).toStringAsFixed(1)}');
  print('Errors: $errors');
  print('=' * 50);
}
