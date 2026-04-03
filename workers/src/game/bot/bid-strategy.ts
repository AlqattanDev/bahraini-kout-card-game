import { evaluateHand } from './hand-evaluator';
import { teamForSeat } from './types';
import type { BotContext } from './types';

export function decideBid(ctx: BotContext): { action: 'bid'; amount: number } | { action: 'pass' } {
  const strength = evaluateHand(ctx.hand);

  let thresholdAdjust = 0.0;

  // Score-aware threshold adjustment
  const my = ctx.scores[ctx.myTeam] ?? 0;
  const opp = ctx.scores[ctx.myTeam === 'teamA' ? 'teamB' : 'teamA'] ?? 0;
  if (my + 5 - opp >= 31) {
    thresholdAdjust += 1.0;
  } else if (my + 5 >= 31) {
    thresholdAdjust += 0.8;
  } else if (opp >= 25 && my <= 5) {
    thresholdAdjust += 1.0;
  } else if (my >= 26) {
    thresholdAdjust += 0.5;
  } else if (opp >= 26) {
    thresholdAdjust += 0.5;
  }

  // Position-aware bidding
  const actedBefore = ctx.bidHistory.length;
  if (actedBefore === 0) {
    thresholdAdjust -= 0.3;
  } else if (actedBefore === 2) {
    thresholdAdjust += 0.2;
  } else if (actedBefore >= 3) {
    thresholdAdjust += 0.3;
  }

  // Partner inference
  const partnerEntry = [...ctx.bidHistory].reverse().find(e => e.seat === ctx.partnerSeat);
  if (partnerEntry != null && partnerEntry.action !== 'pass') {
    thresholdAdjust += 0.3;
  } else if (partnerEntry?.action === 'pass') {
    thresholdAdjust -= 0.3;
  }

  const adjustedStrength = strength.expectedWinners + thresholdAdjust;
  const maxBid = strengthToBid(adjustedStrength);

  if (ctx.isForced) {
    const naturalBid = maxBid ?? 5;
    if (ctx.currentBid == null) return { action: 'bid', amount: naturalBid };
    for (const bid of [5, 6, 7, 8]) {
      if (bid > ctx.currentBid) return { action: 'bid', amount: bid };
    }
    return { action: 'bid', amount: 5 };
  }

  // Tactical overbidding: steal from opponent
  if (ctx.currentBid != null && ctx.bidHistory.length > 0) {
    const lastBidder = [...ctx.bidHistory].reverse().find(e => e.action !== 'pass');
    if (lastBidder != null) {
      const isOpponentBid = teamForSeat(lastBidder.seat) !== ctx.myTeam;
      if (isOpponentBid) {
        const nextBidValue = ctx.currentBid + 1;
        if (nextBidValue <= 8) {
          const nextThreshold = bidThreshold(nextBidValue);
          if (adjustedStrength > nextThreshold + 0.3) {
            return { action: 'bid', amount: nextBidValue };
          }
        }
      }
    }
  }

  if (maxBid == null) return { action: 'pass' };

  if (ctx.currentBid == null) return { action: 'bid', amount: maxBid };

  if (maxBid > ctx.currentBid) {
    for (const bid of [5, 6, 7, 8]) {
      if (bid > ctx.currentBid && bid <= maxBid) return { action: 'bid', amount: bid };
    }
  }

  return { action: 'pass' };
}

function strengthToBid(expectedWinners: number): number | null {
  if (expectedWinners >= 7.5) return 8;
  if (expectedWinners >= 6.5) return 7;
  if (expectedWinners >= 5.5) return 6;
  if (expectedWinners >= 4.5) return 5;
  return null;
}

function bidThreshold(bid: number): number {
  if (bid === 5) return 4.5;
  if (bid === 6) return 5.5;
  if (bid === 7) return 6.5;
  return 7.5;
}
