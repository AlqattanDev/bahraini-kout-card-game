import { decodeCard } from '../card';
import { RANK_VALUES } from '../types';
import type { SuitName, RankName } from '../types';

export interface HandStrength {
  expectedWinners: number;
  strongestSuit: SuitName | null;
}

export function evaluateHand(hand: string[], trumpSuit?: SuitName): HandStrength {
  let score = 0.0;
  const suitCounts = new Map<SuitName, number>();
  const suitStrength = new Map<SuitName, number>();

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) continue;
    const suit = card.suit!;
    suitCounts.set(suit, (suitCounts.get(suit) ?? 0) + 1);
  }

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) {
      score += 1.0;
      continue;
    }
    const suit = card.suit!;
    const rank = card.rank!;
    const count = suitCounts.get(suit) ?? 0;
    let cardScore = 0.0;

    if (rank === 'ace') {
      cardScore = 0.9;
    } else if (rank === 'king') {
      cardScore = count >= 3 ? 0.8 : 0.6;
    } else if (rank === 'queen') {
      cardScore = count >= 3 ? 0.5 : 0.3;
    } else if (rank === 'jack') {
      cardScore = 0.2;
    } else if (rank === 'ten') {
      cardScore = 0.1;
    }

    if (trumpSuit != null && suit === trumpSuit) {
      if (rank === 'ace') cardScore += 0.5;
      else if (rank === 'king') cardScore += 0.4;
      else if (rank === 'queen') cardScore += 0.3;
      else if (rank === 'jack') cardScore += 0.2;
      else cardScore += 0.3;
    }

    score += cardScore;
    suitStrength.set(suit, (suitStrength.get(suit) ?? 0) + cardScore);
  }

  score += suitTextureBonus(hand);

  for (const [, count] of suitCounts) {
    if (count >= 4) score += 0.3;
  }

  const hasAnyTrump = trumpSuit != null &&
    hand.some(c => { const d = decodeCard(c); return !d.isJoker && d.suit === trumpSuit; });

  const allSuits: SuitName[] = ['spades', 'hearts', 'clubs', 'diamonds'];
  for (const suit of allSuits) {
    if (!suitCounts.has(suit)) {
      if (suit === trumpSuit) {
        // void in trump: no bonus
      } else if (hasAnyTrump) {
        score += 0.3;
      } else {
        score += 0.1;
      }
    }
  }

  let strongest: SuitName | null = null;
  let bestStrength = -1;
  for (const [suit, str] of suitStrength) {
    const combined = str + (suitCounts.get(suit) ?? 0) * 0.1;
    if (combined > bestStrength) {
      bestStrength = combined;
      strongest = suit;
    }
  }

  return {
    expectedWinners: Math.min(Math.max(score, 0), 8.0),
    strongestSuit: strongest,
  };
}

function suitTextureBonus(hand: string[]): number {
  let bonus = 0.0;
  const bySuit = new Map<SuitName, RankName[]>();
  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) continue;
    const suit = card.suit!;
    if (!bySuit.has(suit)) bySuit.set(suit, []);
    bySuit.get(suit)!.push(card.rank!);
  }
  for (const ranks of bySuit.values()) {
    const hasAce = ranks.includes('ace');
    const hasKing = ranks.includes('king');
    const hasQueen = ranks.includes('queen');
    if (hasAce && hasKing && hasQueen) bonus += 0.5;
    else if (hasAce && hasKing) bonus += 0.3;
    else if (hasKing && hasQueen && !hasAce) bonus += 0.2;
  }
  return bonus;
}
