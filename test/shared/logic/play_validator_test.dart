import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/logic/play_validator.dart';

void main() {
  group('PlayValidator.validatePlay', () {
    test('allows playing a card of the led suit', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.hearts, rank: Rank.ace), hand: hand, ledSuit: Suit.hearts, isLeadPlay: false);
      expect(result.isValid, true);
    });

    test('rejects off-suit when player has led suit', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.spades, rank: Rank.king), hand: hand, ledSuit: Suit.hearts, isLeadPlay: false);
      expect(result.isValid, false);
      expect(result.error, 'must-follow-suit');
    });

    test('allows off-suit when void in led suit', () {
      final hand = [GameCard(suit: Suit.spades, rank: Rank.king), GameCard(suit: Suit.clubs, rank: Rank.queen)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.spades, rank: Rank.king), hand: hand, ledSuit: Suit.hearts, isLeadPlay: false);
      expect(result.isValid, true);
    });

    test('allows joker when void in led suit', () {
      final hand = [GameCard.joker(), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(card: GameCard.joker(), hand: hand, ledSuit: Suit.hearts, isLeadPlay: false);
      expect(result.isValid, true);
    });

    test('allows joker even when player has led suit', () {
      final hand = [GameCard.joker(), GameCard(suit: Suit.hearts, rank: Rank.seven)];
      final result = PlayValidator.validatePlay(card: GameCard.joker(), hand: hand, ledSuit: Suit.hearts, isLeadPlay: false);
      expect(result.isValid, true);
    });

    test('rejects leading with joker', () {
      final hand = [GameCard.joker(), GameCard(suit: Suit.hearts, rank: Rank.ace)];
      final result = PlayValidator.validatePlay(card: GameCard.joker(), hand: hand, ledSuit: null, isLeadPlay: true);
      expect(result.isValid, false);
      expect(result.error, 'joker-cannot-lead');
    });

    test('allows leading with any non-joker card', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.hearts, rank: Rank.ace), hand: hand, ledSuit: null, isLeadPlay: true);
      expect(result.isValid, true);
    });

    test('kout lead: rejects non-trump when player has trump', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(
        card: GameCard(suit: Suit.spades, rank: Rank.king),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
        trumpSuit: Suit.hearts,
        isKout: true,
        isFirstTrick: true,
      );
      expect(result.isValid, false);
      expect(result.error, 'must-lead-trump');
    });

    test('kout lead: allows trump card', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(
        card: GameCard(suit: Suit.hearts, rank: Rank.ace),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
        trumpSuit: Suit.hearts,
        isKout: true,
        isFirstTrick: true,
      );
      expect(result.isValid, true);
    });

    test('kout lead: allows any card when void in trump', () {
      final hand = [GameCard(suit: Suit.spades, rank: Rank.king), GameCard(suit: Suit.clubs, rank: Rank.queen)];
      final result = PlayValidator.validatePlay(
        card: GameCard(suit: Suit.spades, rank: Rank.king),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
        trumpSuit: Suit.hearts,
        isKout: true,
        isFirstTrick: true,
      );
      expect(result.isValid, true);
    });

    test('kout lead: rejects joker even when holding trump', () {
      final hand = [GameCard.joker(), GameCard(suit: Suit.hearts, rank: Rank.ace)];
      final result = PlayValidator.validatePlay(
        card: GameCard.joker(),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
        trumpSuit: Suit.hearts,
        isKout: true,
        isFirstTrick: true,
      );
      expect(result.isValid, false);
      expect(result.error, 'joker-cannot-lead');
    });

    test('kout lead on non-first trick: allows any card', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(
        card: GameCard(suit: Suit.spades, rank: Rank.king),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
        trumpSuit: Suit.hearts,
        isKout: true,
        isFirstTrick: false,
      );
      expect(result.isValid, true);
    });

    test('non-kout lead: no trump restriction', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(
        card: GameCard(suit: Suit.spades, rank: Rank.king),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
        trumpSuit: Suit.hearts,
        isKout: false,
      );
      expect(result.isValid, true);
    });

    test('rejects card not in hand', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.spades, rank: Rank.king), hand: hand, ledSuit: null, isLeadPlay: true);
      expect(result.isValid, false);
      expect(result.error, 'card-not-in-hand');
    });
  });

  group('PlayValidator.playableForCurrentTrick — Joker leading', () {
    test('joker excluded from playable cards when leading', () {
      final hand = [
        GameCard.joker(),
        GameCard(suit: Suit.hearts, rank: Rank.ace),
        GameCard(suit: Suit.spades, rank: Rank.king),
      ];
      final playable = PlayValidator.playableForCurrentTrick(
        hand: hand,
        trickHasNoPlaysYet: true,
        ledSuit: null,
        bidIsKout: false,
        noTricksCompletedYet: false,
      );
      expect(playable, isNot(contains(GameCard.joker())));
      expect(playable.length, 2);
    });

    test('joker allowed when following', () {
      final hand = [
        GameCard.joker(),
        GameCard(suit: Suit.hearts, rank: Rank.ace),
      ];
      final playable = PlayValidator.playableForCurrentTrick(
        hand: hand,
        trickHasNoPlaysYet: false,
        ledSuit: Suit.hearts,
        bidIsKout: false,
        noTricksCompletedYet: false,
      );
      expect(playable, contains(GameCard.joker()));
    });

    test('kout first trick: only trump playable, joker not an option for leading', () {
      final hand = [
        GameCard.joker(),
        GameCard(suit: Suit.hearts, rank: Rank.ace),
        GameCard(suit: Suit.spades, rank: Rank.king),
      ];
      final playable = PlayValidator.playableForCurrentTrick(
        hand: hand,
        trickHasNoPlaysYet: true,
        ledSuit: null,
        trumpSuit: Suit.hearts,
        bidIsKout: true,
        noTricksCompletedYet: true,
      );
      expect(playable, {GameCard(suit: Suit.hearts, rank: Rank.ace)});
    });

    test('only joker in hand when must lead returns empty playable set (poison joker)', () {
      final hand = [GameCard.joker()];
      final playable = PlayValidator.playableForCurrentTrick(
        hand: hand,
        trickHasNoPlaysYet: true,
        ledSuit: null,
        bidIsKout: false,
        noTricksCompletedYet: false,
      );
      expect(playable, isEmpty);
      expect(PlayValidator.detectPoisonJoker(hand), true);
    });
  });

  group('PlayValidator.detectPoisonJoker', () {
    test('detects poison joker when only card is joker', () {
      expect(PlayValidator.detectPoisonJoker([GameCard.joker()]), true);
    });

    test('no poison joker with multiple cards', () {
      expect(PlayValidator.detectPoisonJoker([GameCard.joker(), GameCard(suit: Suit.hearts, rank: Rank.ace)]), false);
    });

    test('no poison joker when single card is not joker', () {
      expect(PlayValidator.detectPoisonJoker([GameCard(suit: Suit.hearts, rank: Rank.ace)]), false);
    });

    test('no poison joker with empty hand', () {
      expect(PlayValidator.detectPoisonJoker([]), false);
    });
  });
}
