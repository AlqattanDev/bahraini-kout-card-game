import { decodeCard } from '../card';
import type { SuitName, RankName } from '../types';

export interface HandStrength {
  personalTricks: number;
  strongestSuit: SuitName | null;
}

export type PartnerAction = 'unknown' | 'bid' | 'passed';

// Base trick probability for a card (no trump context).
function baseProbability(rank: RankName): number {
  switch (rank) {
    case 'ace': return 0.85;
    case 'king': return 0.65;
    case 'queen': return 0.35;
    case 'jack': return 0.15;
    default: return 0.05; // ten and below
  }
}

// Bonus added when the card is in the prospective trump suit.
function trumpBonus(rank: RankName): number {
  switch (rank) {
    case 'ace': return 0.15;
    case 'king': return 0.25;
    case 'queen': return 0.25;
    case 'jack': return 0.25;
    default: return 0.30; // ten and below
  }
}

function suitTextureBonus(bySuit: Map<SuitName, RankName[]>): number {
  let bonus = 0.0;
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

export function evaluateHand(hand: string[]): HandStrength {
  if (hand.length === 0) return { personalTricks: 0, strongestSuit: null };

  const bySuit = new Map<SuitName, RankName[]>();
  const suitCounts = new Map<SuitName, number>();
  let hasJoker = false;

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) { hasJoker = true; continue; }
    const suit = card.suit!;
    const rank = card.rank!;
    if (!bySuit.has(suit)) bySuit.set(suit, []);
    bySuit.get(suit)!.push(rank);
    suitCounts.set(suit, (suitCounts.get(suit) ?? 0) + 1);
  }

  let strongest: SuitName | null = null;
  let bestPotential = -1;
  for (const [suit, ranks] of bySuit) {
    const potential = ranks.reduce((s, r) => s + baseProbability(r), 0);
    if (potential > bestPotential) {
      bestPotential = potential;
      strongest = suit;
    }
  }

  let score = 0.0;

  if (hasJoker) score += 1.0; // guaranteed trick

  for (const [suit, ranks] of bySuit) {
    const isTrump = suit === strongest;
    for (const rank of ranks) {
      let cardScore = baseProbability(rank);
      if (isTrump) cardScore += trumpBonus(rank);
      score += cardScore;
    }
  }

  score += suitTextureBonus(bySuit);

  for (const count of suitCounts.values()) {
    if (count >= 4) score += (count - 3) * 0.1;
  }

  const hasTrump = strongest !== null && (suitCounts.get(strongest) ?? 0) > 0;
  for (const suit of ['spades', 'hearts', 'clubs', 'diamonds'] as SuitName[]) {
    if (bySuit.has(suit)) continue; // not void in this suit
    if (suit === strongest) continue; // void in own trump — no bonus
    score += hasTrump ? 1.0 : 0.1;
  }

  return {
    personalTricks: Math.max(0, Math.min(8, score)),
    strongestSuit: strongest,
  };
}

// Partner-contribution constants matching BotSettings in Dart.
const PARTNER_ESTIMATE_DEFAULT = 1.0;
const PARTNER_ESTIMATE_BID = 1.5;
const PARTNER_ESTIMATE_PASS = 0.5;

/** Partner-adjusted effective tricks, clamped to 0-8. */
export function effectiveTricks(
  strength: HandStrength,
  partnerAction: PartnerAction,
): number {
  const estimate = partnerAction === 'bid'
    ? PARTNER_ESTIMATE_BID
    : partnerAction === 'passed'
    ? PARTNER_ESTIMATE_PASS
    : PARTNER_ESTIMATE_DEFAULT;
  return Math.max(0, Math.min(8, strength.personalTricks + estimate));
}
