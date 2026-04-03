import { decodeCard } from '../card';
import type { SuitName } from '../types';

export function decideTrump(hand: string[], isForcedBid: boolean): SuitName {
  const suitCounts = new Map<SuitName, number>();
  const suitStrength = new Map<SuitName, number>();

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) continue;
    const suit = card.suit!;
    suitCounts.set(suit, (suitCounts.get(suit) ?? 0) + 1);

    let rankScore = 0.0;
    if (card.rank === 'ace') rankScore = 3.0;
    else if (card.rank === 'king') rankScore = 2.0;
    else if (card.rank === 'queen') rankScore = 1.5;
    else if (card.rank === 'jack') rankScore = 1.0;
    else rankScore = 0.5;

    suitStrength.set(suit, (suitStrength.get(suit) ?? 0) + rankScore);
  }

  // Forced bid: just pick longest suit
  if (isForcedBid) {
    let longest: SuitName | null = null;
    let maxCount = 0;
    for (const [suit, count] of suitCounts) {
      if (count > maxCount) { maxCount = count; longest = suit; }
    }
    return longest ?? 'spades';
  }

  const validSuits = new Set<SuitName>(
    [...suitCounts.entries()].filter(([, v]) => v >= 2).map(([k]) => k)
  );
  const candidates = validSuits.size > 0 ? validSuits : new Set(suitCounts.keys());

  const hasJoker = hand.some(c => c === 'JO');
  const allSuits: SuitName[] = ['spades', 'hearts', 'clubs', 'diamonds'];

  let bestSuit: SuitName = 'spades';
  let bestScore = -1;

  for (const candidateSuit of candidates) {
    const count = suitCounts.get(candidateSuit) ?? 0;
    const strength = suitStrength.get(candidateSuit) ?? 0;

    let score = count * 2.0 + strength * 1.0;

    if (hasJoker && count >= 3) score += 1.0;

    // Side suit strength
    let sideStrength = 0.0;
    for (const code of hand) {
      const card = decodeCard(code);
      if (!card.isJoker && card.suit !== candidateSuit) {
        if (card.rank === 'ace') sideStrength += 0.9;
        else if (card.rank === 'king') sideStrength += 0.5;
      }
    }
    score += sideStrength;

    // Ruff value
    for (const suit of allSuits) {
      if (suit !== candidateSuit && !suitCounts.has(suit)) score += 0.5;
    }

    if (score > bestScore) { bestScore = score; bestSuit = candidateSuit; }
  }

  return bestSuit;
}
