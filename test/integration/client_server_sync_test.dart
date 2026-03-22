// Client-server sync verification test.
//
// This test does NOT require Firebase emulators — it verifies that
// [ClientGameState.fromMap] correctly parses every field of a mock Firestore
// game document that matches the schema written by the Cloud Functions.
//
// Run with:  flutter test test/integration/client_server_sync_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/app/models/client_game_state.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/enums.dart';

// ---------------------------------------------------------------------------
// Mock Firestore document factories
// ---------------------------------------------------------------------------

/// A complete game document as written by the `dealCards` / `placeBid` /
/// `selectTrump` / `playCard` Cloud Functions.
Map<String, dynamic> _buildGameDocument({
  String phase = 'playing',
  String? currentPlayerUid,
  String dealerUid = 'uid-0',
  String? trumpSuit,
  int? currentBid,
  String? bidderUid,
  List<Map<String, dynamic>>? currentTrick,
  Map<String, int>? scores,
  Map<String, int>? tricks,
  List<String>? playerUids,
}) {
  return {
    'phase': phase,
    'playerUids': playerUids ?? ['uid-0', 'uid-1', 'uid-2', 'uid-3'],
    'dealerUid': dealerUid,
    'currentPlayerUid': currentPlayerUid,
    'trumpSuit': trumpSuit,
    'currentBid': currentBid,
    'bidderUid': bidderUid,
    'currentTrick': currentTrick,
    'scores': {
      'a': scores?['a'] ?? 0,
      'b': scores?['b'] ?? 0,
    },
    'tricks': {
      'a': tricks?['a'] ?? 0,
      'b': tricks?['b'] ?? 0,
    },
  };
}

