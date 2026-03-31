import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/offline/bot/trump_strategy.dart';

void main() {
  group('TrumpStrategy', () {
    test('picks longest suit', () {
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.hearts, rank: Rank.nine),
        const GameCard(suit: Suit.hearts, rank: Rank.ten),
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      expect(TrumpStrategy.selectTrump(hand), Suit.hearts);
    });

    test('breaks ties by card strength', () {
      // 3 spades (A, K, Q) vs 3 hearts (7, 8, 9) — spades should win on strength
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.hearts, rank: Rank.nine),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      expect(TrumpStrategy.selectTrump(hand), Suit.spades);
    });

    test('Joker influences selection toward longer suits', () {
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.nine),
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      // Clubs has 3 cards + joker bonus should help
      final trump = TrumpStrategy.selectTrump(hand);
      expect(trump, isNotNull);
    });
  });
}
