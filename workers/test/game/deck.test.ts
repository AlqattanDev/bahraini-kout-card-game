import { describe, it, expect } from 'vitest';
import { buildFourPlayerDeck, dealHands } from '../../src/game/deck';

describe('buildFourPlayerDeck', () => {
  const deck = buildFourPlayerDeck();

  it('has exactly 32 cards', () => {
    expect(deck).toHaveLength(32);
  });

  it('has 8 spades, 8 hearts, 8 clubs', () => {
    for (const suit of ['spades', 'hearts', 'clubs'] as const) {
      const count = deck.filter(c => !c.isJoker && c.suit === suit).length;
      expect(count, `${suit} count`).toBe(8);
    }
  });

  it('has 7 diamonds (no 7 of diamonds)', () => {
    const diamonds = deck.filter(c => !c.isJoker && c.suit === 'diamonds');
    expect(diamonds).toHaveLength(7);
    expect(diamonds.some(c => c.rank === 'seven')).toBe(false);
  });

  it('has exactly 1 Joker', () => {
    expect(deck.filter(c => c.isJoker)).toHaveLength(1);
  });

  it('has no duplicate codes', () => {
    const codes = deck.map(c => c.code);
    expect(new Set(codes).size).toBe(32);
  });
});

describe('dealHands', () => {
  it('deals 4 hands of 8 cards each', () => {
    const deck = buildFourPlayerDeck();
    const hands = dealHands(deck);
    expect(hands).toHaveLength(4);
    for (const hand of hands) {
      expect(hand).toHaveLength(8);
    }
  });

  it('distributes all 32 cards with no duplicates', () => {
    const deck = buildFourPlayerDeck();
    const hands = dealHands(deck);
    const allCodes = hands.flat().map(c => c.code);
    expect(allCodes).toHaveLength(32);
    expect(new Set(allCodes).size).toBe(32);
  });
});
