import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/app/models/seat_config.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/local_game_controller.dart';
import 'package:koutbh/offline/bot_player_controller.dart';
import 'package:koutbh/offline/player_controller.dart';

class _SingleRoundBidController implements PlayerController {
  final BidAmount? openingBid;
  int _bidActions = 0;

  _SingleRoundBidController({required this.openingBid});

  @override
  Future<GameAction> decideAction(
    ClientGameState state,
    ActionContext context,
  ) async {
    if (context is BidContext) {
      _bidActions += 1;
      if (_bidActions == 1) {
        if (openingBid != null) {
          final required = context.currentHighBid != null
              ? BidAmount.nextAbove(context.currentHighBid!)
              : openingBid;
          if (required != null && required.value > openingBid!.value) {
            return BidAction(required);
          }
          return BidAction(openingBid!);
        }
        return PassAction();
      }
      return PassAction();
    }

    if (context is TrumpContext) {
      return TrumpAction(Suit.spades);
    }

    if (context is PlayContext) {
      final legal = _legalCards(state.myHand, context.ledSuit);
      return PlayCardAction(legal.first);
    }

    throw StateError('Unexpected context: $context');
  }

  List<GameCard> _legalCards(List<GameCard> hand, Suit? ledSuit) {
    if (ledSuit == null) return hand;
    final followSuit = hand
        .where((c) => !c.isJoker && c.suit == ledSuit)
        .toList();
    if (followSuit.isNotEmpty) return followSuit;
    return hand;
  }
}

void main() {
  final seats = [
    const SeatConfig(
      seatIndex: 0,
      uid: 'bot_0',
      displayName: 'Bot 0',
      isBot: true,
    ),
    const SeatConfig(
      seatIndex: 1,
      uid: 'bot_1',
      displayName: 'Bot 1',
      isBot: true,
    ),
    const SeatConfig(
      seatIndex: 2,
      uid: 'bot_2',
      displayName: 'Bot 2',
      isBot: true,
    ),
    const SeatConfig(
      seatIndex: 3,
      uid: 'bot_3',
      displayName: 'Bot 3',
      isBot: true,
    ),
  ];

  Map<int, PlayerController> makeBotControllers() => {
    for (final seat in seats)
      seat.seatIndex: BotPlayerController(seatIndex: seat.seatIndex),
  };

  /// Runs a full game and returns all emitted states.
  Future<List<ClientGameState>> runFullGame() async {
    final controller = LocalGameController(
      seats: seats,
      controllers: makeBotControllers(),
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

    // Allow stream events to flush
    await Future<void>.delayed(Duration.zero);
    if (!completer.isCompleted) await completer.future;

    return states;
  }

  group('LocalGameController — 4 bot simulation', () {
    test(
      'full game reaches GAME_OVER with valid scores',
      () async {
        final states = await runFullGame();

        expect(states, isNotEmpty);
        expect(states.last.phase, GamePhase.gameOver);

        final maxScore = [
          states.last.scores[Team.a] ?? 0,
          states.last.scores[Team.b] ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        expect(maxScore, greaterThanOrEqualTo(31));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('scores never go below 0', () async {
      final states = await runFullGame();

      for (final state in states) {
        expect(state.scores[Team.a] ?? 0, greaterThanOrEqualTo(0));
        expect(state.scores[Team.b] ?? 0, greaterThanOrEqualTo(0));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test(
      'dealer is always on the losing team (or stays if tied)',
      () async {
        final states = await runFullGame();

        final uidToSeat = {for (final s in seats) s.uid: s.seatIndex};

        // Check at dealing phase — the dealer rotation happens between rounds,
        // so the invariant holds at the START of each round (not during scoring).
        // Skip the first dealing since the dealer is random and scores are 0-0.
        var dealingCount = 0;
        for (final state in states) {
          if (state.phase != GamePhase.dealing) continue;
          dealingCount++;
          if (dealingCount <= 1)
            continue; // skip first round (random dealer, 0-0)
          final scoreA = state.scores[Team.a] ?? 0;
          final scoreB = state.scores[Team.b] ?? 0;
          if (scoreA == scoreB) continue; // tied → no constraint
          final losingTeam = scoreA < scoreB ? Team.a : Team.b;
          final dealerSeat = uidToSeat[state.dealerUid]!;
          expect(
            teamForSeat(dealerSeat),
            equals(losingTeam),
            reason:
                'Dealer should be on losing team (scores: A=$scoreA B=$scoreB, dealer seat=$dealerSeat)',
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'ClientGameState stream emits correct phases in order',
      () async {
        final states = await runFullGame();

        final phases = <GamePhase>[];
        for (final state in states) {
          if (phases.isEmpty || phases.last != state.phase) {
            phases.add(state.phase);
          }
        }

        expect(phases.first, GamePhase.dealing);
        expect(phases.last, GamePhase.gameOver);
        expect(phases, contains(GamePhase.bidding));
        expect(phases, contains(GamePhase.playing));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'human seat ClientGameState only contains that seat\'s hand',
      () async {
        final states = await runFullGame();

        for (final state in states) {
          if (state.phase == GamePhase.playing && state.myHand.isNotEmpty) {
            expect(state.myHand.length, lessThanOrEqualTo(8));
            expect(state.myUid, 'bot_0');
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('bidding ends after one full table cycle', () async {
      final singleRoundControllers = <int, PlayerController>{
        0: _SingleRoundBidController(openingBid: BidAmount.bab),
        1: _SingleRoundBidController(openingBid: BidAmount.six),
        2: _SingleRoundBidController(openingBid: null),
        3: _SingleRoundBidController(openingBid: null),
      };

      final controller = LocalGameController(
        seats: seats,
        controllers: singleRoundControllers,
        humanSeat: 0,
        enableDelays: false,
      );

      ClientGameState? firstTrumpSelection;
      final done = Completer<void>();
      final sub = controller.stateStream.listen((state) {
        if (firstTrumpSelection == null &&
            state.phase == GamePhase.trumpSelection) {
          firstTrumpSelection = state;
          done.complete();
        }
      });

      final runFuture = controller.start();
      await done.future.timeout(const Duration(seconds: 5));
      controller.dispose();
      await runFuture.timeout(const Duration(seconds: 5));
      await sub.cancel();

      expect(firstTrumpSelection, isNotNull);
      expect(firstTrumpSelection!.bidHistory.length, 4);
    });
  });
}
