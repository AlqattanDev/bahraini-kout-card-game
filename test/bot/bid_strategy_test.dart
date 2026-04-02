import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';

void main() {
  group('decideBid', () {
    test('11. strength >= 4.5 → BidAction(bab)', () {
      // Hand evaluates to ~4.5 expected winners
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
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });

    test('12. strength < 4.5 → PassAction', () {
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
      final action = BidStrategy.decideBid(hand, null);
      expect(action, isA<PassAction>());
    });

    test('13. isForced + no prior bid → BidAction(bab)', () {
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

    test('14. currentHighBid exists + can outbid → smallest legal outbid', () {
      // Hand with ~5.8 expected winners → maxBid = six
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
      expect((action as BidAction).amount, BidAmount.six);
    });

    test('15. currentHighBid exists + can\'t outbid → PassAction', () {
      // Hand with ~4.5 expected winners → maxBid = bab (value 5)
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
      // Can't outbid bab with maxBid of bab
      final action = BidStrategy.decideBid(hand, BidAmount.bab);
      expect(action, isA<PassAction>());
    });
  });

  group('T1.4 score-aware bidding', () {
    // Hand with ~4.2 expectedWinners (below 4.5 threshold without adjustment)
    final mediumHand = [
      GameCard.joker(),
      GameCard.decode('SA'),
      GameCard.decode('HA'),
      GameCard.decode('CA'),
      GameCard.decode('SK'),
      GameCard.decode('H10'),
      GameCard.decode('C9'),
      GameCard.decode('D8'),
    ];

    test('myScore=28 → bids (threshold lowered by 0.5)', () {
      final action = BidStrategy.decideBid(
        mediumHand,
        null,
        scores: {Team.a: 28, Team.b: 0},
        myTeam: Team.a,
      );
      // 4.2 + 0.5 = 4.7 >= 4.5 → bab
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });

    test('oppScore=28 → bids (threshold lowered by 0.5)', () {
      final action = BidStrategy.decideBid(
        mediumHand,
        null,
        scores: {Team.a: 0, Team.b: 28},
        myTeam: Team.a,
      );
      // 4.2 + 0.5 = 4.7 >= 4.5 → bab
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });

    test('oppScore=26 myScore=3 → bids (desperate mode)', () {
      // Weaker hand: ~3.6 expectedWinners
      final weakerHand = [
        GameCard.joker(),
        GameCard.decode('SA'),
        GameCard.decode('HA'),
        GameCard.decode('SK'),
        GameCard.decode('HK'),
        GameCard.decode('C9'),
        GameCard.decode('D8'),
        GameCard.decode('D9'),
      ];
      final action = BidStrategy.decideBid(
        weakerHand,
        null,
        scores: {Team.a: 3, Team.b: 26},
        myTeam: Team.a,
      );
      // 3.6 + 0.5 (opp>=26) + 0.8 (desperate) = 4.9 >= 4.5 → bab
      expect(action, isA<BidAction>());
      expect((action as BidAction).amount, BidAmount.bab);
    });

    test('no scores → same behavior as before', () {
      // mediumHand without scores → 4.2 < 4.5 → Pass
      final action = BidStrategy.decideBid(mediumHand, null);
      expect(action, isA<PassAction>());
    });
  });
}
