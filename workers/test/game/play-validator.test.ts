import { describe, it, expect } from 'vitest';
import { validatePlay, detectPoisonJoker } from '../../src/game/play-validator';

describe('validatePlay', () => {
  it('rejects card not in hand', () => {
    expect(validatePlay('SA', ['SK', 'HK'], null, true).valid).toBe(false);
  });

  it('accepts card in hand when leading', () => {
    expect(validatePlay('SA', ['SA', 'HK'], null, true).valid).toBe(true);
  });

  it('rejects Joker lead', () => {
    const result = validatePlay('JO', ['JO', 'SA'], null, true);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('joker-cannot-lead');
  });

  it('allows Joker lead when only card in hand', () => {
    // Joker as sole card still can't lead — this triggers poison joker path in game-room
    const result = validatePlay('JO', ['JO'], null, true);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('joker-cannot-lead');
  });

  it('must follow led suit when able', () => {
    const result = validatePlay('HK', ['HK', 'SA'], 'spades', false);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('must-follow-suit');
  });

  it('allows any card when void in led suit', () => {
    expect(validatePlay('HK', ['HK', 'CA'], 'spades', false).valid).toBe(true);
  });

  it('allows Joker when following suit (exempt from must-follow)', () => {
    expect(validatePlay('JO', ['JO', 'SA'], 'spades', false).valid).toBe(true);
  });

  it('Kout first trick: must lead trump if have it', () => {
    const result = validatePlay('HA', ['HA', 'SA'], 'spades', true, 'spades', true, true);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('must-lead-trump');
  });

  it('Kout first trick: allows trump lead', () => {
    expect(validatePlay('SA', ['SA', 'HA'], 'spades', true, 'spades', true, true).valid).toBe(true);
  });

  it('Kout first trick: allows non-trump if no trump in hand', () => {
    expect(validatePlay('HA', ['HA', 'CA'], 'spades', true, 'spades', true, true).valid).toBe(true);
  });

  it('Kout non-first trick: no trump lead restriction', () => {
    expect(validatePlay('HA', ['HA', 'SA'], 'spades', true, 'spades', true, false).valid).toBe(true);
  });

  it('non-Kout: no trump lead restriction', () => {
    expect(validatePlay('HA', ['HA', 'SA'], 'spades', true, 'spades', false, true).valid).toBe(true);
  });

  it('no led suit (first play or Joker led): any card valid', () => {
    expect(validatePlay('HA', ['HA', 'SA'], null, false).valid).toBe(true);
  });
});

describe('detectPoisonJoker', () => {
  it('detects single Joker in hand', () => {
    expect(detectPoisonJoker(['JO'])).toBe(true);
  });

  it('returns false for Joker with other cards', () => {
    expect(detectPoisonJoker(['JO', 'SA'])).toBe(false);
  });

  it('returns false for single non-Joker', () => {
    expect(detectPoisonJoker(['SA'])).toBe(false);
  });

  it('returns false for empty hand', () => {
    expect(detectPoisonJoker([])).toBe(false);
  });
});
