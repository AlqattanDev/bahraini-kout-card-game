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

  group('ClientGameState.fromMap — Worker format', () {
    Map<String, dynamic> workerGameData({
      String phase = 'PLAYING',
      String? currentPlayer = 'uid-0',
    }) {
      return {
        'phase': phase,
        'players': ['uid-0', 'uid-1', 'uid-2', 'uid-3'],
        'scores': {'teamA': 10, 'teamB': 0},
        'tricks': {'teamA': 4, 'teamB': 2},
        'currentPlayer': currentPlayer,
        'dealer': 'uid-3',
        'trumpSuit': 'hearts',
        'bid': {'player': 'uid-2', 'amount': 6},
        'currentTrick': {
          'lead': 'uid-0',
          'plays': [
            {'player': 'uid-0', 'card': 'HA'},
          ],
        },
        'bidHistory': [
          {'player': 'uid-3', 'action': 'pass'},
          {'player': 'uid-2', 'action': '6'},
          {'player': 'uid-1', 'action': 'pass'},
          {'player': 'uid-0', 'action': 'pass'},
        ],
        'trickWinners': ['teamA', 'teamB', 'teamA', 'teamA', 'teamA', 'teamB'],
        'passedPlayers': [3, 1, 0],
        'cardCounts': {'0': 5, '1': 5, '2': 5, '3': 5},
        'roundIndex': 2,
      };
    }

    test('parses UPPER_SNAKE phase names', () {
      for (final entry in <String, GamePhase>{
        'WAITING': GamePhase.waiting,
        'DEALING': GamePhase.dealing,
        'BIDDING': GamePhase.bidding,
        'TRUMP_SELECTION': GamePhase.trumpSelection,
        'BID_ANNOUNCEMENT': GamePhase.bidAnnouncement,
        'PLAYING': GamePhase.playing,
        'ROUND_SCORING': GamePhase.roundScoring,
        'GAME_OVER': GamePhase.gameOver,
      }.entries) {
        final data = workerGameData(phase: entry.key);
        final state = ClientGameState.fromMap(data, 'uid-0', []);
        expect(state.phase, entry.value, reason: 'phase ${entry.key}');
      }
    });

    test('parses "players" key (not "playerUids")', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.playerUids, ['uid-0', 'uid-1', 'uid-2', 'uid-3']);
    });

    test('parses teamA/teamB score keys', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.scores[Team.a], 10);
      expect(state.scores[Team.b], 0);
    });

    test('parses teamA/teamB trick keys', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.tricks[Team.a], 4);
      expect(state.tricks[Team.b], 2);
    });

    test('parses "currentPlayer" key (not "currentPlayerUid")', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.currentPlayerUid, 'uid-0');
    });

    test('parses "dealer" key (not "dealerUid")', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.dealerUid, 'uid-3');
    });

    test('parses structured bid {player, amount}', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.bidderUid, 'uid-2');
      expect(state.currentBid, BidAmount.six);
    });

    test('parses Worker trick format {lead, plays: [{player, card}]}', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.currentTrickPlays.length, 1);
      expect(state.currentTrickPlays[0].playerUid, 'uid-0');
      expect(
        state.currentTrickPlays[0].card,
        GameCard(suit: Suit.hearts, rank: Rank.ace),
      );
    });

    test('parses bidHistory', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.bidHistory.length, 4);
      expect(state.bidHistory[0].playerUid, 'uid-3');
      expect(state.bidHistory[0].action, 'pass');
      expect(state.bidHistory[1].playerUid, 'uid-2');
      expect(state.bidHistory[1].action, '6');
    });

    test('parses trickWinners', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.trickWinners.length, 6);
      expect(state.trickWinners[0], Team.a);
      expect(state.trickWinners[1], Team.b);
    });

    test('parses passedPlayers', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.passedPlayers, [3, 1, 0]);
    });

    test('parses cardCounts from string-keyed map', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.cardCounts[0], 5);
      expect(state.cardCounts[1], 5);
      expect(state.cardCounts[2], 5);
      expect(state.cardCounts[3], 5);
    });

    test('parses roundIndex', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.roundIndex, 2);
    });

    test('tugScore and leadingTeam computed correctly', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      expect(state.tugScore, 10);
      expect(state.leadingTeam, Team.a);
    });

    test('bidderTeam resolved from structured bid', () {
      final state = ClientGameState.fromMap(workerGameData(), 'uid-0', []);
      // uid-2 is seat 2 (even) → Team.a
      expect(state.bidderTeam, Team.a);
    });
  });
}
