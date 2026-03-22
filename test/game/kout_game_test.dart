import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/app/models/client_game_state.dart';
import 'package:bahraini_kout/game/kout_game.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/enums.dart';

/// Builds a minimal [ClientGameState] suitable for testing.
ClientGameState _buildState({
  GamePhase phase = GamePhase.playing,
  String myUid = 'uid-0',
  bool isMyTurn = false,
  String? bidderUid,
  BidAmount? currentBid,
}) {
  return ClientGameState(
    phase: phase,
    playerUids: ['uid-0', 'uid-1', 'uid-2', 'uid-3'],
    scores: {Team.a: 0, Team.b: 0},
    tricks: {Team.a: 0, Team.b: 0},
    currentPlayerUid: isMyTurn ? myUid : 'uid-1',
    dealerUid: 'uid-3',
    trumpSuit: Suit.spades,
    currentBid: currentBid,
    bidderUid: bidderUid,
    currentTrickPlays: [],
    myHand: const [],
    myUid: myUid,
  );
}

/// Registers stub overlay builders so [KoutGame._updateOverlays] can call
/// [overlays.add] without an assertion error in unit-test environments
/// (which have no [GameWidget] to provide the real overlay map).
void _registerOverlays(KoutGame game) {
  for (final name in ['bid', 'trump', 'roundResult', 'gameOver']) {
    game.overlays.addEntry(name, (context, g) => const SizedBox.shrink());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KoutGame', () {
    test('initializes without error on empty state stream', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      // onLoad must complete without throwing
      await game.onLoad();

      await controller.close();
    });

    test('processes a playing-phase state without error', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(phase: GamePhase.playing));

      // Give microtask queue a chance to process the stream event
      await Future<void>.delayed(Duration.zero);

      expect(game.currentState, isNotNull);
      expect(game.currentState!.phase, GamePhase.playing);

      await controller.close();
    });

    test('shows bid overlay when it is my turn during bidding', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(
        phase: GamePhase.bidding,
        isMyTurn: true,
      ));

      await Future<void>.delayed(Duration.zero);

      expect(game.overlays.isActive('bid'), isTrue);
      expect(game.overlays.isActive('trump'), isFalse);
      expect(game.overlays.isActive('roundResult'), isFalse);
      expect(game.overlays.isActive('gameOver'), isFalse);

      await controller.close();
    });

    test('does not show bid overlay when it is not my turn', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(
        phase: GamePhase.bidding,
        isMyTurn: false,
      ));

      await Future<void>.delayed(Duration.zero);

      expect(game.overlays.isActive('bid'), isFalse);

      await controller.close();
    });

    test('shows trump overlay when I am the bidder during trump selection', () async {
      final controller = StreamController<ClientGameState>();
      const myUid = 'uid-0';
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(
        phase: GamePhase.trumpSelection,
        myUid: myUid,
        bidderUid: myUid,
        currentBid: BidAmount.six,
      ));

      await Future<void>.delayed(Duration.zero);

      expect(game.overlays.isActive('trump'), isTrue);

      await controller.close();
    });

    test('does not show trump overlay when I am not the bidder', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(
        phase: GamePhase.trumpSelection,
        myUid: 'uid-0',
        bidderUid: 'uid-2', // someone else won the bid
        currentBid: BidAmount.six,
      ));

      await Future<void>.delayed(Duration.zero);

      expect(game.overlays.isActive('trump'), isFalse);

      await controller.close();
    });

    test('shows roundResult overlay during round scoring', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(phase: GamePhase.roundScoring));

      await Future<void>.delayed(Duration.zero);

      expect(game.overlays.isActive('roundResult'), isTrue);

      await controller.close();
    });

    test('shows gameOver overlay during game over phase', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      controller.add(_buildState(phase: GamePhase.gameOver));

      await Future<void>.delayed(Duration.zero);

      expect(game.overlays.isActive('gameOver'), isTrue);

      await controller.close();
    });

    test('removes bid overlay when transitioning from bidding to playing', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      // Start in bidding (my turn)
      controller.add(_buildState(phase: GamePhase.bidding, isMyTurn: true));
      await Future<void>.delayed(Duration.zero);
      expect(game.overlays.isActive('bid'), isTrue);

      // Transition to playing — bid overlay should be removed
      controller.add(_buildState(phase: GamePhase.playing));
      await Future<void>.delayed(Duration.zero);
      expect(game.overlays.isActive('bid'), isFalse);

      await controller.close();
    });

    test('onAction callback is invoked correctly', () async {
      final controller = StreamController<ClientGameState>();
      String? capturedAction;
      Map<String, dynamic>? capturedData;

      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (action, data) {
          capturedAction = action;
          capturedData = data;
        },
      );

      await game.onLoad();

      game.onAction('playCard', {'card': 'SA'});

      expect(capturedAction, 'playCard');
      expect(capturedData, {'card': 'SA'});

      await controller.close();
    });

    test('currentState is updated on each state emission', () async {
      final controller = StreamController<ClientGameState>();
      final game = KoutGame(
        stateStream: controller.stream,
        onAction: (_, __) {},
      );

      await game.onLoad();
      _registerOverlays(game);

      expect(game.currentState, isNull);

      controller.add(_buildState(phase: GamePhase.bidding));
      await Future<void>.delayed(Duration.zero);
      expect(game.currentState!.phase, GamePhase.bidding);

      controller.add(_buildState(phase: GamePhase.playing));
      await Future<void>.delayed(Duration.zero);
      expect(game.currentState!.phase, GamePhase.playing);

      await controller.close();
    });
  });
}
