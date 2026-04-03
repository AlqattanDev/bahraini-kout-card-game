import { describe, it, expect } from 'vitest';
import { evaluateHand } from '../../../src/game/bot/hand-evaluator';

describe('evaluateHand', () => {
  it('scores joker as 1.0', () => {
    const score = evaluateHand(['JO']);
    expect(score).toBeGreaterThanOrEqual(1.0);
  });

  it('scores ace at 0.9 base', () => {
    const score = evaluateHand(['SA']);
    expect(score).toBeGreaterThan(0.9);
  });

  it('adds trump bonus for trump honors', () => {
    const withoutTrump = evaluateHand(['SA', 'SK']);
    const withTrump = evaluateHand(['SA', 'SK'], 'spades');
    expect(withTrump).toBeGreaterThan(withoutTrump);
  });

  it('adds texture bonus for A-K-Q', () => {
    const akq = evaluateHand(['SA', 'SK', 'SQ']);
    const ak = evaluateHand(['SA', 'SK', 'S9']);
    expect(akq).toBeGreaterThan(ak);
  });

  it('adds long suit bonus for 4+ cards', () => {
    const threeSuit = evaluateHand(['S7', 'S8', 'S9']);
    const fourSuit = evaluateHand(['S7', 'S8', 'S9', 'S10']);
    expect(fourSuit - threeSuit).toBeGreaterThan(0.3);
  });

  it('clamps result between 0 and 8', () => {
    expect(evaluateHand([])).toBeGreaterThanOrEqual(0);
    expect(evaluateHand([])).toBeLessThanOrEqual(8);
  });
});
