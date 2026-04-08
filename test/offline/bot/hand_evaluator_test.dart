import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/offline/bot/hand_evaluator.dart';

void main() {
  group('HandEvaluator.suitDistribution', () {
    test('groups non-joker cards by suit', () {
      final hand = [
        GameCard.decode('SA'),
        GameCard.decode('S7'),
        GameCard.joker(),
      ];
      final d = HandEvaluator.suitDistribution(hand);
      expect(d[Suit.spades]?.length, 2);
      expect(d.length, 1);
    });
  });

  group('HandEvaluator — Phase 2 honor valuation', () {
    test('King in 2-card suit scores 0.6', () {
      // Build minimal hands to isolate King contribution.
      final handKing2 = [
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
      ];
      final handKing3 = [
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
      ];

      final score2 = HandEvaluator.evaluate(handKing2);
      final score3 = HandEvaluator.evaluate(handKing3);

      // 2-card suit: King = 0.6, Seven = 0. Voids in H/C/D = 3*0.1 = 0.3. Total = 0.9
      expect(score2.expectedWinners, closeTo(0.9, 0.01));
      // 3-card suit: King = 0.8, Seven = 0, Eight = 0. Voids = 3*0.1 = 0.3. Total = 1.1
      expect(score3.expectedWinners, closeTo(1.1, 0.01));
    });

    test('Queen in 3-card suit scores 0.5', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
      ];

      final strength = HandEvaluator.evaluate(hand);
      // Queen in 3-card = 0.5, Seven = 0, Eight = 0. Voids = 3*0.1 = 0.3. Total = 0.8
      expect(strength.expectedWinners, closeTo(0.8, 0.01));
    });

    test('Jack scores 0.2 (different from Ten at 0.1)', () {
      final handJack = [
        const GameCard(suit: Suit.spades, rank: Rank.jack),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
      ];
      final handTen = [
        const GameCard(suit: Suit.spades, rank: Rank.ten),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
      ];

      final jackScore = HandEvaluator.evaluate(handJack);
      final tenScore = HandEvaluator.evaluate(handTen);

      // Jack = 0.2 + voids(C,D)=0.2. Ten = 0.1 + voids(C,D)=0.2.
      expect(jackScore.expectedWinners, greaterThan(tenScore.expectedWinners));
      expect(
        jackScore.expectedWinners - tenScore.expectedWinners,
        closeTo(0.1, 0.01),
      );
    });
  });

  group('HandEvaluator — Phase 2 trump honor bonus', () {
    test('Trump Ace total = 0.9 + 0.5 = 1.4 contribution', () {
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.ace)];

      final withoutTrump = HandEvaluator.evaluate(hand);
      final withTrump = HandEvaluator.evaluate(hand, trumpSuit: Suit.spades);

      // Without trump: Ace = 0.9, voids(H,C,D) = 0.3. Total = 1.2
      // With trump: Ace = 0.9 + 0.5 = 1.4, voids(H,C,D) = 0.9. Total = 2.3
      // The difference in the ace contribution itself is 0.5 + void bonus change.
      // Let's verify with trump the ace contributes 1.4 to suitStrength.
      // Total with trump: 1.4 (ace) + 0.3*3 (void ruff for H,C,D) = 2.3
      expect(withTrump.expectedWinners, closeTo(2.3, 0.01));
      // Without trump: 0.9 (ace) + 0.1*3 (void, no trump) = 1.2
      expect(withoutTrump.expectedWinners, closeTo(1.2, 0.01));
    });

    test('Trump 7 total = 0.0 + 0.3 = 0.3 contribution', () {
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.seven)];

      final withoutTrump = HandEvaluator.evaluate(hand);
      final withTrump = HandEvaluator.evaluate(hand, trumpSuit: Suit.spades);

      // Without trump: Seven = 0, voids(H,C,D) = 0.3. Total = 0.3
      // With trump: Seven = 0 + 0.3 = 0.3, voids(H,C,D) = 0.9. Total = 1.2
      expect(withoutTrump.expectedWinners, closeTo(0.3, 0.01));
      expect(withTrump.expectedWinners, closeTo(1.2, 0.01));
      // The trump 7 itself contributes 0.3
      expect(
        withTrump.expectedWinners - withoutTrump.expectedWinners,
        closeTo(0.9, 0.01),
      );
    });
  });

  group('HandEvaluator — Phase 2 suit texture bonus', () {
    test('A-K same suit gets +0.3 texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
      ];

      final strength = HandEvaluator.evaluate(hand);
      // Ace = 0.9, King(2-card) = 0.6, texture(AK) = 0.3, voids(H,C,D) = 0.3. Total = 2.1
      expect(strength.expectedWinners, closeTo(2.1, 0.01));
    });

    test('A-K-Q same suit gets +0.5 texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
      ];

      final strength = HandEvaluator.evaluate(hand);
      // Ace = 0.9, King(3-card) = 0.8, Queen(3-card) = 0.5, texture(AKQ) = 0.5, voids = 0.3. Total = 3.0
      expect(strength.expectedWinners, closeTo(3.0, 0.01));
    });

    test('K-Q without Ace gets +0.2 texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
      ];

      final strength = HandEvaluator.evaluate(hand);
      // King(2-card) = 0.6, Queen(2-card) = 0.3, texture(KQ no A) = 0.2, voids = 0.3. Total = 1.4
      expect(strength.expectedWinners, closeTo(1.4, 0.01));
    });
  });

  group('HandEvaluator — Phase 2 void and ruffing potential', () {
    test('Void in trump suit = 0 bonus', () {
      // Hand has no spades, trump is spades
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];

      // Trump = spades, void in spades (trump) => 0 bonus for that void
      // No trump cards => hasAnyTrump = false
      // Void in spades(trump) = 0, no other voids
      final strength = HandEvaluator.evaluate(hand, trumpSuit: Suit.spades);
      // Cards: all zeroes. No voids except in trump suit (0 bonus). Total = 0.0
      expect(strength.expectedWinners, closeTo(0.0, 0.01));
    });

    test('Void in non-trump + has trump = 0.3 bonus', () {
      // Has spades (trump), void in diamonds
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
      ];

      final strength = HandEvaluator.evaluate(hand, trumpSuit: Suit.spades);
      // Cards: Seven of spades as trump = 0 + 0.3 = 0.3. Others = 0.
      // Void in diamonds (non-trump, has trump) = 0.3. Total = 0.6
      expect(strength.expectedWinners, closeTo(0.6, 0.01));
    });

    test('Void in non-trump + no trump = 0.1 bonus', () {
      // No spades (trump), void in diamonds
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
      ];

      final strength = HandEvaluator.evaluate(hand, trumpSuit: Suit.spades);
      // Cards: all zeroes. Void in spades(trump) = 0. Void in diamonds(non-trump, no trump) = 0.1.
      // Total = 0.1
      expect(strength.expectedWinners, closeTo(0.1, 0.01));
    });
  });
}
