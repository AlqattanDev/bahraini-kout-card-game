import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';

void main() {
  group('BidStrategy', () {
    test('strong hand bids appropriately', () {
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.clubs, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.king),
        const GameCard(suit: Suit.diamonds, rank: Rank.ace),
      ];

      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
    });

    test('weak hand passes', () {
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

      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<PassAction>());
    });

    test('respects current high bid (won\'t underbid)', () {
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

      // If current high bid is 7, bot should only bid if it can bid 8
      final action = BidStrategy.decideBid(hand, BidAmount.seven);
      if (action is BidAction) {
        expect(action.amount.value, greaterThan(BidAmount.seven.value));
      } else {
        expect(action, isA<PassAction>());
      }
    });

    test('first bid starts at bab (5) minimum', () {
      // Moderately strong hand
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.spades, rank: Rank.jack),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      final action = BidStrategy.decideBid(hand, null);
      if (action is BidAction) {
        expect(action.amount.value, greaterThanOrEqualTo(5));
      }
    });

    test('forced bid with strong hand bids higher than bab', () {
      // 4 aces + joker → evaluator scores ~5.8 → six bid
      final strongHand = [
        GameCard.joker(),
        GameCard(suit: Suit.spades, rank: Rank.ace),
        GameCard(suit: Suit.hearts, rank: Rank.ace),
        GameCard(suit: Suit.clubs, rank: Rank.ace),
        GameCard(suit: Suit.diamonds, rank: Rank.ace),
        GameCard(suit: Suit.spades, rank: Rank.king),
        GameCard(suit: Suit.hearts, rank: Rank.king),
        GameCard(suit: Suit.clubs, rank: Rank.king),
      ];
      final action = BidStrategy.decideBid(strongHand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThanOrEqualTo(6));
    });

    test('forced bid returns at least bab even with weak hand', () {
      final weakHand = [
        GameCard(suit: Suit.hearts, rank: Rank.seven),
        GameCard(suit: Suit.clubs, rank: Rank.eight),
        GameCard(suit: Suit.diamonds, rank: Rank.nine),
        GameCard(suit: Suit.spades, rank: Rank.seven),
        GameCard(suit: Suit.hearts, rank: Rank.eight),
        GameCard(suit: Suit.clubs, rank: Rank.seven),
        GameCard(suit: Suit.diamonds, rank: Rank.eight),
        GameCard(suit: Suit.spades, rank: Rank.nine),
      ];
      final action = BidStrategy.decideBid(weakHand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });

    test(
      'shape floor: 5-card suit bids Bab without strong evaluator score',
      () {
        final hand = [
          GameCard.decode('S7'),
          GameCard.decode('S8'),
          GameCard.decode('S9'),
          GameCard.decode('S10'),
          GameCard.decode('SJ'),
          GameCard.decode('H7'),
          GameCard.decode('C7'),
          GameCard.decode('D8'),
        ];
        expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.bab);
        final action = BidStrategy.decideBid(hand, null);
        expect(action, isA<BidAction>());
        expect((action as BidAction).amount, BidAmount.bab);
      },
    );

    test('shape floor: 7 spades + Joker implies Kout', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('S9'),
        GameCard.decode('S10'),
        GameCard.decode('SJ'),
        GameCard.decode('SQ'),
        GameCard.decode('SK'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.kout);
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.kout);
    });

    test('aggressive thresholding pushes very strong hand to at least seven', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('HA'),
        GameCard.decode('HK'),
      ];
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThanOrEqualTo(7));
    });

    test('forced bid uses shape floor when above Bab', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('S9'),
        GameCard.decode('S10'),
        GameCard.decode('SJ'),
        GameCard.decode('SQ'),
        GameCard.decode('SK'),
      ];
      final action = BidStrategy.decideBid(hand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.kout);
    });
  });
}
