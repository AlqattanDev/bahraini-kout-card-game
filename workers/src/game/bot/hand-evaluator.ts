import { decodeCard } from '../card';
import type { SuitName, RankName } from '../types';

export interface HandStrength {
  expectedWinners: number;
  strongestSuit: SuitName | null;
}

export function evaluateHand(hand: string[], trumpSuit?: SuitName): number {
  const result = evaluateHandFull(hand, trumpSuit);
  return result.expectedWinners;
}

export function evaluateHandFull(hand: string[], trumpSuit?: SuitName): HandStrength {
  let score = 0.0;
  const suitCounts = new Map<SuitName, number>();
  const suitStrength = new Map<SuitName, number>();

  // Count suits
  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) continue;
    const suit = card.suit!;
    suitCounts.set(suit, (suitCounts.get(suit) ?? 0) + 1);
  }

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) {
      score += 1.0; // Guaranteed winner
      continue;
    }

    const suit = card.suit!;
    const rank = card.rank!;
    const count = suitCounts.get(suit) ?? 0;
    let cardScore = 0.0;

    // Honor valuation
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

    // Trump honor bonus
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

  // Suit texture bonus
  score += suitTextureBonus(hand);

  // Long suit bonus
  for (const count of suitCounts.values()) {
    if (count >= 4) score += 0.3;
  }

  // Void and ruffing potential
  const hasAnyTrump = trumpSuit != null && hand.some(code => {
    const card = decodeCard(code);
    return !card.isJoker && card.suit === trumpSuit;
  });

  for (const suit of ['spades', 'hearts', 'clubs', 'diamonds'] as SuitName[]) {
    if (!suitCounts.has(suit)) {
      if (suit === trumpSuit) {
        // Void in trump: bad. No bonus.
      } else if (hasAnyTrump) {
        score += 0.3; // ruffing potential
      } else {
        score += 0.1; // void but no trump
      }
    }
  }

  // Find strongest suit
  let strongest: SuitName | null = null;
  let bestStrength = -1;
  for (const [suit, strength] of suitStrength) {
    const combined = strength + (suitCounts.get(suit) ?? 0) * 0.1;
    if (combined > bestStrength) {
      bestStrength = combined;
      strongest = suit;
    }
  }

  return {
    expectedWinners: Math.min(Math.max(score, 0.0), 8.0),
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
    if (hasAce && hasKing && hasQueen) {
      bonus += 0.5;
    } else if (hasAce && hasKing) {
      bonus += 0.3;
    } else if (hasKing && hasQueen && !hasAce) {
      bonus += 0.2;
    }
  }
  return bonus;
}
