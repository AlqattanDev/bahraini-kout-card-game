import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/offline/bot/hand_evaluator.dart';

void main() {
  group('HandEvaluator', () {
    test('strong hand (3 aces + Joker) has high expectedWinners', () {
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.clubs, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      final strength = HandEvaluator.evaluate(hand);
      expect(strength.expectedWinners, greaterThanOrEqualTo(4.0));
    });

    test('weak hand (all 7s and 8s, no Joker) has low expectedWinners', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
        const GameCard(suit: Suit.diamonds, rank: Rank.nine),
      ];

      final strength = HandEvaluator.evaluate(hand);
      expect(strength.expectedWinners, lessThan(3.0));
    });

    test('void suit detection adds bonus', () {
      // Hand with no diamonds
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.ace),
        const GameCard(suit: Suit.clubs, rank: Rank.king),
        GameCard.joker(),
      ];

      final strength = HandEvaluator.evaluate(hand);
      // Void in diamonds should add 0.2 bonus
      expect(strength.expectedWinners, greaterThan(4.0));
    });

    test('identifies strongest suit', () {
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.queen),
        const GameCard(suit: Suit.hearts, rank: Rank.jack),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      final strength = HandEvaluator.evaluate(hand);
      expect(strength.strongestSuit, Suit.hearts);
    });

    test('trump bonus adds to score', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.spades, rank: Rank.nine),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      final withoutTrump = HandEvaluator.evaluate(hand);
      final withTrump = HandEvaluator.evaluate(hand, trumpSuit: Suit.spades);
      expect(withTrump.expectedWinners, greaterThan(withoutTrump.expectedWinners));
    });
  });
}
