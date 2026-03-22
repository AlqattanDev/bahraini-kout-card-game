@Tags(['e2e'])

// Disconnect handling tests:
//   1. Player disconnects during bidding → forfeited after 90 s
//   2. Player disconnects during play → forfeited with bid penalty
//   3. Player reconnects within 90 s → game continues normally

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await Firebase.initializeApp();
    await setupEmulators();
  });

  // Helper: spin up a fresh 4-player game and return [gameId, playerUids]
  Future<({String gameId, List<String> playerUids})> _createGame(
    String prefix,
  ) async {
    final playerUids = <String>[];
    for (var i = 0; i < 4; i++) {
      final uid = await createTestUser(
        FirebaseAuth.instance,
        '${prefix}_player$i@test-kout.example',
      );
      playerUids.add(uid);
    }
    for (final uid in playerUids) {
      await callFunction('joinQueue', {'uid': uid});
    }
    await Future<void>.delayed(const Duration(seconds: 5));

    final gamesQuery = await FirebaseFirestore.instance
        .collection('games')
        .where('playerUids', arrayContains: playerUids.first)
        .limit(1)
        .get();
    expect(gamesQuery.docs, isNotEmpty, reason: 'Game must have been created');
    return (gameId: gamesQuery.docs.first.id, playerUids: playerUids);
  }

  group('Disconnect — forfeit during bidding', () {
    late String gameId;
    late List<String> playerUids;

    setUp(() async {
      final result = await _createGame('disc_bid');
      gameId = result.gameId;
      playerUids = result.playerUids;
    });

    tearDown(() async {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('games').doc(gameId).delete();
      for (final uid in playerUids) {
        await firestore.collection('queue').doc(uid).delete();
      }
    });

    test('player disconnects during bidding — forfeited after 90 s timeout', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // Mark player 0 as disconnected via presence service
      await callFunction('setPresence', {
        'gameId': gameId,
        'uid': playerUids[0],
        'online': false,
      });

      // Simulate the server-side 90-second timeout via a test-only function
      // that accelerates the forfeit check (available in emulator test mode)
      await callFunction('triggerDisconnectCheck', {
        'gameId': gameId,
        'uid': playerUids[0],
      });

      await Future<void>.delayed(const Duration(seconds: 3));

      final gameSnap = await gameRef.get();
      final gameData = gameSnap.data()!;

      // Verify the game was forfeited for the disconnected player
      final forfeitUids = List<String>.from(
        (gameData['forfeitedUids'] as List? ?? []),
      );
      expect(forfeitUids, contains(playerUids[0]),
          reason: 'Disconnected player should be marked as forfeited');

      // Remaining 3 players' team should win by forfeit
      expect(
        ['roundScoring', 'gameOver'].contains(gameData['phase']),
        isTrue,
        reason: 'Game should resolve to scoring/over after a forfeit',
      );
    });
  });

  group('Disconnect — forfeit during play with bid penalty', () {
    late String gameId;
    late List<String> playerUids;

    setUp(() async {
      final result = await _createGame('disc_play');
      gameId = result.gameId;
      playerUids = result.playerUids;
    });

    tearDown(() async {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('games').doc(gameId).delete();
      for (final uid in playerUids) {
        await firestore.collection('queue').doc(uid).delete();
      }
    });

    test('bidder disconnects during play — bid penalty applied to their team', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // Player 0 wins the bid
      await callFunction('placeBid', {
        'gameId': gameId,
        'uid': playerUids[0],
        'bid': 5,
      });
      for (var i = 1; i < 4; i++) {
        await callFunction('placeBid', {
          'gameId': gameId,
          'uid': playerUids[i],
          'bid': 0,
        });
      }
      await Future<void>.delayed(const Duration(seconds: 2));

      await callFunction('selectTrump', {
        'gameId': gameId,
        'uid': playerUids[0],
        'suit': 'clubs',
      });
      await Future<void>.delayed(const Duration(seconds: 2));

      // Play 1 trick then disconnect the bidder
      final snap = await gameRef.get();
      final data = snap.data()!;
      final currentPlayerUid = data['currentPlayerUid'] as String;
      final handDoc = await gameRef
          .collection('hands')
          .doc(currentPlayerUid)
          .get();
      final cards = List<String>.from(handDoc.data()!['cards'] as List);
      await callFunction('playCard', {
        'gameId': gameId,
        'uid': currentPlayerUid,
        'card': cards.first,
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Now disconnect the bidder (player 0)
      await callFunction('setPresence', {
        'gameId': gameId,
        'uid': playerUids[0],
        'online': false,
      });
      await callFunction('triggerDisconnectCheck', {
        'gameId': gameId,
        'uid': playerUids[0],
      });

      await Future<void>.delayed(const Duration(seconds: 3));

      final gameSnap = await gameRef.get();
      final gameData = gameSnap.data()!;

      // Verify forfeit recorded
      final forfeitUids = List<String>.from(
        (gameData['forfeitedUids'] as List? ?? []),
      );
      expect(forfeitUids, contains(playerUids[0]));

      // The bid-loser penalty (failurePoints for bab = 10) should be charged
      // to Team A (seats 0 & 2, which include playerUids[0])
      final scores = gameData['scores'] as Map<String, dynamic>;
      // In penalty scoring the disconnecting team's score is reduced;
      // exact value depends on prior score but Team B's score should be higher.
      final teamAScore = (scores['a'] as num).toInt();
      final teamBScore = (scores['b'] as num).toInt();
      expect(teamBScore, greaterThanOrEqualTo(teamAScore),
          reason: 'Team B should benefit from Team A\'s bid forfeit');
    });
  });

  group('Disconnect — reconnect within 90 s continues game', () {
    late String gameId;
    late List<String> playerUids;

    setUp(() async {
      final result = await _createGame('disc_reconn');
      gameId = result.gameId;
      playerUids = result.playerUids;
    });

    tearDown(() async {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('games').doc(gameId).delete();
      for (final uid in playerUids) {
        await firestore.collection('queue').doc(uid).delete();
      }
    });

    test('player disconnects then reconnects within 90 s — game continues', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // Disconnect player 1
      await callFunction('setPresence', {
        'gameId': gameId,
        'uid': playerUids[1],
        'online': false,
      });

      // Wait a few seconds (well under 90 s)
      await Future<void>.delayed(const Duration(seconds: 3));

      // Player 1 reconnects
      await callFunction('setPresence', {
        'gameId': gameId,
        'uid': playerUids[1],
        'online': true,
      });

      // Verify game is still in bidding (not forfeited)
      final gameSnap = await gameRef.get();
      final gameData = gameSnap.data()!;

      expect(gameData['phase'], equals('bidding'),
          reason: 'Game should still be in bidding phase after a brief disconnect');

      final forfeitUids = List<String>.from(
        (gameData['forfeitedUids'] as List? ?? []),
      );
      expect(forfeitUids, isNot(contains(playerUids[1])),
          reason: 'Player who reconnected in time should not be forfeited');

      // Game should be fully playable — all 4 players still present
      final gamePlayers = List<String>.from(gameData['playerUids'] as List);
      expect(gamePlayers.length, equals(4));
    });
  });
}
