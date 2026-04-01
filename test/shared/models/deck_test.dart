import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/deck.dart';

void main() {
  group('Deck.fourPlayer', () {
    late Deck deck;
    setUp(() { deck = Deck.fourPlayer(); });

    test('has exactly 32 cards', () { expect(deck.cards.length, 32); });

    test('spades has 8 cards (A, K, Q, J, 10, 9, 8, 7)', () {
      final spades = deck.cards.where((c) => !c.isJoker && c.suit == Suit.spades).toList();
      expect(spades.length, 8);
    });

    test('hearts has 8 cards', () {
      final hearts = deck.cards.where((c) => !c.isJoker && c.suit == Suit.hearts).toList();
      expect(hearts.length, 8);
    });

    test('clubs has 8 cards', () {
      final clubs = deck.cards.where((c) => !c.isJoker && c.suit == Suit.clubs).toList();
      expect(clubs.length, 8);
    });

    test('diamonds has 7 cards (A, K, Q, J, 10, 9, 8 — no 7)', () {
      final diamonds = deck.cards.where((c) => !c.isJoker && c.suit == Suit.diamonds).toList();
      expect(diamonds.length, 7);
      expect(diamonds.any((c) => c.rank == Rank.seven), false);
    });

    test('has exactly 1 joker', () {
      final jokers = deck.cards.where((c) => c.isJoker).toList();
      expect(jokers.length, 1);
    });

    test('no duplicate cards', () {
      final encoded = deck.cards.map((c) => c.encode()).toSet();
      expect(encoded.length, 32);
    });
  });

  group('Deck.deal', () {
    test('deals 8 cards to each of 4 players', () {
      final deck = Deck.fourPlayer();
      final hands = deck.deal(4);
      expect(hands.length, 4);
      for (final hand in hands) { expect(hand.length, 8); }
    });

    test('all 32 cards are distributed', () {
      final deck = Deck.fourPlayer();
      final hands = deck.deal(4);
      final allCards = hands.expand((h) => h).toSet();
      expect(allCards.length, 32);
    });

    test('shuffling produces different deals', () {
      final deck1 = Deck.fourPlayer();
      final deck2 = Deck.fourPlayer();
      final hands1 = deck1.deal(4);
      final hands2 = deck2.deal(4);
      final encoded1 = hands1[0].map((c) => c.encode()).toList();
      final encoded2 = hands2[0].map((c) => c.encode()).toList();
      expect(encoded1, isNot(equals(encoded2)));
    });
  });
}
