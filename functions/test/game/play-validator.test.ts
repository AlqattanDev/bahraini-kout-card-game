import { validatePlay, detectPoisonJoker } from '../../src/game/play-validator';

describe('validatePlay', () => {
  test('allows playing a card of the led suit', () => {
    const hand = ['HA', 'SK'];
    const result = validatePlay('HA', hand, 'hearts', false);
    expect(result.valid).toBe(true);
  });

  test('rejects off-suit when player has led suit', () => {
    const hand = ['HA', 'SK'];
    const result = validatePlay('SK', hand, 'hearts', false);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('must-follow-suit');
  });

  test('allows off-suit when void in led suit', () => {
    const hand = ['SK', 'CQ'];
    const result = validatePlay('SK', hand, 'hearts', false);
    expect(result.valid).toBe(true);
  });

  test('allows joker when void in led suit', () => {
    const hand = ['JO', 'SK'];
    const result = validatePlay('JO', hand, 'hearts', false);
    expect(result.valid).toBe(true);
  });

  test('rejects joker when player has led suit', () => {
    const hand = ['JO', 'H7'];
    const result = validatePlay('JO', hand, 'hearts', false);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('must-follow-suit');
  });

  test('rejects leading with joker', () => {
    const hand = ['JO', 'HA'];
    const result = validatePlay('JO', hand, null, true);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('cannot-lead-joker');
  });

  test('allows leading with any non-joker card', () => {
    const hand = ['HA', 'SK'];
    const result = validatePlay('HA', hand, null, true);
    expect(result.valid).toBe(true);
  });

  test('rejects card not in hand', () => {
    const hand = ['HA'];
    const result = validatePlay('SK', hand, null, true);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('card-not-in-hand');
  });
});

describe('detectPoisonJoker', () => {
  test('detects poison joker when only card is joker', () => {
    expect(detectPoisonJoker(['JO'])).toBe(true);
  });

  test('no poison joker with multiple cards', () => {
    expect(detectPoisonJoker(['JO', 'HA'])).toBe(false);
  });

  test('no poison joker when single card is not joker', () => {
    expect(detectPoisonJoker(['HA'])).toBe(false);
  });

  test('no poison joker with empty hand', () => {
    expect(detectPoisonJoker([])).toBe(false);
  });
});
