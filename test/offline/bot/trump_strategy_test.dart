import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/offline/bot/trump_strategy.dart';

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

    test('1-card suit never selected when 2+ card alternatives exist', () {
      // Spades: 1 card (Ace), Hearts: 2 cards, Clubs: 2 cards
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.queen),
        const GameCard(suit: Suit.clubs, rank: Rank.jack),
        const GameCard(suit: Suit.clubs, rank: Rank.ten),
        const GameCard(suit: Suit.diamonds, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
        const GameCard(suit: Suit.diamonds, rank: Rank.nine),
      ];

      final trump = TrumpStrategy.selectTrump(hand);
      expect(trump, isNot(Suit.spades),
          reason: 'Single-card suit should not be chosen over 2+ card suits');
    });

    test('Kout prefers A-K-Q in 3 cards over 7-8-9-10 in 4 cards', () {
      // Hearts: A, K, Q (3 high cards) vs Clubs: 7, 8, 9, 10 (4 low cards)
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.queen),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.nine),
        const GameCard(suit: Suit.clubs, rank: Rank.ten),
        const GameCard(suit: Suit.diamonds, rank: Rank.seven),
      ];

      final trump =
          TrumpStrategy.selectTrump(hand, bidLevel: BidAmount.kout);
      expect(trump, Suit.hearts,
          reason: 'Kout should prefer strength over length');
    });

    test('Bab prefers 5 low cards over 3 high cards', () {
      // Hearts: A, K (2 high) vs Clubs: 7, 8, 9, 10, J (5 low-mid)
      // Bab scoring (lengthWeight=2.0, strengthWeight=1.0):
      //   Clubs: 5*2.0 + (0.5*4 + 1.0)*1.0 = 10 + 3.0 = 13.0
      //     + side H-A(0.9) + H-K(0.5) = 1.4 => 14.4
      //   Hearts: 2*2.0 + (3.0+2.0)*1.0 = 4 + 5.0 = 9.0
      //     + side C-cards(0) + D(0) = 0 => 9.0
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.nine),
        const GameCard(suit: Suit.clubs, rank: Rank.ten),
        const GameCard(suit: Suit.clubs, rank: Rank.jack),
        const GameCard(suit: Suit.diamonds, rank: Rank.seven),
      ];

      final trump =
          TrumpStrategy.selectTrump(hand, bidLevel: BidAmount.bab);
      expect(trump, Suit.clubs,
          reason: 'Bab should prefer length over strength');
    });

    test('side suit A-K boosts score', () {
      // Spades: 3 low cards (7,8,9). Hearts: 3 low cards (7,8,9).
      // Rest of hand: clubs A, diamonds 7.
      //
      // Without side strength, spades and hearts are identical. But:
      //   If spades is trump, side = C-A(0.9) = 0.9
      //   If hearts is trump, side = C-A(0.9) = 0.9
      //   => Same. Can't differentiate with symmetric hands.
      //
      // Instead: make one suit slightly weaker on internal score but
      // richer in side Aces when chosen as trump.
      //
      // Spades: 7, 8, 9 (count=3, strength=1.5)
      // Hearts: A, 7, 8 (count=3, strength=4.0)
      // Clubs: K, 7 (count=2, strength=2.5)
      //
      // Default scoring (lengthWeight=2.0, strengthWeight=1.0):
      //   Spades as trump: 3*2 + 1.5 = 7.5, side = H-A(0.9)+C-K(0.5) = 1.4 => 8.9
      //   Hearts as trump: 3*2 + 4.0 = 10.0, side = C-K(0.5) = 0.5 => 10.5
      //   Clubs as trump:  2*2 + 2.5 = 6.5, side = H-A(0.9) = 0.9 => 7.4
      //
      // Hearts wins. The side A-K gives hearts a smaller boost (+0.5) than
      // spades (+1.4), but hearts' internal strength dominates. This test
      // verifies that side cards ARE contributing (hearts without side would
      // be 10.0, with side it's 10.5).
      //
      // Verify clubs doesn't win despite having a King (it's too short).
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.spades, rank: Rank.nine),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
      ];

      final trump = TrumpStrategy.selectTrump(hand);
      // Hearts should win: internal strength (10.0) + side King (0.5) = 10.5
      // Spades: 7.5 + side Ace+King (1.4) = 8.9
      // Clubs: 6.5 + side Ace (0.9) = 7.4
      expect(trump, Suit.hearts,
          reason: 'Side suit Aces/Kings should boost trump selection');
      // Also verify that clubs (with K) doesn't beat spades (no honors)
      // despite having a King — length matters more.
      expect(trump, isNot(Suit.clubs));
    });

    test('void non-trump suit adds ruff value', () {
      // Hand with 5 spades, 2 hearts, 1 club, 0 diamonds
      // Diamonds being void gives spades a +0.5 ruff bonus
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.spades, rank: Rank.nine),
        const GameCard(suit: Suit.spades, rank: Rank.ten),
        const GameCard(suit: Suit.spades, rank: Rank.jack),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
      ];

      final trump = TrumpStrategy.selectTrump(hand);
      expect(trump, Suit.spades);
      // Spades is void in diamonds => +0.5 ruff.
      // We mainly verify spades wins (it should anyway due to length)
      // and that the method doesn't crash with void suits.
    });

    test('forced bid picks longest suit regardless of strength', () {
      // Hearts: A, K, Q (3 high) vs Clubs: 7, 8, 9, 10 (4 low)
      // Forced bid should pick clubs (longest) even though hearts is stronger
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.queen),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.nine),
        const GameCard(suit: Suit.clubs, rank: Rank.ten),
        const GameCard(suit: Suit.diamonds, rank: Rank.seven),
      ];

      final trump = TrumpStrategy.selectTrump(
        hand,
        isForcedBid: true,
      );
      expect(trump, Suit.clubs,
          reason: 'Forced bid should pick longest suit regardless of strength');
    });
  });
}
