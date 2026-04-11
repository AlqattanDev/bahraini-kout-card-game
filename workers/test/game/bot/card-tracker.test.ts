import { describe, it, expect } from 'vitest';
import { CardTracker } from '../../../src/game/bot/card-tracker';

describe('CardTracker', () => {
  it('tracks played cards and excludes from remaining', () => {
    const tracker = new CardTracker();
    tracker.recordPlay(0, 'SA');
    const remaining = tracker.remainingCards(['SK']);
    expect(remaining).not.toContain('SA');
    expect(remaining).not.toContain('SK');
  });

  it('identifies highest remaining card', () => {
    const tracker = new CardTracker();
    tracker.recordPlay(0, 'SA');
    expect(tracker.isHighestRemaining('SK', ['SK'])).toBe(true);
  });

  it('joker is always highest remaining', () => {
    const tracker = new CardTracker();
    expect(tracker.isHighestRemaining('JO', ['JO'])).toBe(true);
  });

  it('detects exhausted suit', () => {
    const tracker = new CardTracker();
    const allSpades = ['SA', 'SK', 'SQ', 'SJ', 'S10', 'S9', 'S8', 'S7'];
    for (const c of allSpades.slice(1)) tracker.recordPlay(0, c);
    expect(tracker.isSuitExhausted('spades', ['SA'])).toBe(true);
  });

  it('counts remaining trumps', () => {
    const tracker = new CardTracker();
    tracker.recordPlay(0, 'SA');
    tracker.recordPlay(1, 'SK');
    expect(tracker.trumpsRemaining('spades', ['SQ'])).toBe(5);
  });

  it('records void inference', () => {
    const tracker = new CardTracker();
    tracker.inferVoid(1, 'hearts');
    expect(tracker.knownVoids.get(1)?.has('hearts')).toBe(true);
  });
});
