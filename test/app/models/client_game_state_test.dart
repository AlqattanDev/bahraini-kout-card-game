import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/models/bid.dart';

Map<String, dynamic> _baseGameData({
  String phase = 'playing',
  String? currentPlayerUid = 'uid-0',
  String? trumpSuit = 'spades',
  int? currentBid = 6,
  String? bidderUid = 'uid-0',
  List<dynamic>? currentTrick,
}) {
  return {
    'phase': phase,
    'playerUids': ['uid-0', 'uid-1', 'uid-2', 'uid-3'],
    'scores': {'a': 12, 'b': 7},
    'tricks': {'a': 3, 'b': 2},
    'currentPlayerUid': currentPlayerUid,
    'dealerUid': 'uid-3',
    'trumpSuit': trumpSuit,
    'currentBid': currentBid,
    'bidderUid': bidderUid,
    'currentTrick': currentTrick,
  };
}

void main() {
  group('ClientGameState.fromMap', () {
    test('parses all fields correctly', () {
      final trick = [
        {'playerUid': 'uid-0', 'card': 'SA'},
        {'playerUid': 'uid-1', 'card': 'H10'},
      ];
      final data = _baseGameData(currentTrick: trick);
      final myHand = ['CK', 'DQ', 'S7'];

      final state = ClientGameState.fromMap(data, 'uid-0', myHand);

      expect(state.phase, GamePhase.playing);
      expect(state.playerUids, ['uid-0', 'uid-1', 'uid-2', 'uid-3']);
      expect(state.scores[Team.a], 12);
      expect(state.scores[Team.b], 7);
      expect(state.tricks[Team.a], 3);
      expect(state.tricks[Team.b], 2);
      expect(state.currentPlayerUid, 'uid-0');
      expect(state.dealerUid, 'uid-3');
      expect(state.trumpSuit, Suit.spades);
      expect(state.currentBid, BidAmount.six);
      expect(state.bidderUid, 'uid-0');
      expect(state.myUid, 'uid-0');

      expect(state.currentTrickPlays.length, 2);
      expect(state.currentTrickPlays[0].playerUid, 'uid-0');
      expect(state.currentTrickPlays[0].card, GameCard(suit: Suit.spades, rank: Rank.ace));
      expect(state.currentTrickPlays[1].playerUid, 'uid-1');
      expect(state.currentTrickPlays[1].card, GameCard(suit: Suit.hearts, rank: Rank.ten));

      expect(state.myHand.length, 3);
      expect(state.myHand[0], GameCard(suit: Suit.clubs, rank: Rank.king));
      expect(state.myHand[1], GameCard(suit: Suit.diamonds, rank: Rank.queen));
      expect(state.myHand[2], GameCard(suit: Suit.spades, rank: Rank.seven));
    });

    test('handles null currentTrick', () {
      final data = _baseGameData(currentTrick: null);
      final state = ClientGameState.fromMap(data, 'uid-2', []);

      expect(state.currentTrickPlays, isEmpty);
    });

    test('handles null optional fields', () {
      final data = _baseGameData(
        currentPlayerUid: null,
        trumpSuit: null,
        currentBid: null,
        bidderUid: null,
        currentTrick: null,
      );
      final state = ClientGameState.fromMap(data, 'uid-1', []);

      expect(state.currentPlayerUid, isNull);
      expect(state.trumpSuit, isNull);
      expect(state.currentBid, isNull);
      expect(state.bidderUid, isNull);
    });

    test('isMyTurn returns true when currentPlayerUid matches myUid', () {
      final data = _baseGameData(currentPlayerUid: 'uid-2');
      final state = ClientGameState.fromMap(data, 'uid-2', []);

      expect(state.isMyTurn, isTrue);
    });

    test('isMyTurn returns false when currentPlayerUid does not match myUid', () {
      final data = _baseGameData(currentPlayerUid: 'uid-1');
      final state = ClientGameState.fromMap(data, 'uid-2', []);

      expect(state.isMyTurn, isFalse);
    });

    test('team helper methods work correctly', () {
      final data = _baseGameData();

      // uid-0 is seat 0 (even) => Team.a
      final stateA = ClientGameState.fromMap(data, 'uid-0', []);
      expect(stateA.mySeatIndex, 0);
      expect(stateA.myTeam, Team.a);

      // uid-1 is seat 1 (odd) => Team.b
      final stateB = ClientGameState.fromMap(data, 'uid-1', []);
      expect(stateB.mySeatIndex, 1);
      expect(stateB.myTeam, Team.b);

      // uid-2 is seat 2 (even) => Team.a
      final stateA2 = ClientGameState.fromMap(data, 'uid-2', []);
      expect(stateA2.mySeatIndex, 2);
      expect(stateA2.myTeam, Team.a);

      // uid-3 is seat 3 (odd) => Team.b
      final stateB2 = ClientGameState.fromMap(data, 'uid-3', []);
      expect(stateB2.mySeatIndex, 3);
      expect(stateB2.myTeam, Team.b);
    });

    test('parses kout bid correctly', () {
      final data = _baseGameData(currentBid: 8);
      final state = ClientGameState.fromMap(data, 'uid-0', []);

      expect(state.currentBid, BidAmount.kout);
      expect(state.currentBid!.isKout, isTrue);
    });

    test('parses all game phases', () {
      for (final phase in GamePhase.values) {
        final data = _baseGameData(phase: phase.name);
        final state = ClientGameState.fromMap(data, 'uid-0', []);
        expect(state.phase, phase);
      }
    });
  });
}
