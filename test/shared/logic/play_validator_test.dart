import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/logic/play_validator.dart';

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

    test('allows leading with joker (triggers round loss via game controller)', () {
      final hand = [GameCard.joker(), GameCard(suit: Suit.hearts, rank: Rank.ace)];
      final result = PlayValidator.validatePlay(card: GameCard.joker(), hand: hand, ledSuit: null, isLeadPlay: true);
      expect(result.isValid, true);
    });

    test('allows leading with any non-joker card', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace), GameCard(suit: Suit.spades, rank: Rank.king)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.hearts, rank: Rank.ace), hand: hand, ledSuit: null, isLeadPlay: true);
      expect(result.isValid, true);
    });

    test('rejects card not in hand', () {
      final hand = [GameCard(suit: Suit.hearts, rank: Rank.ace)];
      final result = PlayValidator.validatePlay(card: GameCard(suit: Suit.spades, rank: Rank.king), hand: hand, ledSuit: null, isLeadPlay: true);
      expect(result.isValid, false);
      expect(result.error, 'card-not-in-hand');
    });
  });

  group('PlayValidator.detectJokerLead', () {
    test('detects joker lead when joker is played as lead', () {
      expect(PlayValidator.detectJokerLead(GameCard.joker(), true), true);
    });

    test('no joker lead when joker is played as follow', () {
      expect(PlayValidator.detectJokerLead(GameCard.joker(), false), false);
    });

    test('no joker lead when non-joker is played as lead', () {
      expect(
        PlayValidator.detectJokerLead(
          GameCard(suit: Suit.hearts, rank: Rank.ace),
          true,
        ),
        false,
      );
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
