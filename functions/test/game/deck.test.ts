import { buildFourPlayerDeck, dealHands } from '../../src/game/deck';
import { GameCard } from '../../src/game/types';

describe('buildFourPlayerDeck', () => {
  let deck: GameCard[];

  beforeEach(() => {
    deck = buildFourPlayerDeck();
  });

  test('has exactly 32 cards', () => {
    expect(deck.length).toBe(32);
  });

  test('spades has 8 cards (A, K, Q, J, 10, 9, 8, 7)', () => {
    const spades = deck.filter((c) => !c.isJoker && c.suit === 'spades');
    expect(spades.length).toBe(8);
  });

  test('hearts has 8 cards', () => {
    const hearts = deck.filter((c) => !c.isJoker && c.suit === 'hearts');
    expect(hearts.length).toBe(8);
  });

  test('clubs has 8 cards', () => {
    const clubs = deck.filter((c) => !c.isJoker && c.suit === 'clubs');
    expect(clubs.length).toBe(8);
  });

  test('diamonds has 7 cards (A, K, Q, J, 10, 9, 8 — no 7)', () => {
    const diamonds = deck.filter((c) => !c.isJoker && c.suit === 'diamonds');
    expect(diamonds.length).toBe(7);
    expect(diamonds.some((c) => c.rank === 'seven')).toBe(false);
  });

  test('has exactly 1 joker', () => {
    const jokers = deck.filter((c) => c.isJoker);
    expect(jokers.length).toBe(1);
  });

  test('no duplicate cards', () => {
    const codes = new Set(deck.map((c) => c.code));
    expect(codes.size).toBe(32);
  });
});

describe('dealHands', () => {
  test('deals 8 cards to each of 4 players', () => {
    const deck = buildFourPlayerDeck();
    const hands = dealHands(deck);
    expect(hands.length).toBe(4);
    for (const hand of hands) {
      expect(hand.length).toBe(8);
    }
  });

  test('all 32 cards are distributed', () => {
    const deck = buildFourPlayerDeck();
    const hands = dealHands(deck);
    const allCodes = new Set(hands.flat().map((c) => c.code));
    expect(allCodes.size).toBe(32);
  });

  test('shuffling produces different deals (probabilistic)', () => {
    const deck1 = buildFourPlayerDeck();
    const deck2 = buildFourPlayerDeck();
    const hands1 = dealHands(deck1);
    const hands2 = dealHands(deck2);
    const encoded1 = hands1[0].map((c) => c.code).join(',');
    const encoded2 = hands2[0].map((c) => c.code).join(',');
    // Very unlikely to be the same — if this flakes, re-run
    expect(encoded1).not.toBe(encoded2);
  });
});
