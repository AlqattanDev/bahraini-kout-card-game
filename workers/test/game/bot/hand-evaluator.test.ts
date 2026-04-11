import { describe, it, expect } from 'vitest';
import { evaluateHand } from '../../../src/game/bot/hand-evaluator';

describe('evaluateHand', () => {
  it('scores joker as 1.0 contribution', () => {
    const result = evaluateHand(['JO']);
    expect(result.personalTricks).toBeGreaterThanOrEqual(1.0);
  });

  it('scores ace with base probability 0.85', () => {
    const result = evaluateHand(['SA']);
    expect(result.personalTricks).toBeGreaterThanOrEqual(0.85);
  });

  it('identifies strongest suit', () => {
    // Spades has AK (strong), Hearts has 7 (weak)
    const result = evaluateHand(['SA', 'SK', 'H7']);
    expect(result.strongestSuit).toBe('spades');
  });

  it('adds texture bonus for A-K-Q', () => {
    const akq = evaluateHand(['SA', 'SK', 'SQ']);
    const ak = evaluateHand(['SA', 'SK', 'S9']);
    expect(akq.personalTricks).toBeGreaterThan(ak.personalTricks);
  });

  it('adds long suit bonus for 4+ cards (+0.1 per card beyond 3)', () => {
    const threeSuit = evaluateHand(['S7', 'S8', 'S9']);
    const fourSuit = evaluateHand(['S7', 'S8', 'S9', 'S10']);
    expect(fourSuit.personalTricks - threeSuit.personalTricks).toBeGreaterThan(0);
  });

  it('clamps result between 0 and 8', () => {
    expect(evaluateHand([]).personalTricks).toBeGreaterThanOrEqual(0);
    expect(evaluateHand([]).personalTricks).toBeLessThanOrEqual(8);
  });

  it('returns null strongestSuit for empty hand', () => {
    expect(evaluateHand([]).strongestSuit).toBeNull();
  });
});
