import { decodeCard } from '../card';
import type { SuitName, RankName } from '../types';

const HONOR_VALUES: Partial<Record<RankName, number>> = {
  ace: 3.0, king: 2.0, queen: 1.5, jack: 1.0,
};

export function decideTrump(hand: string[], isForcedBid = false): SuitName {
  const suitCounts = new Map<SuitName, number>();
  const suitStrength = new Map<SuitName, number>();
  const hasJoker = hand.includes('JO');

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) continue;
    const suit = card.suit!;
    suitCounts.set(suit, (suitCounts.get(suit) ?? 0) + 1);
    const rankScore = HONOR_VALUES[card.rank!] ?? 0.5;
    suitStrength.set(suit, (suitStrength.get(suit) ?? 0) + rankScore);
  }

  if (isForcedBid) {
    let longest: SuitName = 'spades';
    let maxCount = 0;
    for (const [suit, count] of suitCounts) {
      if (count > maxCount) { maxCount = count; longest = suit; }
    }
    return longest;
  }

  const validSuits = new Set<SuitName>();
  for (const [suit, count] of suitCounts) {
    if (count >= 2) validSuits.add(suit);
  }
  const candidates = validSuits.size > 0 ? validSuits : new Set(suitCounts.keys());

  let bestSuit: SuitName = 'spades';
  let bestScore = -1;
  const lengthWeight = 2.0;
  const strengthWeight = 1.0;

  for (const suit of candidates) {
    const count = suitCounts.get(suit) ?? 0;
    const strength = suitStrength.get(suit) ?? 0;
    let score = count * lengthWeight + strength * strengthWeight;

    if (hasJoker && count >= 3) score += 1.0;

    for (const code of hand) {
      const card = decodeCard(code);
      if (card.isJoker || card.suit === suit) continue;
      if (card.rank === 'ace') score += 0.9;
      else if (card.rank === 'king') score += 0.5;
    }

    for (const s of ['spades', 'hearts', 'clubs', 'diamonds'] as SuitName[]) {
      if (s !== suit && !suitCounts.has(s)) score += 0.5;
    }

    if (score > bestScore) { bestScore = score; bestSuit = suit; }
  }

  return bestSuit;
}
