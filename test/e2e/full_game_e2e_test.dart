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

  group('Full Game E2E — matchmaking through scoring', () {
    late List<String> playerUids;
    late String gameId;

    setUp(() async {
      playerUids = [];
      for (var i = 0; i < 4; i++) {
        final uid = await createTestUser(
          FirebaseAuth.instance,
          'fullgame_player$i@test-kout.example',
        );
        playerUids.add(uid);
      }

      // Create a game via matchmaking
      for (final uid in playerUids) {
        await callFunction('joinQueue', {'uid': uid});
      }
      await Future<void>.delayed(const Duration(seconds: 5));

      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('playerUids', arrayContains: playerUids.first)
          .limit(1)
          .get();

      expect(gamesQuery.docs, isNotEmpty, reason: 'Game should have been created');
      gameId = gamesQuery.docs.first.id;
    });

    tearDown(() async {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('games').doc(gameId).delete();
      for (final uid in playerUids) {
        await firestore.collection('queue').doc(uid).delete();
      }
    });

    test('complete game flow: bidding → trump selection → 8 tricks → round scored', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // --- Phase: Bidding ---
      // Player 0 (seat 0, Team A) bids 5 (bab); players 1, 2, 3 pass
      await callFunction('placeBid', {
        'gameId': gameId,
        'uid': playerUids[0],
        'bid': 5,
      });
      for (var i = 1; i < 4; i++) {
        await callFunction('placeBid', {
          'gameId': gameId,
          'uid': playerUids[i],
          'bid': 0, // 0 = pass
        });
      }

      await Future<void>.delayed(const Duration(seconds: 2));

      var gameSnap = await gameRef.get();
      var gameData = gameSnap.data()!;
      expect(gameData['phase'], equals('trumpSelection'),
          reason: 'Game should advance to trumpSelection after all bids');
      expect(gameData['bidderUid'], equals(playerUids[0]));
      expect(gameData['currentBid'], equals(5));

      // --- Phase: Trump Selection ---
      // The winning bidder selects trump suit
      await callFunction('selectTrump', {
        'gameId': gameId,
        'uid': playerUids[0],
        'suit': 'spades',
      });

      await Future<void>.delayed(const Duration(seconds: 2));

      gameSnap = await gameRef.get();
      gameData = gameSnap.data()!;
      expect(gameData['phase'], equals('playing'),
          reason: 'Game should be in playing phase after trump selected');
      expect(gameData['trumpSuit'], equals('spades'));

      // --- Phase: Playing — 8 tricks ---
      // Each trick: current player leads with first legal card from their hand
      for (var trick = 0; trick < 8; trick++) {
        for (var seat = 0; seat < 4; seat++) {
          // Fetch game state to find current player
          final snap = await gameRef.get();
          final data = snap.data()!;

          if (data['phase'] != 'playing') break;

          final currentPlayerUid = data['currentPlayerUid'] as String;

          // Fetch that player's hand
          final handDoc = await gameRef
              .collection('hands')
              .doc(currentPlayerUid)
              .get();
          final cards = List<String>.from(handDoc.data()!['cards'] as List);
          expect(cards, isNotEmpty, reason: 'Player should have cards left');

          // Play the first card in hand
          await callFunction('playCard', {
            'gameId': gameId,
            'uid': currentPlayerUid,
            'card': cards.first,
          });

          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        // After 4 plays check we haven't errored
        final snap = await gameRef.get();
        final phase = snap.data()!['phase'] as String;
        if (phase == 'roundScoring' || phase == 'gameOver') break;
      }

      // --- Phase: Round Scoring ---
      await Future<void>.delayed(const Duration(seconds: 2));

      gameSnap = await gameRef.get();
      gameData = gameSnap.data()!;

      expect(
        ['roundScoring', 'bidding', 'gameOver'].contains(gameData['phase']),
        isTrue,
        reason: 'Game should be in roundScoring, bidding, or gameOver after 8 tricks',
      );

      // Verify scores were updated (at least one team has non-zero score)
      final scores = gameData['scores'] as Map<String, dynamic>;
      final totalScore = (scores['a'] as num).toInt() + (scores['b'] as num).toInt();
      expect(totalScore, greaterThan(0),
          reason: 'At least one team should have points after a round');
    });
  });
}
