import { evaluateHand, effectiveTricks } from './hand-evaluator';
import type { PartnerAction } from './hand-evaluator';
import { decodeCard } from '../card';
import type { BotContext } from './types';
import type { SuitName, RankName } from '../types';
import { TARGET_SCORE } from '../types';

// effectiveTricks threshold per bid level
const THRESHOLDS: Record<number, number> = { 5: 5.0, 6: 6.0, 7: 7.0, 8: 8.0 };

export function decideBid(ctx: BotContext): { action: 'bid'; amount: number } | { action: 'pass' } {
  const hand = ctx.hand;
  const strength = evaluateHand(hand);

  const partnerAction = getPartnerAction(ctx.mySeat, ctx.bidHistory);
  const et = effectiveTricks(strength, partnerAction);

  const opponentTeam = ctx.myTeam === 'teamA' ? 'teamB' : 'teamA';
  const oppScore = ctx.scores[opponentTeam] ?? 0;
  const desperationOffset = oppScore >= TARGET_SCORE - 10 ? 1.0 : 0.0;
  const adjustedET = et + desperationOffset;

  const thresholdBid = computeThresholdBid(adjustedET);

  const shapeFloor = computeShapeFloor(hand);

  let ceiling = maxBid(thresholdBid, shapeFloor);
  ceiling = applyGates(ceiling, hand, adjustedET);

  if (ctx.isForced) {
    return forcedBid(ceiling, ctx.currentBid);
  }

  if (partnerAction === 'bid' && ceiling !== 8) {
    return { action: 'pass' };
  }

  if (ceiling === null || ceiling === undefined) {
    return { action: 'pass' };
  }

  if (ctx.currentBid == null) {
    return { action: 'bid', amount: ceiling };
  }

  const nextBid = ctx.currentBid < 8 ? ctx.currentBid + 1 : null;
  if (nextBid === null) return { action: 'pass' }; // can't outbid Kout

  const isOpponentBid = checkIsOpponentBid(ctx.myTeam, ctx.bidHistory);

  if (isOpponentBid) {
    if (adjustedET >= nextBid && nextBid <= ceiling) {
      return { action: 'bid', amount: nextBid };
    }
    return { action: 'pass' };
  }

  if (nextBid <= ceiling) {
    return { action: 'bid', amount: nextBid };
  }

  return { action: 'pass' };
}

function getPartnerAction(mySeat: number, bidHistory: Array<{ seat: number; action: string }>): PartnerAction {
  const partnerSeat = (mySeat + 2) % 4;
  const entry = [...bidHistory].reverse().find(e => e.seat === partnerSeat);
  if (!entry) return 'unknown';
  return entry.action === 'pass' ? 'passed' : 'bid';
}

function computeThresholdBid(adjustedET: number): number | null {
  let best: number | null = null;
  for (const [bid, threshold] of Object.entries(THRESHOLDS)) {
    if (adjustedET >= threshold) {
      const level = Number(bid);
      if (best === null || level > best) best = level;
    }
  }
  return best;
}

function computeShapeFloor(hand: string[]): number | null {
  const bySuit = new Map<SuitName, RankName[]>();
  let hasJoker = false;

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) { hasJoker = true; continue; }
    const suit = card.suit!;
    if (!bySuit.has(suit)) bySuit.set(suit, []);
    bySuit.get(suit)!.push(card.rank!);
  }

  let best: number | null = null;

  for (const [, ranks] of bySuit) {
    const len = ranks.length;
    const hasA = ranks.includes('ace');
    const hasK = ranks.includes('king');
    const hasQ = ranks.includes('queen');
    const akq = hasA && hasK && hasQ;

    let floor: number | null = null;
    if (len >= 7 && hasJoker) floor = 8;
    else if (len >= 7) floor = 7;
    else if (len >= 6 && hasJoker && akq) floor = 8;
    else if (len >= 6 && hasJoker) floor = 7;
    else if (len >= 6) floor = 6;
    else if (len >= 5 && hasJoker) floor = 6;
    else if (len >= 5) floor = 5;

    best = maxBid(best, floor);
  }

  return best;
}

