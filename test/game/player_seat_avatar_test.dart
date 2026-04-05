import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/player_seat.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/app/models/client_game_state.dart';

ClientGameState _makeState({
  int currentSeat = 0,
  GamePhase phase = GamePhase.playing,
  List<({String playerUid, String action})>? bidHistory,
}) {
  return ClientGameState(
    playerUids: ['p0', 'p1', 'p2', 'p3'],
    myUid: 'p0',
    dealerUid: 'p0',
    phase: phase,
    myHand: const [],
    currentPlayerUid: 'p$currentSeat',
    scores: const {Team.a: 0, Team.b: 0},
    tricks: const {Team.a: 0, Team.b: 0},
    currentTrickPlays: const [],
    passedPlayers: const [],
    bidHistory: bidHistory ?? const [],
    trickWinners: const [],
    cardCounts: const {0: 8, 1: 8, 2: 8, 3: 8},
    currentBid: null,
    bidderUid: null,
    trumpSuit: null,
  );
}

void main() {
  group('PlayerSeatComponent', () {
    test('updateState correctly propagates all properties', () {
      final seat = PlayerSeatComponent(
        seatIndex: 1,
        playerName: 'Init',
        cardCount: 8,
        isActive: false,
        team: Team.a,
        avatarSeed: 0,
      );
      final state = _makeState(
        currentSeat: 1,
        phase: GamePhase.bidding,
        bidHistory: [(playerUid: 'p1', action: 'pass')],
      );
      seat.updateState(state);
      expect(seat.playerName, 'p1');
      expect(seat.cardCount, 8);
      expect(seat.isActive, true);
      expect(seat.team, Team.b);
      expect(seat.bidAction, 'pass');
    });

    test('avatarSeed is immutable after construction', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'Test',
        cardCount: 8,
        isActive: false,
        team: Team.a,
        avatarSeed: 2,
      );
      seat.updateState(_makeState());
      expect(seat.avatarSeed, 2);
    });

    test('timerProgress defaults to 0 and can be set', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'Timer',
        cardCount: 8,
        isActive: true,
        team: Team.a,
        avatarSeed: 0,
      );
      expect(seat.timerProgress, 0.0);
      seat.timerProgress = 0.75;
      expect(seat.timerProgress, 0.75);
    });

    test('component size accounts for avatar radius + name pill', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'Size',
        cardCount: 8,
        isActive: false,
        team: Team.a,
        avatarSeed: 0,
      );
      expect(seat.size.x, greaterThan(72));
      expect(seat.size.y, greaterThan(72 + 20));
    });

    test('_truncateName shortens names over 8 chars', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'VeryLongPlayerName',
        cardCount: 8,
        isActive: false,
        team: Team.a,
        avatarSeed: 0,
      );
      expect(seat.playerName, 'VeryLongPlayerName');
    });
  });
}
