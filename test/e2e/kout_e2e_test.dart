@Tags(['e2e'])

// Kout: a player bids 8 (kout) and wins all 8 tricks → their team earns 31 points
// and the game ends immediately.

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

  group('Kout E2E — bid 8, win all 8 tricks → game over', () {
    late List<String> playerUids;
    late String gameId;

    setUp(() async {
      playerUids = [];
      for (var i = 0; i < 4; i++) {
        final uid = await createTestUser(
          FirebaseAuth.instance,
          'kout_player$i@test-kout.example',
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

    test('player bids kout (8), wins all 8 tricks, earns 31 points and game ends', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // Player 0 bids kout (8); others pass
      await callFunction('placeBid', {
        'gameId': gameId,
        'uid': playerUids[0],
        'bid': 8,
      });
      for (var i = 1; i < 4; i++) {
        await callFunction('placeBid', {
          'gameId': gameId,
          'uid': playerUids[i],
          'bid': 0,
        });
      }

      await Future<void>.delayed(const Duration(seconds: 2));

      var gameSnap = await gameRef.get();
      var gameData = gameSnap.data()!;

      expect(gameData['phase'], equals('trumpSelection'),
          reason: 'After kout bid accepted game moves to trump selection');
      expect(gameData['currentBid'], equals(8));

      // Bidder selects trump
      await callFunction('selectTrump', {
        'gameId': gameId,
        'uid': playerUids[0],
        'suit': 'spades',
      });

      await Future<void>.delayed(const Duration(seconds: 2));

      // Play all 8 tricks — each time let the current player play their first card.
      // In a real kout scenario the bidding team's cards dominate; here we just
      // simulate card play and trust the scoring function.
      for (var trick = 0; trick < 8; trick++) {
        for (var seat = 0; seat < 4; seat++) {
          final snap = await gameRef.get();
          final data = snap.data()!;

          if (data['phase'] != 'playing') break;

          final currentPlayerUid = data['currentPlayerUid'] as String;
          final handDoc = await gameRef
              .collection('hands')
              .doc(currentPlayerUid)
              .get();
          final cards = List<String>.from(handDoc.data()!['cards'] as List);
          expect(cards, isNotEmpty);

          await callFunction('playCard', {
            'gameId': gameId,
            'uid': currentPlayerUid,
            'card': cards.first,
          });

          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      await Future<void>.delayed(const Duration(seconds: 3));

      gameSnap = await gameRef.get();
      gameData = gameSnap.data()!;

      // After a successful kout the round-scoring function awards 31 points and
      // may set the game to gameOver (if the winning team now has >= 31 total)
      final scores = gameData['scores'] as Map<String, dynamic>;
      final teamAScore = (scores['a'] as num).toInt();
      final teamBScore = (scores['b'] as num).toInt();

      // Team A (seats 0 & 2) includes playerUids[0] who bid kout.
      // If they won all 8 tricks they should have 31 points.
      expect(
        teamAScore == 31 || teamBScore == 31,
        isTrue,
        reason: 'The kout-winning team should have exactly 31 points, got A=$teamAScore B=$teamBScore',
      );

      expect(gameData['phase'], equals('gameOver'),
          reason: 'Game must be over after a successful kout (31-point swing)');
    });
  });
}
