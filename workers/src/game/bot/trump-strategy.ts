import { decodeCard } from '../card';
import type { SuitName, RankName } from '../types';
import type { BotContext } from './types';

// Matching BotSettings in Dart.
const TRUMP_LENGTH_WEIGHT = 2.5;
const TRUMP_STRENGTH_WEIGHT = 0.45;

const HONOR_VALUES: Partial<Record<RankName, number>> = {
  ace: 3.0, king: 2.0, queen: 1.5, jack: 1.0,
};

function honorTiebreak(hand: string[], suit: SuitName): number {
  let s = 0;
  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker || card.suit !== suit) continue;
    if (card.rank === 'ace') s += 3.0;
    else if (card.rank === 'king') s += 2.0;
  }
  return s;
}

export function decideTrump(ctx: BotContext): SuitName {
  const hand = ctx.hand;
  const isKout = ctx.currentBid === 8;

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

  // Candidate suits must have >= 2 cards; fall back to all suits if none qualify.
  const validSuits = new Set<SuitName>();
  for (const [suit, count] of suitCounts) {
    if (count >= 2) validSuits.add(suit);
  }
  const candidates = validSuits.size > 0 ? validSuits : new Set(suitCounts.keys());

  // Weight selection: Kout inverts the ratio (honors matter more than length).
  const lengthWeight = isKout ? 1.5 : TRUMP_LENGTH_WEIGHT;
  const strengthWeight = isKout ? 2.0 : TRUMP_STRENGTH_WEIGHT;

  const scores = new Map<SuitName, number>();

  for (const suit of candidates) {
    const count = suitCounts.get(suit) ?? 0;
    const strength = suitStrength.get(suit) ?? 0;
    let score = count * lengthWeight + strength * strengthWeight;

    if (hasJoker && count >= 3) score += 1.0;

    // Side-suit honor bonus
    for (const code of hand) {
      const card = decodeCard(code);
      if (card.isJoker || card.suit === suit) continue;
      if (card.rank === 'ace') score += 0.9;
      else if (card.rank === 'king') score += 0.5;
    }

    // Void bonus
    for (const s of ['spades', 'hearts', 'clubs', 'diamonds'] as SuitName[]) {
      if (s !== suit && !suitCounts.has(s)) score += 0.5;
    }

    scores.set(suit, score);
  }

  if (scores.size === 0) return 'spades';

  const maxScore = Math.max(...scores.values());
  const epsilon = 0.5;
  const close: SuitName[] = [];
  for (const [suit, score] of scores) {
    if (maxScore - score <= epsilon) close.push(suit);
  }

  // Tiebreaker: when suits are within epsilon, prefer A/K honors then length.
  if (close.length >= 2) {
    close.sort((a, b) => {
      const tbDiff = honorTiebreak(hand, b) - honorTiebreak(hand, a);
      if (Math.abs(tbDiff) > 0.01) return tbDiff;
      return (suitCounts.get(b) ?? 0) - (suitCounts.get(a) ?? 0);
    });
    return close[0];
  }

  let bestSuit: SuitName = 'spades';
  let bestScore = -1;
  for (const [suit, score] of scores) {
    if (score > bestScore) { bestScore = score; bestSuit = suit; }
  }
  return bestSuit;
}
