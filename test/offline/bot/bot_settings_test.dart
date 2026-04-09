import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/bot_settings.dart';
import 'package:koutbh/offline/bot/game_context.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';

void main() {
  group('BotSettings', () {
    test('trump selection weights are positive', () {
      expect(BotSettings.trumpLengthWeight, greaterThan(2.0));
      expect(BotSettings.trumpStrengthWeight, greaterThan(0.0));
    });

    test('partner estimates are ordered pass < default < bid', () {
      expect(BotSettings.partnerEstimatePass,
          lessThan(BotSettings.partnerEstimateDefault));
      expect(BotSettings.partnerEstimateDefault,
          lessThan(BotSettings.partnerEstimateBid));
    });

    test('desperation threshold is positive', () {
      expect(BotSettings.desperationThreshold, greaterThan(0.0));
    });

    test('PlayStrategy leads a legal card with GameContext', () {
      final hand = [
        GameCard.decode('SA'),
        GameCard.decode('SK'),
        GameCard.decode('HA'),
        GameCard.decode('HK'),
        GameCard.decode('CQ'),
        GameCard.decode('CJ'),
        GameCard.decode('D10'),
        GameCard.decode('D9'),
      ];
      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [],
        trumpSuit: Suit.hearts,
        ledSuit: null,
        mySeat: 0,
        context: GameContext(
          mySeat: 0,
          myTeam: Team.a,
          scores: {Team.a: 0, Team.b: 0},
          currentBid: BidAmount.bab,
          bidderSeat: 0,
          isBiddingTeam: true,
          isForcedBid: false,
          trickCounts: {Team.a: 0, Team.b: 0},
          trickWinners: [],
          trumpSuit: Suit.hearts,
        ),
      );
      expect(result, isA<PlayCardAction>());
      expect(hand.contains(result.card), isTrue);
    });
  });
}
