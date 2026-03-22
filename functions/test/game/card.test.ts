import { makeCard, makeJoker, encodeCard, decodeCard } from '../../src/game/card';

describe('encodeCard', () => {
  test('encodes SA (Ace of Spades)', () => {
    expect(encodeCard(makeCard('spades', 'ace'))).toBe('SA');
  });

  test('encodes HK (King of Hearts)', () => {
    expect(encodeCard(makeCard('hearts', 'king'))).toBe('HK');
  });

  test('encodes D10 (Ten of Diamonds)', () => {
    expect(encodeCard(makeCard('diamonds', 'ten'))).toBe('D10');
  });

  test('encodes C7 (Seven of Clubs)', () => {
    expect(encodeCard(makeCard('clubs', 'seven'))).toBe('C7');
  });

  test('encodes JO (Joker)', () => {
    expect(encodeCard(makeJoker())).toBe('JO');
  });
});

describe('decodeCard', () => {
  test('decodes SA to Ace of Spades', () => {
    const card = decodeCard('SA');
    expect(card.suit).toBe('spades');
    expect(card.rank).toBe('ace');
    expect(card.isJoker).toBe(false);
  });

  test('decodes HK to King of Hearts', () => {
    const card = decodeCard('HK');
    expect(card.suit).toBe('hearts');
    expect(card.rank).toBe('king');
  });

  test('decodes D10 to Ten of Diamonds', () => {
    const card = decodeCard('D10');
    expect(card.suit).toBe('diamonds');
    expect(card.rank).toBe('ten');
  });

  test('decodes C7 to Seven of Clubs', () => {
    const card = decodeCard('C7');
    expect(card.suit).toBe('clubs');
    expect(card.rank).toBe('seven');
  });

  test('decodes JO to Joker', () => {
    const card = decodeCard('JO');
    expect(card.isJoker).toBe(true);
    expect(card.suit).toBeNull();
    expect(card.rank).toBeNull();
  });

  test('throws on invalid encoding', () => {
    expect(() => decodeCard('XX')).toThrow('Invalid card encoding: XX');
  });
});

describe('roundtrip encode/decode', () => {
  const suits = ['spades', 'hearts', 'clubs', 'diamonds'] as const;
  const ranks = ['ace', 'king', 'queen', 'jack', 'ten', 'nine', 'eight', 'seven'] as const;

  test('encode then decode returns equivalent card for all regular cards', () => {
    for (const suit of suits) {
      for (const rank of ranks) {
        const original = makeCard(suit, rank);
        const roundtripped = decodeCard(encodeCard(original));
        expect(roundtripped.suit).toBe(original.suit);
        expect(roundtripped.rank).toBe(original.rank);
        expect(roundtripped.isJoker).toBe(false);
      }
    }
  });

  test('encode then decode returns equivalent joker', () => {
    const joker = makeJoker();
    const roundtripped = decodeCard(encodeCard(joker));
    expect(roundtripped.isJoker).toBe(true);
    expect(roundtripped.suit).toBeNull();
    expect(roundtripped.rank).toBeNull();
  });
});
