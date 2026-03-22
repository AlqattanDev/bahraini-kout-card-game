@Tags(['e2e'])

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

  tearDownAll(() async {
    // Clean up all test users and game documents created during this suite
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.delete();
  });

  group('Matchmaking E2E — 4 players queue to game creation', () {
    late List<String> playerUids;
    late String gameId;

    setUp(() async {
      playerUids = [];
      for (var i = 0; i < 4; i++) {
        final uid = await createTestUser(
          FirebaseAuth.instance,
          'player$i@test-kout.example',
        );
        playerUids.add(uid);
      }
    });

    tearDown(() async {
      // Remove test entries from queue and game document
      final firestore = FirebaseFirestore.instance;
      for (final uid in playerUids) {
        await firestore.collection('queue').doc(uid).delete();
      }
      if (gameId.isNotEmpty) {
        await firestore.collection('games').doc(gameId).delete();
      }
    });

    test('all 4 players join queue and a game is created', () async {
      // All 4 players call joinQueue
      for (final uid in playerUids) {
        await callFunction('joinQueue', {'uid': uid});
      }

      // Wait for the matchmaking Cloud Function trigger to fire
      // (triggered by the 4th queue entry)
      await Future<void>.delayed(const Duration(seconds: 5));

      final firestore = FirebaseFirestore.instance;

      // Verify queue is empty for all 4 UIDs
      for (final uid in playerUids) {
        final queueDoc = await firestore.collection('queue').doc(uid).get();
        expect(queueDoc.exists, isFalse,
            reason: 'Player $uid should have been removed from the queue');
      }

      // Find the game that was created — look for a game containing all 4 players
      final gamesQuery = await firestore
          .collection('games')
          .where('playerUids', arrayContains: playerUids.first)
          .limit(1)
          .get();

      expect(gamesQuery.docs, isNotEmpty,
          reason: 'A game document should have been created');

      final gameDoc = gamesQuery.docs.first;
      gameId = gameDoc.id;
      final gameData = gameDoc.data();

      // Verify all 4 players are in the game
      final gamePlayers = List<String>.from(gameData['playerUids'] as List);
      expect(gamePlayers.length, equals(4));
      for (final uid in playerUids) {
        expect(gamePlayers, contains(uid),
            reason: 'Player $uid should be in the game');
      }

      // Verify game phase is dealing or bidding (not waiting)
      final phase = gameData['phase'] as String;
      expect(
        ['dealing', 'bidding'].contains(phase),
        isTrue,
        reason: 'Game should have progressed past waiting phase, got: $phase',
      );

      // Verify each player has an 8-card hand in their private sub-collection
      for (final uid in gamePlayers) {
        final handDoc = await firestore
            .collection('games')
            .doc(gameId)
            .collection('hands')
            .doc(uid)
            .get();

        expect(handDoc.exists, isTrue,
            reason: 'Hand document should exist for player $uid');

        final cards = List<String>.from(handDoc.data()!['cards'] as List);
        expect(cards.length, equals(8),
            reason: 'Player $uid should have exactly 8 cards');
      }
    });
  });
}