/// An 8-card hand as stored in `games/{id}/hands/{uid}`.
List<String> _hand8 = ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'D10', 'C7'];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ClientGameState.fromMap — full Firestore schema coverage', () {
    // --- Phase parsing ---

    test('parses phase: bidding', () {
      final doc = _buildGameDocument(phase: 'bidding');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.phase, GamePhase.bidding);
    });

    test('parses phase: trumpSelection', () {
      final doc = _buildGameDocument(phase: 'trumpSelection');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.phase, GamePhase.trumpSelection);
    });

    test('parses phase: playing', () {
      final doc = _buildGameDocument(phase: 'playing');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.phase, GamePhase.playing);
    });

    test('parses phase: roundScoring', () {
      final doc = _buildGameDocument(phase: 'roundScoring');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.phase, GamePhase.roundScoring);
    });

    test('parses phase: gameOver', () {
      final doc = _buildGameDocument(phase: 'gameOver');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.phase, GamePhase.gameOver);
    });

    // --- playerUids & seat logic ---

    test('parses playerUids correctly', () {
      final doc = _buildGameDocument();
      final state = ClientGameState.fromMap(doc, 'uid-2', []);
      expect(state.playerUids, ['uid-0', 'uid-1', 'uid-2', 'uid-3']);
    });

    test('mySeatIndex reflects position in playerUids', () {
      final doc = _buildGameDocument();
      expect(ClientGameState.fromMap(doc, 'uid-0', []).mySeatIndex, 0);
      expect(ClientGameState.fromMap(doc, 'uid-1', []).mySeatIndex, 1);
      expect(ClientGameState.fromMap(doc, 'uid-2', []).mySeatIndex, 2);
      expect(ClientGameState.fromMap(doc, 'uid-3', []).mySeatIndex, 3);
    });

    test('myTeam is Team.a for seats 0 and 2', () {
      final doc = _buildGameDocument();
      expect(ClientGameState.fromMap(doc, 'uid-0', []).myTeam, Team.a);
      expect(ClientGameState.fromMap(doc, 'uid-2', []).myTeam, Team.a);
    });

    test('myTeam is Team.b for seats 1 and 3', () {
      final doc = _buildGameDocument();
      expect(ClientGameState.fromMap(doc, 'uid-1', []).myTeam, Team.b);
      expect(ClientGameState.fromMap(doc, 'uid-3', []).myTeam, Team.b);
    });

    // --- dealerUid ---

    test('parses dealerUid', () {
      final doc = _buildGameDocument(dealerUid: 'uid-3');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.dealerUid, 'uid-3');
    });

    // --- currentPlayerUid & isMyTurn ---

    test('isMyTurn is true when currentPlayerUid == myUid', () {
      final doc = _buildGameDocument(currentPlayerUid: 'uid-0');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.isMyTurn, isTrue);
    });

    test('isMyTurn is false when currentPlayerUid != myUid', () {
      final doc = _buildGameDocument(currentPlayerUid: 'uid-1');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.isMyTurn, isFalse);
    });

    test('isMyTurn is false when currentPlayerUid is null', () {
      final doc = _buildGameDocument(currentPlayerUid: null);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.isMyTurn, isFalse);
    });

    // --- Trump suit ---

    test('parses trumpSuit: spades', () {
      final doc = _buildGameDocument(trumpSuit: 'spades');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.trumpSuit, Suit.spades);
    });

    test('parses trumpSuit: hearts', () {
      final doc = _buildGameDocument(trumpSuit: 'hearts');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.trumpSuit, Suit.hearts);
    });

    test('parses trumpSuit: clubs', () {
      final doc = _buildGameDocument(trumpSuit: 'clubs');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.trumpSuit, Suit.clubs);
    });

    test('parses trumpSuit: diamonds', () {
      final doc = _buildGameDocument(trumpSuit: 'diamonds');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.trumpSuit, Suit.diamonds);
    });

    test('trumpSuit is null when not set', () {
      final doc = _buildGameDocument(trumpSuit: null);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.trumpSuit, isNull);
    });

    // --- Bid amount ---

    test('parses currentBid: 5 → BidAmount.bab', () {
      final doc = _buildGameDocument(currentBid: 5);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentBid, BidAmount.bab);
    });

    test('parses currentBid: 6 → BidAmount.six', () {
      final doc = _buildGameDocument(currentBid: 6);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentBid, BidAmount.six);
    });

    test('parses currentBid: 7 → BidAmount.seven', () {
      final doc = _buildGameDocument(currentBid: 7);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentBid, BidAmount.seven);
    });

    test('parses currentBid: 8 → BidAmount.kout', () {
      final doc = _buildGameDocument(currentBid: 8);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentBid, BidAmount.kout);
      expect(state.currentBid!.isKout, isTrue);
    });

    test('currentBid is null when not set', () {
      final doc = _buildGameDocument(currentBid: null);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentBid, isNull);
    });

    // --- bidderUid ---

    test('parses bidderUid', () {
      final doc = _buildGameDocument(bidderUid: 'uid-2');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.bidderUid, 'uid-2');
    });

    test('bidderUid is null when not set', () {
      final doc = _buildGameDocument(bidderUid: null);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.bidderUid, isNull);
    });

    // --- Scores ---

    test('parses scores for both teams', () {
      final doc = _buildGameDocument(scores: {'a': 12, 'b': 7});
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.scores[Team.a], 12);
      expect(state.scores[Team.b], 7);
    });

    test('scores default to 0', () {
      final doc = _buildGameDocument();
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.scores[Team.a], 0);
      expect(state.scores[Team.b], 0);
    });

    // Scores are stored as num in Firestore (could be int or double).
    test('parses scores stored as double (Firestore num)', () {
      final doc = _buildGameDocument();
      // Override with double values to simulate Firestore deserialization
      (doc['scores'] as Map<String, dynamic>)['a'] = 5.0;
      (doc['scores'] as Map<String, dynamic>)['b'] = 10.0;
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.scores[Team.a], 5);
      expect(state.scores[Team.b], 10);
    });

    // --- Tricks ---

    test('parses tricks taken by each team', () {
      final doc = _buildGameDocument(tricks: {'a': 5, 'b': 3});
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.tricks[Team.a], 5);
      expect(state.tricks[Team.b], 3);
    });

    test('tricks default to 0', () {
      final doc = _buildGameDocument();
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.tricks[Team.a], 0);
      expect(state.tricks[Team.b], 0);
    });

    // --- Current trick plays ---

    test('parses an empty currentTrick list', () {
      final doc = _buildGameDocument(currentTrick: []);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentTrickPlays, isEmpty);
    });

    test('currentTrickPlays is empty when currentTrick key is absent', () {
      final doc = _buildGameDocument();
      // Ensure the key is absent (not just null)
      doc.remove('currentTrick');
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentTrickPlays, isEmpty);
    });

    test('parses currentTrick with one play', () {
      final doc = _buildGameDocument(currentTrick: [
        {'playerUid': 'uid-1', 'card': 'SA'},
      ]);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentTrickPlays.length, 1);
      expect(state.currentTrickPlays.first.playerUid, 'uid-1');
      expect(state.currentTrickPlays.first.card.isJoker, isFalse);
      expect(state.currentTrickPlays.first.card.suit, Suit.spades);
      expect(state.currentTrickPlays.first.card.rank, Rank.ace);
    });

    test('parses currentTrick with 4 plays including a Joker', () {
      final doc = _buildGameDocument(currentTrick: [
        {'playerUid': 'uid-0', 'card': 'HA'},
        {'playerUid': 'uid-1', 'card': 'HK'},
        {'playerUid': 'uid-2', 'card': 'JO'},
        {'playerUid': 'uid-3', 'card': 'H7'},
      ]);
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.currentTrickPlays.length, 4);

      final jokerPlay = state.currentTrickPlays[2];
      expect(jokerPlay.playerUid, 'uid-2');
      expect(jokerPlay.card.isJoker, isTrue);
    });

    // --- My hand ---

    test('parses an empty hand', () {
      final doc = _buildGameDocument();
      final state = ClientGameState.fromMap(doc, 'uid-0', []);
      expect(state.myHand, isEmpty);
    });

    test('parses an 8-card hand', () {
      final doc = _buildGameDocument();
      final state = ClientGameState.fromMap(doc, 'uid-0', _hand8);
      expect(state.myHand.length, 8);
    });

    test('hand contains correct cards in order', () {
      final doc = _buildGameDocument();
      final state = ClientGameState.fromMap(doc, 'uid-0', _hand8);
      // SA → Ace of Spades
      expect(state.myHand[0].suit, Suit.spades);
      expect(state.myHand[0].rank, Rank.ace);
      // C7 → Seven of Clubs (last card)
      expect(state.myHand[7].suit, Suit.clubs);
      expect(state.myHand[7].rank, Rank.seven);
    });

    test('parses hand containing the Joker', () {
      final doc = _buildGameDocument();
      final handWithJoker = ['SA', 'JO', 'HK'];
      final state = ClientGameState.fromMap(doc, 'uid-0', handWithJoker);
      expect(state.myHand.length, 3);
      expect(state.myHand[1].isJoker, isTrue);
    });

    // --- Full document roundtrip ---

    test('complete game document maps all fields correctly', () {
      final doc = _buildGameDocument(
        phase: 'playing',
        currentPlayerUid: 'uid-2',
        dealerUid: 'uid-1',
        trumpSuit: 'diamonds',
        currentBid: 6,
        bidderUid: 'uid-2',
        currentTrick: [
          {'playerUid': 'uid-2', 'card': 'D10'},
          {'playerUid': 'uid-3', 'card': 'D9'},
        ],
        scores: {'a': 6, 'b': 0},
        tricks: {'a': 2, 'b': 1},
      );

      final state = ClientGameState.fromMap(
        doc,
        'uid-2',
        ['DA', 'DK', 'SQ', 'HJ', 'C10', 'S9', 'H8', 'C7'],
      );

      expect(state.phase, GamePhase.playing);
      expect(state.playerUids, ['uid-0', 'uid-1', 'uid-2', 'uid-3']);
      expect(state.myUid, 'uid-2');
      expect(state.mySeatIndex, 2);
      expect(state.myTeam, Team.a);
      expect(state.isMyTurn, isTrue);
      expect(state.dealerUid, 'uid-1');
      expect(state.trumpSuit, Suit.diamonds);
      expect(state.currentBid, BidAmount.six);
      expect(state.bidderUid, 'uid-2');
      expect(state.scores[Team.a], 6);
      expect(state.scores[Team.b], 0);
      expect(state.tricks[Team.a], 2);
      expect(state.tricks[Team.b], 1);
      expect(state.currentTrickPlays.length, 2);
      expect(state.currentTrickPlays[0].card.rank, Rank.ten);
      expect(state.myHand.length, 8);
      expect(state.myHand.first.suit, Suit.diamonds);
      expect(state.myHand.first.rank, Rank.ace);
    });
  });
}
