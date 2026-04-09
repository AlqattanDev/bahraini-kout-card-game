import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';
import 'package:koutbh/offline/bot/hand_evaluator.dart';

/// Helper: effective tricks for a hand with a given partner action.
double _et(List<GameCard> hand, {PartnerAction pa = PartnerAction.unknown}) {
  final s = HandEvaluator.evaluate(hand);
  return HandEvaluator.effectiveTricks(s, partnerAction: pa);
}

void main() {
  // -----------------------------------------------------------------
  // 1. Strong hand bids appropriately
  // -----------------------------------------------------------------
  group('strong hand bids appropriately', () {
    test('3 Aces + Joker + Kings bids at least Bab', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CA'),
        GameCard.decode('SK'),
        GameCard.decode('HK'),
        GameCard.decode('CK'),
        GameCard.decode('DA'),
      ];
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
    });

    test('6-card suit + Joker + AKQ bids high', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('HA'),
      ];
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThanOrEqualTo(7));
    });
  });

  // -----------------------------------------------------------------
  // 2. Weak hand passes
  // -----------------------------------------------------------------
  group('weak hand passes', () {
    test('all low cards passes', () {
      final hand = [
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('H7'),
        GameCard.decode('H8'),
        GameCard.decode('C7'),
        GameCard.decode('C8'),
        GameCard.decode('D8'),
        GameCard.decode('D9'),
      ];
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<PassAction>());
    });

    test('scattered low/mid cards pass', () {
      final hand = [
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('H10'),
        GameCard.decode('H9'),
        GameCard.decode('C8'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
        GameCard.decode('D9'),
      ];
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<PassAction>());
    });
  });

  // -----------------------------------------------------------------
  // 3. Never outbids partner unless Kout
  // -----------------------------------------------------------------
  group('never outbids partner unless Kout', () {
    test('partner bid Bab, strong hand passes (not Kout-worthy)', () {
      // Hand that supports Six/Seven but NOT Kout.
      // 4 spades (no 6+ suit) + joker + 2 aces + king. Evaluator score ~6-7.
      // No Kout gate passing shape (longest suit = 4).
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('HA'),
        GameCard.decode('CA'),
        GameCard.decode('D8'),
      ];
      // Verify it would bid something if partner hadn't already bid.
      final noBidHistory = BidStrategy.decideBid(hand, null);
      expect(noBidHistory, isA<BidAction>());

      final action = BidStrategy.decideBid(
        hand,
        BidAmount.bab,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 0, action: '5')], // partner (seat 0) bid
      );
      expect(action, isA<PassAction>());
    });

    test('partner bid Bab, Kout-worthy hand bids Kout', () {
      // Monster hand: 7 spades + joker → passes Kout gate.
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
      ];
      // Verify ceiling is kout-level.
      expect(_et(hand), greaterThanOrEqualTo(7.0));
      final action = BidStrategy.decideBid(
        hand,
        BidAmount.bab,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 0, action: '5')], // partner bid
      );
      // Should outbid partner since this is Kout-worthy.
      expect(action, isA<BidAction>());
    });
  });

  // -----------------------------------------------------------------
  // 4. Seven gate blocks Seven without 6+ suit
  // -----------------------------------------------------------------
  group('Seven gate blocks Seven without qualifying shape', () {
    test('high effectiveTricks but no 6+ suit and no Joker+AK5 blocks Seven',
        () {
      // Spread across suits: 3-3-1-1. No suit has 6+. No joker.
      // Moderate-high cards → effective tricks around 6-7 range.
      // No joker means no "Joker + 5 + AK" or "3 Aces + Joker" paths.
      final hand = [
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('HA'),
        GameCard.decode('HK'),
        GameCard.decode('HQ'),
        GameCard.decode('CA'),
        GameCard.decode('D8'),
      ];
      final et = _et(hand);
      // Verify effective tricks would qualify for Seven threshold.
      expect(et, greaterThanOrEqualTo(7.0));
      // But Seven gate should block since no qualifying shape.
      final action = BidStrategy.decideBid(hand, null);
      if (action is BidAction) {
        // Should be capped at Six since Seven gate fails.
        expect(action.amount.value, lessThanOrEqualTo(6));
      }
    });
  });

  // -----------------------------------------------------------------
  // 5. Seven gate allows Seven with 6+ suit
  // -----------------------------------------------------------------
  group('Seven gate allows Seven with 6+ suit', () {
    test('6-card suit passes Seven gate', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('HA'),
      ];
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThanOrEqualTo(7));
    });

    test('Joker + 5-card suit with AK passes Seven gate', () {
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

    test('3 Aces + Joker passes Seven gate', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
      ];
      // Has 3 aces + joker → passes seven gate.
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThanOrEqualTo(7));
    });
  });

  // -----------------------------------------------------------------
  // 6. Kout gate blocks/allows appropriately
  // -----------------------------------------------------------------
  group('Kout gate', () {
    test('7-card suit + Joker passes Kout gate', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.kout);
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.kout);
    });

    test('6-card suit without AKQ + Joker does not pass Kout gate', () {
      // 6 spades (low cards) + joker, no AKQ block.
      // Weaker cards to keep effectiveTricks < 7.6.
      final hand = [
        GameCard.joker(),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
        GameCard.decode('S7'),
        GameCard.decode('SK'),
        GameCard.decode('H8'),
      ];
      // Shape floor: 6 + joker → Seven. No AKQ → no Kout floor.
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.seven);
      // Effective tricks should be < 7.6 with these weak cards.
      final et = _et(hand);
      expect(et, lessThan(7.6));
      final action = BidStrategy.decideBid(hand, null);
      if (action is BidAction) {
        expect(action.amount.value, lessThanOrEqualTo(7));
      }
    });

    test('6-card suit + Joker + AKQ passes Kout gate', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('HA'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.kout);
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.kout);
    });
  });

  // -----------------------------------------------------------------
  // 7. Forced player bids based on hand (not always Bab)
  // -----------------------------------------------------------------
  group('forced bid uses hand strength', () {
    test('forced with strong hand bids higher than Bab', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
      ];
      final action = BidStrategy.decideBid(hand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThan(5));
    });
  });

  // -----------------------------------------------------------------
  // 8. Forced with weak hand bids Bab
  // -----------------------------------------------------------------
  group('forced with weak hand bids Bab', () {
    test('weak forced hand bids Bab', () {
      final hand = [
        GameCard.decode('S7'),
        GameCard.decode('H7'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
        GameCard.decode('S8'),
        GameCard.decode('H8'),
        GameCard.decode('C8'),
        GameCard.decode('D9'),
      ];
      final action = BidStrategy.decideBid(hand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });
  });

  // -----------------------------------------------------------------
  // 9. Desperation lowers thresholds
  // -----------------------------------------------------------------
  group('desperation lowers thresholds', () {
    test('opponent at 21+ triggers desperation, borderline hand now bids', () {
      // Hand where effective tricks is ~4.0-4.9: passes normally (threshold 5.0)
      // but with desperation offset of 1.0, adjusted = et + 1.0 >= 5.0.
      // Need: no shape floor that would cause a bid on its own.
      // Spread cards across suits (no suit with 5+).
      final hand = [
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('HA'),
        GameCard.decode('H9'),
        GameCard.decode('C9'),
        GameCard.decode('C8'),
        GameCard.decode('D8'),
        GameCard.decode('D9'),
      ];
      final etNormal = _et(hand);
      // Verify effective tricks is in the desperation-relevant range.
      expect(etNormal, greaterThanOrEqualTo(4.0));
      expect(etNormal, lessThan(5.0));

      // Without desperation: should pass (et < 5.0, no shape floor).
      final normalAction = BidStrategy.decideBid(hand, null);
      expect(normalAction, isA<PassAction>());

      // With desperation: opponent at 25 (>= 31-10=21).
      final desperateAction = BidStrategy.decideBid(
        hand,
        null,
        scores: {Team.a: 0, Team.b: 25},
        myTeam: Team.a,
      );
      // Desperation offset of 1.0 pushes adjusted threshold to 4.0.
      // et >= 4.0 → should now bid Bab.
      expect(desperateAction, isA<BidAction>());
    });

    test('opponent at 20 does NOT trigger desperation', () {
      final hand = [
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('H9'),
        GameCard.decode('H8'),
        GameCard.decode('C8'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
        GameCard.decode('D9'),
      ];
      final normal = BidStrategy.decideBid(hand, null);
      final withScore = BidStrategy.decideBid(
        hand,
        null,
        scores: {Team.a: 0, Team.b: 20},
        myTeam: Team.a,
      );
      // Both should behave the same (no desperation at opp=20).
      expect(normal.runtimeType, withScore.runtimeType);
    });
  });

  // -----------------------------------------------------------------
  // 10. Shape floors enforce minimum bids
  // -----------------------------------------------------------------
  group('shape floors', () {
    test('5-card suit → Bab floor', () {
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
    });

    test('5-card suit + Joker → Six floor', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('S9'),
        GameCard.decode('S10'),
        GameCard.decode('SJ'),
        GameCard.decode('H7'),
        GameCard.decode('C7'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.six);
    });

    test('6-card suit → Six floor', () {
      final hand = [
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('S9'),
        GameCard.decode('S10'),
        GameCard.decode('SJ'),
        GameCard.decode('SQ'),
        GameCard.decode('H7'),
        GameCard.decode('C7'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.six);
    });

    test('6-card suit + Joker → Seven floor', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('S9'),
        GameCard.decode('S10'),
        GameCard.decode('SJ'),
        GameCard.decode('SQ'),
        GameCard.decode('H7'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.seven);
    });

    test('6-card suit + Joker + AKQ → Kout floor', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('H7'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.kout);
    });

    test('7-card suit → Seven floor', () {
      final hand = [
        GameCard.decode('S7'),
        GameCard.decode('S8'),
        GameCard.decode('S9'),
        GameCard.decode('S10'),
        GameCard.decode('SJ'),
        GameCard.decode('SQ'),
        GameCard.decode('SK'),
        GameCard.decode('H7'),
      ];
      expect(BidStrategy.computeShapeFloorBid(hand), BidAmount.seven);
    });

    test('7-card suit + Joker → Kout floor', () {
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
    });
  });

  // -----------------------------------------------------------------
  // 11. Opponent contest only when effective tricks support it
  // -----------------------------------------------------------------
  group('opponent contest', () {
    test('opponent bid Bab, strong hand outbids to Six', () {
      // Very strong hand.
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CA'),
        GameCard.decode('DA'),
        GameCard.decode('SK'),
        GameCard.decode('HK'),
        GameCard.decode('CK'),
      ];
      final action = BidStrategy.decideBid(
        hand,
        BidAmount.bab,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 1, action: '5')], // opponent bid
      );
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.six);
    });

    test('opponent bid Bab, weak hand passes', () {
      final hand = [
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('H9'),
        GameCard.decode('H8'),
        GameCard.decode('C8'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
        GameCard.decode('D9'),
      ];
      final action = BidStrategy.decideBid(
        hand,
        BidAmount.bab,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 1, action: '5')],
      );
      expect(action, isA<PassAction>());
    });

    test('opponent bid Six, moderate hand cannot outbid to Seven', () {
      // Hand that can support Six but not Seven.
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('SQ'),
        GameCard.decode('SJ'),
        GameCard.decode('HA'),
        GameCard.decode('H9'),
        GameCard.decode('C8'),
      ];
      final et = _et(hand);
      final action = BidStrategy.decideBid(
        hand,
        BidAmount.six,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 1, action: '6')],
      );
      if (et < 7.0) {
        expect(action, isA<PassAction>());
      }
    });
  });

  // -----------------------------------------------------------------
  // Backward compatibility
  // -----------------------------------------------------------------
  group('backward compat', () {
    test('decideBid works with minimal params', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CA'),
        GameCard.decode('SK'),
        GameCard.decode('HK'),
        GameCard.decode('CK'),
        GameCard.decode('DA'),
      ];
      // Just hand + currentHighBid.
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
    });

    test('forced bid with existing high bid returns next legal bid', () {
      final hand = [
        GameCard.decode('S7'),
        GameCard.decode('H7'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
        GameCard.decode('S8'),
        GameCard.decode('H8'),
        GameCard.decode('C8'),
        GameCard.decode('D9'),
      ];
      final action = BidStrategy.decideBid(
        hand,
        BidAmount.bab,
        isForced: true,
      );
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThan(5));
    });
  });
}
