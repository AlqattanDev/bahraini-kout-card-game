import { resolveTrick } from '../../src/game/trick-resolver';
import { TrickPlay } from '../../src/game/types';

describe('resolveTrick', () => {
  test('highest card of led suit wins (no trump, no joker)', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'H9' },
      { player: 'p1', card: 'HK' },
      { player: 'p2', card: 'H7' },
      { player: 'p3', card: 'HA' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('p3');
  });

  test('off-suit cards lose to led suit', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'H7' },
      { player: 'p1', card: 'CA' },
      { player: 'p2', card: 'DA' },
      { player: 'p3', card: 'H8' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('p3');
  });

  test('trump beats led suit', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'p1', card: 'S7' },
      { player: 'p2', card: 'HK' },
      { player: 'p3', card: 'HQ' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('p1');
  });

  test('highest trump wins when multiple trumps played', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'p1', card: 'S7' },
      { player: 'p2', card: 'SJ' },
      { player: 'p3', card: 'HK' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('p2');
  });

  test('joker always wins', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'p1', card: 'SA' },
      { player: 'p2', card: 'JO' },
      { player: 'p3', card: 'HK' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('p2');
  });

  test('joker beats trump ace', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'SA' },
      { player: 'p1', card: 'JO' },
      { player: 'p2', card: 'SK' },
      { player: 'p3', card: 'SQ' },
    ];
    expect(resolveTrick(plays, 'spades', 'spades')).toBe('p1');
  });

  test('when trump is led, highest trump wins (no joker)', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'S9' },
      { player: 'p1', card: 'SA' },
      { player: 'p2', card: 'HA' },
      { player: 'p3', card: 'S10' },
    ];
    expect(resolveTrick(plays, 'spades', 'spades')).toBe('p1');
  });
});
