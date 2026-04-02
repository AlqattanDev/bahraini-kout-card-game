import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/app/models/seat_config.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/local_game_controller.dart';
import 'package:koutbh/offline/bot_player_controller.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/card_tracker.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';
import 'package:koutbh/offline/bot/trump_strategy.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';

/// A PlayerController that auto-responds with bot logic but can be used
/// in seat 0 (the "human" seat) to test the full game loop and state stream
/// without the stream-listener-vs-Completer race condition.
class AutoRespondController implements PlayerController {
  final int seatIndex;
  AutoRespondController({required this.seatIndex});

  @override
  Future<GameAction> decideAction(
      ClientGameState state, ActionContext context,
      {CardTracker? tracker}) async {
    return switch (context) {
      BidContext(:final currentHighBid, :final isForced) =>
        BidStrategy.decideBid(state.myHand, currentHighBid, isForced: isForced),
      TrumpContext() => TrumpAction(TrumpStrategy.selectTrump(state.myHand)),
      PlayContext(:final ledSuit) => PlayStrategy.selectCard(
          hand: state.myHand,
          trickPlays: state.currentTrickPlays,
          trumpSuit: state.trumpSuit,
          ledSuit: ledSuit,
          mySeat: seatIndex,
          partnerUid: state.playerUids[(seatIndex + 2) % 4],
        ),
    };
  }
}

void main() {
  group('Stream integration — human + 3 bots', () {
    test('human controller can feed actions and game progresses', () async {
      final seats = [
        const SeatConfig(seatIndex: 0, uid: 'human', displayName: 'You', isBot: false),
        const SeatConfig(seatIndex: 1, uid: 'bot_1', displayName: 'Bot 1', isBot: true),
        const SeatConfig(seatIndex: 2, uid: 'bot_2', displayName: 'Bot 2', isBot: true),
        const SeatConfig(seatIndex: 3, uid: 'bot_3', displayName: 'Bot 3', isBot: true),
      ];

      final controllers = <int, PlayerController>{
        0: AutoRespondController(seatIndex: 0),
        1: BotPlayerController(seatIndex: 1),
        2: BotPlayerController(seatIndex: 2),
        3: BotPlayerController(seatIndex: 3),
      };

      final controller = LocalGameController(
        seats: seats,
        controllers: controllers,
        humanSeat: 0,
        enableDelays: false,
      );

      final states = <ClientGameState>[];
      final completer = Completer<void>();

      controller.stateStream.listen(
        (state) => states.add(state),
        onDone: () => completer.complete(),
      );

      await controller.start();
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      if (!completer.isCompleted) await completer.future;

      expect(states, isNotEmpty);
      expect(states.last.phase, GamePhase.gameOver);

      // Verify we saw all expected phases during the game
      final phases = states.map((s) => s.phase).toSet();
      expect(phases, contains(GamePhase.dealing));
      expect(phases, contains(GamePhase.bidding));
      expect(phases, contains(GamePhase.trumpSelection));
      expect(phases, contains(GamePhase.playing));
      expect(phases, contains(GamePhase.roundScoring));
      expect(phases, contains(GamePhase.gameOver));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
