import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/trick.dart';
import 'package:bahraini_kout/shared/logic/trick_resolver.dart';

void main() {
  group('TrickResolver', () {
    test('highest card of led suit wins (no trump, no joker)', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.hearts, rank: Rank.nine)),
        TrickPlay(playerIndex: 1, card: GameCard(suit: Suit.hearts, rank: Rank.king)),
        TrickPlay(playerIndex: 2, card: GameCard(suit: Suit.hearts, rank: Rank.seven)),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.hearts, rank: Rank.ace)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 3);
    });

    test('off-suit cards lose to led suit', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.hearts, rank: Rank.seven)),
        TrickPlay(playerIndex: 1, card: GameCard(suit: Suit.clubs, rank: Rank.ace)),
        TrickPlay(playerIndex: 2, card: GameCard(suit: Suit.diamonds, rank: Rank.ace)),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.hearts, rank: Rank.eight)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 3);
    });

    test('trump beats led suit', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.hearts, rank: Rank.ace)),
        TrickPlay(playerIndex: 1, card: GameCard(suit: Suit.spades, rank: Rank.seven)),
        TrickPlay(playerIndex: 2, card: GameCard(suit: Suit.hearts, rank: Rank.king)),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.hearts, rank: Rank.queen)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 1);
    });

    test('highest trump wins when multiple trumps played', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.hearts, rank: Rank.ace)),
        TrickPlay(playerIndex: 1, card: GameCard(suit: Suit.spades, rank: Rank.seven)),
        TrickPlay(playerIndex: 2, card: GameCard(suit: Suit.spades, rank: Rank.jack)),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.hearts, rank: Rank.king)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 2);
    });

    test('joker always wins', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.hearts, rank: Rank.ace)),
        TrickPlay(playerIndex: 1, card: GameCard(suit: Suit.spades, rank: Rank.ace)),
        TrickPlay(playerIndex: 2, card: GameCard.joker()),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.hearts, rank: Rank.king)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 2);
    });

    test('joker beats trump ace', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.spades, rank: Rank.ace)),
        TrickPlay(playerIndex: 1, card: GameCard.joker()),
        TrickPlay(playerIndex: 2, card: GameCard(suit: Suit.spades, rank: Rank.king)),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.spades, rank: Rank.queen)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 1);
    });

    test('when trump is led, highest trump wins (no joker)', () {
      final trick = Trick(leadPlayerIndex: 0, plays: [
        TrickPlay(playerIndex: 0, card: GameCard(suit: Suit.spades, rank: Rank.nine)),
        TrickPlay(playerIndex: 1, card: GameCard(suit: Suit.spades, rank: Rank.ace)),
        TrickPlay(playerIndex: 2, card: GameCard(suit: Suit.hearts, rank: Rank.ace)),
        TrickPlay(playerIndex: 3, card: GameCard(suit: Suit.spades, rank: Rank.ten)),
      ]);
      expect(TrickResolver.resolve(trick, trumpSuit: Suit.spades), 1);
    });
  });
}
