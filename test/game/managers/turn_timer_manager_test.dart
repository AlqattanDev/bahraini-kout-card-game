import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/game/components/player_seat.dart';
import 'package:koutbh/game/managers/turn_timer_manager.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';

ClientGameState _state({
  required GamePhase phase,
  required String currentPlayerUid,
  List<({String playerUid, GameCard card})> currentTrickPlays = const [],
  List<Team> trickWinners = const [],
  List<({String playerUid, String action})> bidHistory = const [],
}) {
  return ClientGameState(
    phase: phase,
    playerUids: const ['uid-0', 'uid-1', 'uid-2', 'uid-3'],
    scores: const {Team.a: 0, Team.b: 0},
    tricks: const {Team.a: 0, Team.b: 0},
    currentPlayerUid: currentPlayerUid,
    dealerUid: 'uid-0',
    trumpSuit: Suit.spades,
    currentBid: BidAmount.six,
    bidderUid: 'uid-1',
    currentTrickPlays: currentTrickPlays,
    myHand: const [],
    myUid: 'uid-0',
    bidHistory: bidHistory,
    trickWinners: trickWinners,
    cardCounts: const {0: 8, 1: 8, 2: 8, 3: 8},
  );
}

List<PlayerSeatComponent> _seats() {
  return List.generate(
    4,
    (i) => PlayerSeatComponent(
      seatIndex: i,
      playerName: 'p$i',
      cardCount: 8,
      isActive: false,
      team: teamForSeat(i),
    ),
  );
}

void main() {
  group('TurnTimerManager', () {
    test('resets timer when same player starts a new trick', () {
      final manager = TurnTimerManager();
      final seats = _seats();

      final beforeReset = _state(
        phase: GamePhase.playing,
        currentPlayerUid: 'uid-1',
        trickWinners: const [],
      );

      manager.tick(1.0, beforeReset, seats);
      expect(seats[1].timerProgress, closeTo(0.75, 0.0001));

      final afterReset = _state(
        phase: GamePhase.playing,
        currentPlayerUid: 'uid-1',
        trickWinners: const [Team.a],
      );

      manager.tick(1.0, afterReset, seats);
      expect(seats[1].timerProgress, closeTo(0.75, 0.0001));
    });
  });
}
