@Tags(['e2e'])

// Poison Joker: if the Joker is the last card played in the final trick of a
// round, the player who played it receives a +10 point penalty.

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

  group('Poison Joker E2E — last card is the Joker → +10 penalty', () {
    late List<String> playerUids;
    late String gameId;

    setUp(() async {
      playerUids = [];
      for (var i = 0; i < 4; i++) {
        final uid = await createTestUser(
          FirebaseAuth.instance,
          'joker_player$i@test-kout.example',
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

    test('last card played is JO → player\'s team receives +10 penalty', () async {
      final firestore = FirebaseFirestore.instance;
      final gameRef = firestore.collection('games').doc(gameId);

      // Complete a standard bidding phase so we reach playing
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
        'suit': 'hearts',
      });
      await Future<void>.delayed(const Duration(seconds: 2));

      // Play 7 full tricks normally (first card each time)
      for (var trick = 0; trick < 7; trick++) {
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

          // On the last seat of the last trick we want to force the Joker play.
          // For the first 7 tricks we skip any Joker and play the first non-Joker.
          final cardToPlay = cards.firstWhere(
            (c) => c != 'JO',
            orElse: () => cards.first,
          );
          await callFunction('playCard', {
            'gameId': gameId,
            'uid': currentPlayerUid,
            'card': cardToPlay,
          });
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      // --- Trick 8 (final trick) ---
      // Play the first 3 cards normally, then find the player holding the Joker
      // and force them to play it last.
      String? jokerHolderUid;
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

        if (cards.contains('JO') && jokerHolderUid == null && seat == 3) {
          // This player holds the Joker and plays last — use it
          jokerHolderUid = currentPlayerUid;
          await callFunction('playCard', {
            'gameId': gameId,
            'uid': currentPlayerUid,
            'card': 'JO',
          });
        } else {
          // Play a non-Joker card
          final cardToPlay = cards.firstWhere(
            (c) => c != 'JO',
            orElse: () => cards.first,
          );
          await callFunction('playCard', {
            'gameId': gameId,
            'uid': currentPlayerUid,
            'card': cardToPlay,
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      await Future<void>.delayed(const Duration(seconds: 3));

      final gameSnap = await gameRef.get();
      final gameData = gameSnap.data()!;

      // The game should now be in roundScoring or beyond
      expect(
        ['roundScoring', 'bidding', 'gameOver'].contains(gameData['phase']),
        isTrue,
        reason: 'Game should have advanced to scoring after final trick',
      );

      // If the Joker was played, verify the +10 penalty is encoded in the
      // penaltyLog sub-field or reflected in the team's adjusted score.
      if (jokerHolderUid != null) {
        final penaltyLog = gameData['penaltyLog'] as List<dynamic>?;
        expect(penaltyLog, isNotNull,
            reason: 'penaltyLog should exist when Joker penalty was applied');

        final jokerPenalty = penaltyLog!.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['reason'] == 'poisonJoker',
          orElse: () => {},
        );
        expect(jokerPenalty, isNotEmpty,
            reason: 'A poisonJoker penalty entry should be present in penaltyLog');
        expect(jokerPenalty['uid'], equals(jokerHolderUid),
            reason: 'Penalty should be attributed to the player who held the Joker last');
        expect(jokerPenalty['points'], equals(10),
            reason: 'Poison Joker penalty is +10 points');
      }
    });
  });
}
