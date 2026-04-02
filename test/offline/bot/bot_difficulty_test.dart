import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/bot_difficulty.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';
import 'package:koutbh/offline/bot/hand_evaluator.dart';
import 'package:koutbh/offline/bot/trump_strategy.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';
import 'package:koutbh/offline/bot/game_context.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';

void main() {
  group('BotDifficulty bid behavior', () {
    // Hand near threshold (~4.3) — conservative passes, aggressive bids
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

    test('conservative is less likely to bid than aggressive', () {
      final s = HandEvaluator.evaluate(borderlineHand).expectedWinners;

      final conservativeAction = BidStrategy.decideBid(
        borderlineHand,
        null,
        difficultyAdjust: BotDifficulty.conservative.bidAdjust,
      );
      final aggressiveAction = BidStrategy.decideBid(
        borderlineHand,
        null,
        difficultyAdjust: BotDifficulty.aggressive.bidAdjust,
      );

      // With -0.3 (conservative): s - 0.3
      // With +0.3 (aggressive): s + 0.3
      // If s is near 4.5, conservative should pass, aggressive should bid
      if (s + BotDifficulty.aggressive.bidAdjust >= 4.5 &&
          s + BotDifficulty.conservative.bidAdjust < 4.5) {
        expect(conservativeAction, isA<PassAction>());
        expect(aggressiveAction, isA<BidAction>());
      }
    });

    test('balanced bidAdjust is 0.0 (no effect)', () {
      expect(BotDifficulty.balanced.bidAdjust, 0.0);
    });
  });

  group('BotDifficulty trump weights', () {
    test('conservative prefers stronger suits, aggressive prefers longer', () {
      // 3 high cards in hearts vs 4 low cards in spades
      final hand = [
        GameCard.decode('HA'),
        GameCard.decode('HK'),
        GameCard.decode('HQ'),
        GameCard.decode('S9'),
        GameCard.decode('S8'),
        GameCard.decode('S7'),
        GameCard.decode('S10'),
        GameCard.decode('D8'),
      ];

      final conservativePick = TrumpStrategy.selectTrump(
        hand,
        lengthWeight: BotDifficulty.conservative.trumpLengthWeight,
        strengthWeight: BotDifficulty.conservative.trumpStrengthWeight,
      );
      final aggressivePick = TrumpStrategy.selectTrump(
        hand,
        lengthWeight: BotDifficulty.aggressive.trumpLengthWeight,
        strengthWeight: BotDifficulty.aggressive.trumpStrengthWeight,
      );

      // Conservative: strength 2.0 → prefers hearts (A+K+Q = high strength)
      // Aggressive: length 2.5 → prefers spades (4 cards)
      expect(conservativePick, Suit.hearts);
      expect(aggressivePick, Suit.spades);
    });
  });

  group('BotDifficulty Joker threshold', () {
    test('conservative threshold is higher than aggressive', () {
      expect(BotDifficulty.conservative.jokerUrgencyThreshold,
          greaterThan(BotDifficulty.aggressive.jokerUrgencyThreshold));
    });

    test('aggressive plays Joker more readily', () {
      // Scenario: void in led suit, opponent played high card (not trump),
      // 5 cards in hand, no special conditions.
      // Urgency = 0.0 (no trump, no critical trick, 5 cards > 3)
      // With aggressive threshold 0.1 → doesn't fire (0.0 < 0.1)
      // With any threshold > 0.0 → doesn't fire
      // Need urgency > 0 — opponent trumped gives 0.3
      final hand = [
        GameCard.joker(),
        GameCard.decode('H8'),
        GameCard.decode('HK'),
        GameCard.decode('CJ'),
        GameCard.decode('C9'),
      ];

      // Opponent trumped → urgency 0.3
      // Conservative threshold 0.6 → 0.3 < 0.6 → holds Joker
      // Aggressive threshold 0.1 → 0.3 >= 0.1 → plays Joker
      final conservativeCtx = GameContext(
        mySeat: 0,
        myTeam: Team.a,
        scores: {Team.a: 0, Team.b: 0},
        currentBid: BidAmount.bab,
        bidderSeat: 1,
        isBiddingTeam: false,
        isForcedBid: false,
        trickCounts: {Team.a: 0, Team.b: 0},
        trickWinners: [],
        trumpSuit: Suit.diamonds,
        difficulty: BotDifficulty.conservative,
      );
      final aggressiveCtx = GameContext(
        mySeat: 0,
        myTeam: Team.a,
        scores: {Team.a: 0, Team.b: 0},
        currentBid: BidAmount.bab,
        bidderSeat: 1,
        isBiddingTeam: false,
        isForcedBid: false,
        trickCounts: {Team.a: 0, Team.b: 0},
        trickWinners: [],
        trumpSuit: Suit.diamonds,
        difficulty: BotDifficulty.aggressive,
      );

      final conservativeResult = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('D10'))],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'partner',
        context: conservativeCtx,
      );
      final aggressiveResult = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('D10'))],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'partner',
        context: aggressiveCtx,
      );

      // Conservative holds Joker (0.3 < 0.6), aggressive plays it (0.3 >= 0.1)
      expect(conservativeResult.card.isJoker, isFalse);
      expect(aggressiveResult.card.isJoker, isTrue);
    });
  });

  group('all difficulties produce legal moves', () {
    for (final difficulty in BotDifficulty.values) {
      test('$difficulty plays legal card', () {
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
            difficulty: difficulty,
          ),
        );
        expect(result, isA<PlayCardAction>());
        expect(hand.contains(result.card), isTrue);
      });
    }
  });
}
