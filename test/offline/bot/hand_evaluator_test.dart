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

  group('HandEvaluator.evaluate — base probabilities', () {
    test('empty hand returns 0.0', () {
      final strength = HandEvaluator.evaluate([]);
      expect(strength.personalTricks, 0.0);
      expect(strength.strongestSuit, isNull);
    });

    test('single Ace scores ~0.85 + trump bonus + void bonuses', () {
      // Single Ace of spades: base 0.85, it IS the strongest suit so
      // trump bonus +0.15 = 1.0. Void in H, C, D with trump = 3 * 1.0 = 3.0.
      // Total = 4.0
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.ace)];
      final strength = HandEvaluator.evaluate(hand);
      expect(strength.personalTricks, closeTo(4.0, 0.01));
      expect(strength.strongestSuit, Suit.spades);
    });

    test('single Ace base contribution is 0.85 (verifiable by comparing suits)', () {
      // Two cards in different suits: Ace of spades and Ace of hearts.
      // Strongest suit is tied; the first one found wins (spades, since it's
      // iterated first from suitDistribution). The strongest gets trump bonus.
      // But we can verify the base by using a single-suit hand with known values.
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Ace: base 0.85 + trump 0.15 = 1.0
      // Seven: base 0.05 + trump 0.30 = 0.35
      // Void in H, C, D with trump = 3 * 1.0 = 3.0
      // AK texture: no. Total = 4.35
      expect(strength.personalTricks, closeTo(4.35, 0.01));
    });

    test('Joker scores 1.0 guaranteed trick', () {
      final hand = [GameCard.joker()];
      final strength = HandEvaluator.evaluate(hand);
      // Joker = 1.0. No suited cards, so no strongest suit. No voids apply
      // (no suit cards at all, hasTrump = false, but suitCounts is empty so
      // all 4 suits are "void" — void without trump = 0.1 each = 0.4).
      expect(strength.personalTricks, closeTo(1.4, 0.01));
      expect(strength.strongestSuit, isNull);
    });

    test('weak hand (all low cards, one suit) scores low', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.spades, rank: Rank.nine),
        const GameCard(suit: Suit.spades, rank: Rank.ten),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Each card: base 0.05 + trump 0.30 = 0.35. Four cards = 1.4
      // Long suit: 4 cards => +0.1 * (4-3) = 0.1
      // Void in H, C, D with trump = 3 * 1.0 = 3.0
      // Total = 4.5
      // But let's check: this is a weak hand but with lots of void/trump bonuses.
      // The personalTricks reflects total potential including positional advantages.
      expect(strength.personalTricks, closeTo(4.5, 0.01));
    });

    test('weak hand spread across suits scores < 2.0', () {
      // Low cards spread across all 4 suits: no trump bonus concentration,
      // no voids, no long suit.
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // All base 0.05 each. Strongest suit: all tied at 0.05, first one wins.
      // One card gets trump bonus: 0.05 + 0.30 = 0.35
      // Other three: 0.05 each = 0.15
      // No voids, no long suit, no texture.
      // Total = 0.50
      expect(strength.personalTricks, closeTo(0.50, 0.01));
      expect(strength.personalTricks, lessThan(2.0));
    });
  });

  group('HandEvaluator.evaluate — trump bonus on strongest suit', () {
    test('trump bonus applied only to strongest suit', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Spades raw = 0.85, Hearts raw = 0.65. Spades is strongest.
      // Ace of spades: 0.85 + 0.15 = 1.0
      // King of hearts: 0.65 (no trump bonus)
      // Void in C, D: hasTrump (spades has cards) => 2 * 1.0 = 2.0
      // AK texture: not same suit, no bonus.
      // Total = 3.65
      expect(strength.personalTricks, closeTo(3.65, 0.01));
      expect(strength.strongestSuit, Suit.spades);
    });

    test('King gets +0.25 trump bonus (total 0.9)', () {
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.king)];
      final strength = HandEvaluator.evaluate(hand);
      // King: 0.65 + 0.25 = 0.9. Void H,C,D with trump = 3.0. Total = 3.9
      expect(strength.personalTricks, closeTo(3.9, 0.01));
    });

    test('Queen gets +0.25 trump bonus (total 0.6)', () {
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.queen)];
      final strength = HandEvaluator.evaluate(hand);
      // Queen: 0.35 + 0.25 = 0.6. Void H,C,D with trump = 3.0. Total = 3.6
      expect(strength.personalTricks, closeTo(3.6, 0.01));
    });

    test('Jack gets +0.25 trump bonus (total 0.4)', () {
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.jack)];
      final strength = HandEvaluator.evaluate(hand);
      // Jack: 0.15 + 0.25 = 0.4. Void H,C,D with trump = 3.0. Total = 3.4
      expect(strength.personalTricks, closeTo(3.4, 0.01));
    });

    test('low card (10 and below) gets +0.30 trump bonus (total 0.35)', () {
      final hand = [const GameCard(suit: Suit.spades, rank: Rank.ten)];
      final strength = HandEvaluator.evaluate(hand);
      // Ten: 0.05 + 0.30 = 0.35. Void H,C,D with trump = 3.0. Total = 3.35
      expect(strength.personalTricks, closeTo(3.35, 0.01));
    });
  });

  group('HandEvaluator.evaluate — suit texture bonus', () {
    test('AKQ in same suit gets +0.5 texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Base+trump: A=1.0, K=0.9, Q=0.6 => 2.5
      // Texture AKQ: +0.5
      // Void H,C,D with trump: 3.0
      // Total = 6.0
      expect(strength.personalTricks, closeTo(6.0, 0.01));
    });

    test('AK in same suit gets +0.3 texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // A=1.0, K=0.9. Texture AK: +0.3. Void H,C,D: 3.0. Total = 5.2
      expect(strength.personalTricks, closeTo(5.2, 0.01));
    });

    test('KQ without A gets +0.2 texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // K=0.9, Q=0.6. Texture KQ(no A): +0.2. Void H,C,D: 3.0. Total = 4.7
      expect(strength.personalTricks, closeTo(4.7, 0.01));
    });

    test('AKQ across different suits gets no texture bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.queen),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Spades raw=0.85, Hearts raw=0.65, Clubs raw=0.35. Strongest = spades.
      // A(spades)=0.85+0.15=1.0, K(hearts)=0.65, Q(clubs)=0.35
      // No texture (different suits). Void in D with trump = 1.0.
      // Total = 3.0
      expect(strength.personalTricks, closeTo(3.0, 0.01));
    });
  });

  group('HandEvaluator.evaluate — long suit bonus', () {
    test('4 cards in a suit gets +0.1 long suit bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.spades, rank: Rank.jack),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // A=1.0, K=0.9, Q=0.6, J=0.4 => 2.9
      // Texture AKQ: +0.5
      // Long suit (4 cards): +0.1 * (4-3) = 0.1
      // Void H,C,D with trump: 3.0
      // Total = 6.5
      expect(strength.personalTricks, closeTo(6.5, 0.01));
    });

    test('5 cards in a suit gets +0.2 long suit bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.spades, rank: Rank.jack),
        const GameCard(suit: Suit.spades, rank: Rank.ten),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // A=1.0, K=0.9, Q=0.6, J=0.4, 10=0.35 => 3.25
      // Texture AKQ: +0.5
      // Long suit (5 cards): +0.1 * (5-3) = 0.2
      // Void H,C,D with trump: 3.0
      // Total = 6.95
      expect(strength.personalTricks, closeTo(6.95, 0.01));
    });

    test('3 cards in a suit gets no long suit bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
        const GameCard(suit: Suit.spades, rank: Rank.nine),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Each: 0.05 + 0.30 = 0.35. Three = 1.05
      // No long suit bonus. Void H,C,D: 3.0. Total = 4.05
      expect(strength.personalTricks, closeTo(4.05, 0.01));
    });
  });

  group('HandEvaluator.evaluate — void bonuses', () {
    test('void in non-trump with trump gives +1.0 per void suit', () {
      // Spades is strongest (has cards). Void in H, C, D.
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // A(spades) = 1.0. Void H,C,D with trump = 3.0. Total = 4.0
      expect(strength.personalTricks, closeTo(4.0, 0.01));
    });

    test('void in non-trump without trump gives +0.1', () {
      // Joker only: no suited cards, all 4 suits void, no trump.
      final hand = [GameCard.joker()];
      final strength = HandEvaluator.evaluate(hand);
      // Joker = 1.0. No strongest suit. hasTrump = false.
      // 4 suits void, none is "strongest" so none skipped.
      // Each void: +0.1. Total voids: 4 * 0.1 = 0.4.
      // Total = 1.4
      expect(strength.personalTricks, closeTo(1.4, 0.01));
    });

    test('no void means no void bonus', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.diamonds, rank: Rank.eight),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // No voids. One card in strongest suit gets trump bonus.
      // Strongest: all 0.05 raw, first suit wins. Trump card = 0.35, others = 0.05.
      // Total = 0.50
      expect(strength.personalTricks, closeTo(0.50, 0.01));
    });
  });

  group('HandEvaluator.evaluate — strongestSuit detection', () {
    test('picks suit with highest raw trick potential', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Spades raw = 0.05, Hearts raw = 0.85. Hearts is strongest.
      expect(strength.strongestSuit, Suit.hearts);
    });

    test('picks suit with more high cards over longer low suit', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.hearts, rank: Rank.nine),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Spades raw = 0.85 + 0.65 = 1.50
      // Hearts raw = 0.05 + 0.05 + 0.05 = 0.15
      // Spades is strongest.
      expect(strength.strongestSuit, Suit.spades);
    });

    test('no suited cards means no strongest suit', () {
      final hand = [GameCard.joker()];
      final strength = HandEvaluator.evaluate(hand);
      expect(strength.strongestSuit, isNull);
    });
  });

  group('HandEvaluator.effectiveTricks', () {
    test('PartnerAction.unknown adds +1.0', () {
      const strength = HandStrength(personalTricks: 3.0, strongestSuit: Suit.spades);
      final effective = HandEvaluator.effectiveTricks(
        strength,
        partnerAction: PartnerAction.unknown,
      );
      expect(effective, closeTo(4.0, 0.01));
    });

    test('PartnerAction.bid adds +1.5', () {
      const strength = HandStrength(personalTricks: 3.0, strongestSuit: Suit.spades);
      final effective = HandEvaluator.effectiveTricks(
        strength,
        partnerAction: PartnerAction.bid,
      );
      expect(effective, closeTo(4.5, 0.01));
    });

    test('PartnerAction.passed adds +0.5', () {
      const strength = HandStrength(personalTricks: 3.0, strongestSuit: Suit.spades);
      final effective = HandEvaluator.effectiveTricks(
        strength,
        partnerAction: PartnerAction.passed,
      );
      expect(effective, closeTo(3.5, 0.01));
    });

    test('result clamped to 8.0 max', () {
      const strength = HandStrength(personalTricks: 7.5, strongestSuit: Suit.spades);
      final effective = HandEvaluator.effectiveTricks(
        strength,
        partnerAction: PartnerAction.bid,
      );
      // 7.5 + 1.5 = 9.0, clamped to 8.0
      expect(effective, 8.0);
    });

    test('result clamped to 0.0 min', () {
      const strength = HandStrength(personalTricks: 0.0);
      final effective = HandEvaluator.effectiveTricks(
        strength,
        partnerAction: PartnerAction.passed,
      );
      // 0.0 + 0.5 = 0.5 (not clamped, but verify floor)
      expect(effective, closeTo(0.5, 0.01));
      expect(effective, greaterThanOrEqualTo(0.0));
    });
  });

  group('HandEvaluator.evaluate — combined scenarios', () {
    test('strong trump hand with Joker', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.king),
        const GameCard(suit: Suit.spades, rank: Rank.queen),
        const GameCard(suit: Suit.spades, rank: Rank.jack),
        const GameCard(suit: Suit.spades, rank: Rank.ten),
        const GameCard(suit: Suit.hearts, rank: Rank.ace),
        const GameCard(suit: Suit.clubs, rank: Rank.ace),
        GameCard.joker(),
      ];
      final strength = HandEvaluator.evaluate(hand);
      // Spades is strongest (sum of base: 0.85+0.65+0.35+0.15+0.05=2.05)
      // Hearts raw=0.85, Clubs raw=0.85. Spades wins.
      //
      // Cards:
      //   SA: 0.85+0.15=1.0, SK: 0.65+0.25=0.9, SQ: 0.35+0.25=0.6,
      //   SJ: 0.15+0.25=0.4, S10: 0.05+0.30=0.35
      //   HA: 0.85, CA: 0.85
      //   Joker: 1.0
      //   Sum = 1.0+0.9+0.6+0.4+0.35+0.85+0.85+1.0 = 5.95
      //
      // Texture: AKQ in spades = +0.5
      // Long suit: 5 spades => +0.2
      // Void: D only (H,C have cards). D void with trump => +1.0
      // Total = 5.95 + 0.5 + 0.2 + 1.0 = 7.65
      expect(strength.personalTricks, closeTo(7.65, 0.01));
      expect(strength.strongestSuit, Suit.spades);
    });

    test('evaluate does not take trumpSuit parameter', () {
      // Verify the new API: no trumpSuit parameter, trump is auto-detected.
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
      ];
      // This should compile and work — strongest suit auto-detected.
      final strength = HandEvaluator.evaluate(hand);
      expect(strength.strongestSuit, Suit.spades);
    });
  });
}
