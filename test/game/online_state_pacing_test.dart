import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/game/online_state_pacing.dart';
import 'package:koutbh/shared/constants/timing.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';

ClientGameState _playing({
  required List<({String playerUid, GameCard card})> trickPlays,
  required String currentPlayerUid,
}) {
  return ClientGameState(
    phase: GamePhase.playing,
    playerUids: const ['a', 'b', 'c', 'd'],
    scores: const {Team.a: 0, Team.b: 0},
    tricks: const {Team.a: 0, Team.b: 0},
    currentPlayerUid: currentPlayerUid,
    dealerUid: 'a',
    trumpSuit: Suit.spades,
    currentBid: BidAmount.fromValue(5)!,
    bidderUid: 'b',
    currentTrickPlays: trickPlays,
    myHand: const [],
    myUid: 'a',
  );
}

void main() {
  group('onlinePlayPacingDelay', () {
    final c = GameCard.decode('SA');

    test('null when leaving or entering non-playing phase', () {
      final playing = _playing(trickPlays: [], currentPlayerUid: 'a');
      final bidding = ClientGameState(
        phase: GamePhase.bidding,
        playerUids: const ['a', 'b', 'c', 'd'],
        scores: const {Team.a: 0, Team.b: 0},
        tricks: const {Team.a: 0, Team.b: 0},
        currentPlayerUid: 'a',
        dealerUid: 'a',
        trumpSuit: null,
        currentBid: null,
        bidderUid: null,
        currentTrickPlays: const [],
        myHand: const [],
        myUid: 'a',
      );
      expect(onlinePlayPacingDelay(playing, bidding), isNull);
      expect(onlinePlayPacingDelay(null, playing), isNull);
    });

    test('cardPlayDelay when trick grows by one card', () {
      final p1 = _playing(
        trickPlays: [(playerUid: 'a', card: c)],
        currentPlayerUid: 'b',
      );
      final p2 = _playing(
        trickPlays: [(playerUid: 'a', card: c), (playerUid: 'b', card: c)],
        currentPlayerUid: 'c',
      );
      expect(onlinePlayPacingDelay(p1, p2), GameTiming.cardPlayDelay);
    });

    test('trickResolutionDelay when trick clears from 4 to 0', () {
      final four = _playing(
        trickPlays: [
          (playerUid: 'a', card: c),
          (playerUid: 'b', card: c),
          (playerUid: 'c', card: c),
          (playerUid: 'd', card: c),
        ],
        currentPlayerUid: 'a',
      );
      final empty = _playing(trickPlays: [], currentPlayerUid: 'a');
      expect(onlinePlayPacingDelay(four, empty), GameTiming.trickResolutionDelay);
    });

    test('trickResolutionDelay when trick clears from 4 to 1 in one step', () {
      final four = _playing(
        trickPlays: [
          (playerUid: 'a', card: c),
          (playerUid: 'b', card: c),
          (playerUid: 'c', card: c),
          (playerUid: 'd', card: c),
        ],
        currentPlayerUid: 'a',
      );
      final one = _playing(
        trickPlays: [(playerUid: 'a', card: c)],
        currentPlayerUid: 'b',
      );
      expect(onlinePlayPacingDelay(four, one), GameTiming.trickResolutionDelay);
    });

    test('cardPlayDelay when trick goes from 0 to 1 in same phase', () {
      final zero = _playing(trickPlays: [], currentPlayerUid: 'a');
      final one = _playing(
        trickPlays: [(playerUid: 'a', card: c)],
        currentPlayerUid: 'b',
      );
      expect(onlinePlayPacingDelay(zero, one), GameTiming.cardPlayDelay);
    });
  });
}