function applyGates(ceiling: number | null, hand: string[], adjustedET: number): number | null {
  if (ceiling === null) return null;

  // Kout gate
  if (ceiling === 8 && !passesKoutGate(hand, adjustedET)) {
    ceiling = 7;
  }

  // Seven gate
  if (ceiling === 7 && !passesSevenGate(hand)) {
    ceiling = 6;
  }

  return ceiling;
}

function passesSevenGate(hand: string[]): boolean {
  const bySuit = new Map<SuitName, RankName[]>();
  let hasJoker = false;

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) { hasJoker = true; continue; }
    const suit = card.suit!;
    if (!bySuit.has(suit)) bySuit.set(suit, []);
    bySuit.get(suit)!.push(card.rank!);
  }

  for (const ranks of bySuit.values()) {
    if (ranks.length >= 6) return true;
  }

  if (hasJoker) {
    // Joker + 5+ cards in a suit with A-K
    for (const ranks of bySuit.values()) {
      if (ranks.length >= 5 && ranks.includes('ace') && ranks.includes('king')) {
        return true;
      }
    }
    // 3+ Aces + Joker
    let aceCount = 0;
    for (const ranks of bySuit.values()) {
      aceCount += ranks.filter(r => r === 'ace').length;
    }
    if (aceCount >= 3) return true;
  }

  return false;
}

function passesKoutGate(hand: string[], adjustedET: number): boolean {
  const bySuit = new Map<SuitName, RankName[]>();
  let hasJoker = false;

  for (const code of hand) {
    const card = decodeCard(code);
    if (card.isJoker) { hasJoker = true; continue; }
    const suit = card.suit!;
    if (!bySuit.has(suit)) bySuit.set(suit, []);
    bySuit.get(suit)!.push(card.rank!);
  }

  let aceCount = 0;
  for (const ranks of bySuit.values()) {
    aceCount += ranks.filter(r => r === 'ace').length;
  }

  for (const ranks of bySuit.values()) {
    if (ranks.length >= 7) return true;
  }

  if (hasJoker) {
    for (const ranks of bySuit.values()) {
      // Joker + 6+ cards + AKQ block
      if (ranks.length >= 6 && ranks.includes('ace') && ranks.includes('king') && ranks.includes('queen')) {
        return true;
      }
      // Joker + 5+ cards + 3 Aces
      if (ranks.length >= 5 && aceCount >= 3) return true;
    }
  }

  if (adjustedET >= 7.6) return true;

  return false;
}

function forcedBid(ceiling: number | null, currentBid: number | undefined): { action: 'bid'; amount: number } {
  const naturalBid = ceiling ?? 5;
  if (currentBid == null) return { action: 'bid', amount: naturalBid };

  const nextBid = currentBid < 8 ? currentBid + 1 : null;
  if (nextBid !== null && ceiling !== null && nextBid <= ceiling) {
    return { action: 'bid', amount: nextBid };
  }
  if (nextBid !== null) return { action: 'bid', amount: nextBid };
  // currentBid is already 8 (Kout) — forced player must still bid above it,
  // but there is no valid bid above 8. This shouldn't happen in practice
  // because Kout ends bidding immediately, but defend against it.
  return { action: 'bid', amount: 8 };
}

function maxBid(a: number | null, b: number | null): number | null {
  if (a === null) return b;
  if (b === null) return a;
  return a >= b ? a : b;
}

function checkIsOpponentBid(
  myTeam: string,
  bidHistory: Array<{ seat: number; action: string }>,
): boolean {
  const lastBidder = [...bidHistory].reverse().find(e => e.action !== 'pass');
  if (!lastBidder) return false;
  const lastBidderTeam = lastBidder.seat % 2 === 0 ? 'teamA' : 'teamB';
  return lastBidderTeam !== myTeam;
}
