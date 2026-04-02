import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';

void main() {
  group('PlayStrategy', () {
    test('follows suit when holding suit cards', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
        const GameCard(suit: Suit.clubs, rank: Rank.queen),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.spades, rank: Rank.king)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );

      expect(result.card.suit, Suit.spades);
    });

    test('trumps in when void in led suit', () {
      final hand = [
        const GameCard(suit: Suit.hearts, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
        const GameCard(suit: Suit.clubs, rank: Rank.queen),
        const GameCard(suit: Suit.diamonds, rank: Rank.jack),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.spades, rank: Rank.king)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );

      // Should play a trump card (hearts)
      expect(result.card.suit, Suit.hearts);
    });

    test('does not overtake partner when partner is winning (last position)', () {
      // Seat 0's partner is seat 2 (uid: p2). Must be last to play (position 3).
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.spades, rank: Rank.nine)),
          (playerUid: 'p2', card: const GameCard(suit: Suit.spades, rank: Rank.king)),
          (playerUid: 'p3', card: const GameCard(suit: Suit.spades, rank: Rank.eight)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
      );

      // Last to play, partner winning → dump low
      expect(result.card.rank, Rank.seven);
    });

    test('dumps lowest when can\'t win', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.spades, rank: Rank.eight),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.spades, rank: Rank.ace)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );

      expect(result.card.rank, Rank.seven);
    });

    test('leading: does not lead with Joker', () {
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.spades, rank: Rank.ace),
        const GameCard(suit: Suit.hearts, rank: Rank.king),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [],
        trumpSuit: Suit.hearts,
        ledSuit: null,
        mySeat: 0,
      );

      expect(result.card.isJoker, isFalse);
    });

    test('plays Joker late to avoid poison (trick 6, void in suit)', () {
      // 3 cards = trick 6 (9-3), void in clubs → plays Joker
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.spades, rank: Rank.seven),
        const GameCard(suit: Suit.hearts, rank: Rank.eight),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.clubs, rank: Rank.ace)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.clubs,
        mySeat: 2,
      );

      expect(result.card.isJoker, isTrue);
    });

    test('plays Joker to steal when opponent trumps in', () {
      // 5 cards = trick 4, void in spades, opponent trumped with hearts
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.diamonds, rank: Rank.nine),
        const GameCard(suit: Suit.diamonds, rank: Rank.jack),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.spades, rank: Rank.king)),
          (playerUid: 'p3', card: const GameCard(suit: Suit.hearts, rank: Rank.ace)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );

      // Opponent trumped → Joker steals the contested trick
      expect(result.card.isJoker, isTrue);
    });

    test('does not play Joker early when trick is low-value', () {
      // 6 cards = trick 3, void in spades, no trump played
      final hand = [
        GameCard.joker(),
        const GameCard(suit: Suit.clubs, rank: Rank.seven),
        const GameCard(suit: Suit.clubs, rank: Rank.eight),
        const GameCard(suit: Suit.hearts, rank: Rank.nine),
        const GameCard(suit: Suit.diamonds, rank: Rank.nine),
        const GameCard(suit: Suit.diamonds, rank: Rank.jack),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: const GameCard(suit: Suit.spades, rank: Rank.seven)),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );

      // Trick 3, no trump in play → save Joker, trump in or dump instead
      expect(result.card.isJoker, isFalse);
    });

    test('returns a valid PlayCardAction', () {
      final hand = [
        const GameCard(suit: Suit.spades, rank: Rank.ace),
      ];

      final result = PlayStrategy.selectCard(
        hand: hand,
        trickPlays: [],
        trumpSuit: Suit.hearts,
        ledSuit: null,
        mySeat: 0,
      );

      expect(result, isA<PlayCardAction>());
      expect(result.card, hand.first);
    });
  });
}
