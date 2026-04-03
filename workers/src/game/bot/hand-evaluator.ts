import { decodeCard } from '../card';
import type { SuitName, RankName } from '../types';

export function evaluateHand(hand: string[], trumpSuit?: SuitName): number {
  let score = 0;
  const bySuit = new Map<SuitName, RankName[]>();
  const suitCounts = new Map<SuitName, number>();

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) {
      score += 1.0;
      continue;
    }
    const suit = card.suit!;
    const ranks = bySuit.get(suit) ?? [];
    ranks.push(card.rank!);
    bySuit.set(suit, ranks);
    suitCounts.set(suit, (suitCounts.get(suit) ?? 0) + 1);
  }

  for (const [suit, ranks] of bySuit) {
    const isTrump = suit === trumpSuit;
    const count = ranks.length;

    for (const rank of ranks) {
      if (rank === 'ace') score += 0.9;
      else if (rank === 'king') score += count >= 3 ? 0.8 : 0.6;
      else if (rank === 'queen') score += count >= 3 ? 0.5 : 0.3;
      else if (rank === 'jack') score += 0.2;
      else if (rank === 'ten') score += 0.1;

      if (isTrump) {
        if (rank === 'ace') score += 0.5;
        else if (rank === 'king') score += 0.4;
        else if (rank === 'queen') score += 0.3;
        else if (rank === 'jack') score += 0.2;
        else score += 0.3;
      }
    }

    const hasAce = ranks.includes('ace');
    const hasKing = ranks.includes('king');
    const hasQueen = ranks.includes('queen');
    if (hasAce && hasKing && hasQueen) score += 0.5;
    else if (hasAce && hasKing) score += 0.3;
    else if (hasKing && hasQueen && !hasAce) score += 0.2;

    if (count >= 4) score += 0.3;
  }

  const hasAnyTrump = trumpSuit != null && bySuit.has(trumpSuit);
  for (const suit of ['spades', 'hearts', 'clubs', 'diamonds'] as SuitName[]) {
    if (!bySuit.has(suit)) {
      if (suit === trumpSuit) { /* no bonus */ }
      else if (hasAnyTrump) score += 0.3;
      else score += 0.1;
    }
  }

  return Math.max(0, Math.min(8, score));
}
