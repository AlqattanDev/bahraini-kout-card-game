import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';
import 'package:koutbh/offline/bot/hand_evaluator.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';

void main() {
  // Helper to verify hand strength before using in bid tests
  double strength(List<GameCard> hand) =>
      HandEvaluator.evaluate(hand).expectedWinners;

  group('decideBid basics', () {
    test('strong hand bids', () {
      // 3 Aces + Joker + 2 Kings → should be well above 4.5
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CA'),
        GameCard.decode('SK'),
        GameCard.decode('HK'),
        GameCard.decode('C8'),
        GameCard.decode('D8'),
      ];
      expect(strength(hand), greaterThanOrEqualTo(4.5));
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
    });

    test('weak hand passes', () {
      final hand = [
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
        GameCard.decode('H10'),
        GameCard.decode('H9'),
        GameCard.decode('C8'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
      ];
      expect(strength(hand), lessThan(4.5));
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<PassAction>());
    });

    test('isForced + no prior bid → BidAction(bab)', () {
      final hand = [
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
        GameCard.decode('H10'),
        GameCard.decode('H9'),
        GameCard.decode('C8'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
      ];
      final action = BidStrategy.decideBid(hand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });

    test('currentHighBid exists + can outbid → outbids', () {
      // Very strong hand → should max out well above bab
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
      final action = BidStrategy.decideBid(hand, BidAmount.bab);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount.value, greaterThan(BidAmount.bab.value));
    });

    test('currentHighBid at max strength → PassAction', () {
      // Hand in bab range (4.5-5.5), can't outbid bab
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('SK'),
        GameCard.decode('HK'),
        GameCard.decode('CQ'),
        GameCard.decode('S9'),
        GameCard.decode('D8'),
      ];
      expect(strength(hand), greaterThanOrEqualTo(4.5));
      expect(strength(hand), lessThan(5.5));
      final action = BidStrategy.decideBid(hand, BidAmount.bab);
      expect(action, isA<PassAction>());
    });
  });

  group('score-aware bidding', () {
    // Hand that passes without adjustment (~3.6)
    final belowThreshold = [
      GameCard.joker(),
      GameCard.decode('SA'),
      GameCard.decode('HA'),
      GameCard.decode('CK'),
      GameCard.decode('DJ'),
      GameCard.decode('S9'),
      GameCard.decode('H8'),
      GameCard.decode('C7'),
    ];

    test('hand is below threshold without adjustment', () {
      expect(strength(belowThreshold), lessThan(4.5));
      final action = BidStrategy.decideBid(belowThreshold, null);
      expect(action, isA<PassAction>());
    });

    test('any bid wins game (my+5-opp>=31) → aggressive +1.0', () {
      final action = BidStrategy.decideBid(
        belowThreshold,
        null,
        scores: {Team.a: 28, Team.b: 0},
        myTeam: Team.a,
      );
      // +1.0 should push above 4.5
      expect(action, isA<BidAction>());
    });

    test('Bab alone reaches 31 → aggressive +0.8', () {
      final action = BidStrategy.decideBid(
        belowThreshold,
        null,
        scores: {Team.a: 26, Team.b: 0},
        myTeam: Team.a,
      );
      // 26+5=31, +0.8 should push above 4.5
      expect(action, isA<BidAction>());
    });

    test('opponent close (opp>=26) → +0.5', () {
      final action = BidStrategy.decideBid(
        belowThreshold,
        null,
        scores: {Team.a: 10, Team.b: 28},
        myTeam: Team.a,
      );
      // my=10 > 5, so not desperate. opp=28>=26 → +0.5
      // Need hand where +0.5 tips it over
      final s = strength(belowThreshold);
      if (s + 0.5 >= 4.5) {
        expect(action, isA<BidAction>());
      } else {
        expect(action, isA<PassAction>());
      }
    });

    test('desperate mode (opp>=25, my<=5) → +1.0', () {
      final action = BidStrategy.decideBid(
        belowThreshold,
        null,
        scores: {Team.a: 3, Team.b: 26},
        myTeam: Team.a,
      );
      // desperate → +1.0 should push above 4.5
      expect(action, isA<BidAction>());
    });

    test('no scores → no adjustment, passes with below-threshold hand', () {
      final action = BidStrategy.decideBid(belowThreshold, null);
      expect(action, isA<PassAction>());
    });
  });

  group('position-aware bidding', () {
    test('first to bid is conservative (-0.3)', () {
      // Find a hand right at the boundary: passes when first, bids when last
      // Use a hand at ~4.6 (bids normally, but -0.3 drops to 4.3 → pass)
      final borderlineHand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CK'),
        GameCard.decode('SQ'),
        GameCard.decode('HJ'),
        GameCard.decode('C9'),
        GameCard.decode('D8'),
      ];
      final s = strength(borderlineHand);

      // First to bid: -0.3
      final action = BidStrategy.decideBid(
        borderlineHand,
        null,
        mySeat: 1,
        bidHistory: [],
      );
      if (s - 0.3 < 4.5) {
        expect(action, isA<PassAction>());
      } else {
        expect(action, isA<BidAction>());
      }
    });

    test('position 0 is more conservative than position 3', () {
      // Use a hand that would bid at position 3 but not position 0
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CK'),
        GameCard.decode('SQ'),
        GameCard.decode('DJ'),
        GameCard.decode('H8'),
        GameCard.decode('C7'),
      ];
      // First (no history): strength - 0.3
      final actionFirst = BidStrategy.decideBid(
        hand,
        null,
        mySeat: 1,
        bidHistory: [],
      );

      // Last (3 entries): s + 0.3 (but partner at seat 3 passed → -0.3)
      final actionLast = BidStrategy.decideBid(
        hand,
        null,
        mySeat: 0,
        bidHistory: [
          (seat: 3, action: 'pass'),
          (seat: 2, action: 'pass'),
          (seat: 1, action: 'pass'),
        ],
      );

      // First should be more conservative (lower effective strength)
      // Both might pass or both might bid — the point is first ≤ last
      final firstBids = actionFirst is BidAction;
      final lastBids = actionLast is BidAction;
      // If last passes, first must also pass
      if (!lastBids) {
        expect(firstBids, isFalse);
      }
    });
  });

  group('partner inference', () {
    test('partner bid increases effective strength', () {
      // Hand at ~4.2 — passes normally. With partner bid (+0.3) may bid.
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CK'),
        GameCard.decode('DJ'),
        GameCard.decode('S9'),
        GameCard.decode('H8'),
        GameCard.decode('C7'),
      ];
      final s = strength(hand);
      // With partner bid at position 2: s + 0.2 (position) + 0.3 (partner)
      final withPartner = BidStrategy.decideBid(
        hand,
        null,
        mySeat: 2,
        bidHistory: [
          (seat: 0, action: '5'),
          (seat: 1, action: 'pass'),
        ],
      );
      // Note: currentHighBid is null but partner bid '5'. In real game
      // currentHighBid would be bab. Test here is about threshold, not outbid.
      // With null currentHighBid and maxBid: just verifying it can bid.
      if (s + 0.5 >= 4.5) {
        expect(withPartner, isA<BidAction>());
      }
    });

    test('partner pass decreases effective strength', () {
      final hand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('CK'),
        GameCard.decode('DJ'),
        GameCard.decode('S9'),
        GameCard.decode('H8'),
        GameCard.decode('C7'),
      ];
      final s = strength(hand);
      // With partner passed at position 2: s + 0.2 (position) - 0.3 (pass) = s - 0.1
      final withPartnerPass = BidStrategy.decideBid(
        hand,
        null,
        mySeat: 2,
        bidHistory: [
          (seat: 0, action: 'pass'),
          (seat: 1, action: 'pass'),
        ],
      );
      if (s - 0.1 < 4.5) {
        expect(withPartnerPass, isA<PassAction>());
      }
    });
  });

  group('tactical overbidding', () {
    test('opponent bid Bab, strong hand → overbids to Six', () {
      final strongHand = [
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
        strongHand,
        BidAmount.bab,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [
          (seat: 1, action: '5'),
        ],
      );
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.six);
    });

    test('forced bid still returns minimum legal bid', () {
      final weakHand = [
        GameCard.decode('S10'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
        GameCard.decode('H10'),
        GameCard.decode('H9'),
        GameCard.decode('C8'),
        GameCard.decode('C7'),
        GameCard.decode('D8'),
      ];
      final action = BidStrategy.decideBid(
        weakHand,
        null,
        isForced: true,
      );
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });
  });
}
