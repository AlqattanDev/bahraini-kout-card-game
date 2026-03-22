@Tags(['e2e'])

// Malzoom: all 4 players pass → server reshuffles → all pass again → forced bid
// The server must detect the double-pass and force the dealer to bid 5 (bab).

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

  group('Malzoom E2E — double pass forces a bid', () {
    late List<String> playerUids;
    late String gameId;

    setUp(() async {
      playerUids = [];
      for (var i = 0; i < 4; i++) {
        final uid = await createTestUser(
          FirebaseAuth.instance,
          'malzoom_player$i@test-kout.example',
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

    test('all 4 pass → reshuffle → all pass again → dealer is forced to bid 5', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // --- First pass round: all 4 players pass ---
      for (final uid in playerUids) {
        await callFunction('placeBid', {
          'gameId': gameId,
          'uid': uid,
          'bid': 0, // pass
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      await Future<void>.delayed(const Duration(seconds: 3));

      var gameSnap = await gameRef.get();
      var gameData = gameSnap.data()!;

      // After first all-pass the server should reshuffle and return to bidding
      expect(gameData['phase'], equals('bidding'),
          reason: 'After first all-pass, server reshuffles and restarts bidding');

      final passCount = (gameData['passCount'] as num?)?.toInt() ?? 0;
      expect(passCount, equals(1),
          reason: 'passCount should be 1 after the first all-pass round');

      // --- Second pass round: all 4 players pass again ---
      for (final uid in playerUids) {
        await callFunction('placeBid', {
          'gameId': gameId,
          'uid': uid,
          'bid': 0, // pass
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      await Future<void>.delayed(const Duration(seconds: 3));

      gameSnap = await gameRef.get();
      gameData = gameSnap.data()!;

      // After the second all-pass, the game must be in trumpSelection
      // with the dealer forced to bid bab (5)
      expect(gameData['phase'], equals('trumpSelection'),
          reason: 'After double all-pass (malzoom), game must advance to trump selection');

      expect(gameData['currentBid'], equals(5),
          reason: 'Forced bid must be bab (5)');

      // The forced bidder should be the dealer
      final dealerUid = gameData['dealerUid'] as String;
      expect(gameData['bidderUid'], equals(dealerUid),
          reason: 'Forced bid should be assigned to the dealer');
    });
  });
}
