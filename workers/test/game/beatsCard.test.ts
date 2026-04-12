import { describe, it, expect } from 'vitest';
import { beatsCard } from '../../src/game/card';

describe('beatsCard', () => {
  it('Joker beats everything', () => {
    expect(beatsCard('JO', 'SA', 'spades', 'spades')).toBe(true);
  });

  it('nothing beats Joker', () => {
    expect(beatsCard('SA', 'JO', 'spades', 'spades')).toBe(false);
  });

  it('trump beats non-trump', () => {
    expect(beatsCard('S7', 'HA', 'spades', 'hearts')).toBe(true);
  });

  it('non-trump does not beat trump', () => {
    expect(beatsCard('HA', 'S7', 'spades', 'hearts')).toBe(false);
  });

  it('higher trump beats lower trump', () => {
    expect(beatsCard('SA', 'SK', 'spades', 'hearts')).toBe(true);
    expect(beatsCard('SK', 'SA', 'spades', 'hearts')).toBe(false);
  });

  it('same suit: higher rank wins', () => {
    expect(beatsCard('HA', 'HK', null, 'hearts')).toBe(true);
    expect(beatsCard('HK', 'HA', null, 'hearts')).toBe(false);
  });

  it('led suit beats off-suit (no trump)', () => {
    expect(beatsCard('HA', 'CA', null, 'hearts')).toBe(true);
  });

  it('off-suit does not beat led suit', () => {
    expect(beatsCard('CA', 'H7', null, 'hearts')).toBe(false);
  });

  it('two off-suit cards: neither beats the other', () => {
    expect(beatsCard('CA', 'DA', null, 'hearts')).toBe(false);
    expect(beatsCard('DA', 'CA', null, 'hearts')).toBe(false);
  });

  it('null trump: no trump advantage', () => {
    expect(beatsCard('SA', 'HK', null, 'hearts')).toBe(false);
  });
});
