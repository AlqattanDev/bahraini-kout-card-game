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
      HandEvaluator.evaluate(hand).personalTricks;


  group('decideBid basics', () {
    test('strong hand bids', () {
      // 3 Aces + Joker + 2 Kings
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

    test('isForced + no prior bid -> BidAction(bab)', () {
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

    test('currentHighBid exists + can outbid -> outbids', () {
      // Very strong hand
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
      expect(
        (action as BidAction).amount.value,
        greaterThan(BidAmount.bab.value),
      );
    });

    test('currentHighBid at bab with strong hand -> outbids to Six', () {
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
      final action = BidStrategy.decideBid(hand, BidAmount.bab);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.six);
    });
  });

  group('score-aware bidding', () {
    // Hand that may pass without desperation adjustment.
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

    test('hand with shape may still bid even below threshold', () {
      final action = BidStrategy.decideBid(belowThreshold, null);
      // Shape floor or threshold may cause a bid.
      // This test just verifies no crash.
      expect(action, isA<GameAction>());
    });

    test('desperation (opp >= 21) helps borderline hand bid', () {
      final action = BidStrategy.decideBid(
        belowThreshold,
        null,
        scores: {Team.a: 0, Team.b: 25},
        myTeam: Team.a,
      );
      // Desperation offset of 1.0 should help.
      expect(action, isA<BidAction>());
    });

    test('no scores still works', () {
      final action = BidStrategy.decideBid(belowThreshold, null);
      expect(action, isA<GameAction>());
    });
  });

  group('partner rule', () {
    test('partner bid -> pass (unless Kout)', () {
      // Hand that would normally bid but not Kout-worthy.
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
      final action = BidStrategy.decideBid(
        hand,
        BidAmount.bab,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 0, action: '5'), (seat: 1, action: 'pass')],
      );
      // Partner at seat 0 bid -> pass unless Kout.
      expect(action, isA<PassAction>());
    });

    test('partner passed -> can still bid', () {
      // Partner passed, this hand is strong enough.
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
      final action = BidStrategy.decideBid(
        hand,
        null,
        mySeat: 2,
        myTeam: Team.a,
        bidHistory: [(seat: 0, action: 'pass'), (seat: 1, action: 'pass')],
      );
      // Partner passed, no partner rule blocking. Strong hand should bid.
      expect(action, isA<BidAction>());
    });
  });

  group('tactical overbidding', () {
    test('opponent bid Bab, strong hand -> overbids to Six', () {
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
        bidHistory: [(seat: 1, action: '5')],
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
      final action = BidStrategy.decideBid(weakHand, null, isForced: true);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });
  });
}
