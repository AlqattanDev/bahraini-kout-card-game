import { evaluateHand } from './hand-evaluator';
import type { BotContext } from './types';
import type { TeamName } from '../types';

export function decideBid(ctx: BotContext): { action: 'bid'; amount: number } | { action: 'pass' } {
  const strength = evaluateHand(ctx.hand);

  const myScore = ctx.scores[ctx.myTeam];
  const oppScore = ctx.scores[ctx.myTeam === 'teamA' ? 'teamB' : 'teamA'];
  let thresholdAdjust = 0;

  if (myScore + 5 - oppScore >= 31) thresholdAdjust += 1.0;
  else if (myScore + 5 >= 31) thresholdAdjust += 0.8;
  else if (oppScore >= 25 && myScore <= 5) thresholdAdjust += 1.0;
  else if (myScore >= 26) thresholdAdjust += 0.5;
  else if (oppScore >= 26) thresholdAdjust += 0.5;

  const acted = ctx.bidHistory.length;
  if (acted === 0) thresholdAdjust -= 0.3;
  else if (acted >= 2) thresholdAdjust += 0.2;
  else if (acted >= 3) thresholdAdjust += 0.3;

  const partnerEntry = ctx.bidHistory.find(e => e.seat === ctx.partnerSeat);
  if (partnerEntry && partnerEntry.action !== 'pass') thresholdAdjust += 0.3;
  else if (partnerEntry?.action === 'pass') thresholdAdjust -= 0.3;

  const adjustedStrength = strength + thresholdAdjust;

  if (ctx.isForced) {
    const amount = strengthToBid(adjustedStrength) ?? 5;
    if (!ctx.currentBid) return { action: 'bid', amount };
    for (const b of [5, 6, 7, 8]) {
      if (b > ctx.currentBid) return { action: 'bid', amount: b };
    }
    return { action: 'bid', amount: 5 };
  }

  if (ctx.currentBid != null && ctx.bidHistory.length > 0) {
    const lastBidder = [...ctx.bidHistory].reverse().find(e => e.action !== 'pass');
    if (lastBidder) {
      const lastBidderTeam: TeamName = lastBidder.seat % 2 === 0 ? 'teamA' : 'teamB';
      if (lastBidderTeam !== ctx.myTeam) {
        const nextBid = ctx.currentBid + 1;
        if (nextBid <= 8) {
          const threshold = bidThreshold(nextBid);
          if (adjustedStrength > threshold + 0.3) {
            return { action: 'bid', amount: nextBid };
          }
        }
      }
    }
  }

  const maxBid = strengthToBid(adjustedStrength);
  if (maxBid == null) return { action: 'pass' };
  if (!ctx.currentBid) return { action: 'bid', amount: maxBid };

  for (const b of [5, 6, 7, 8]) {
    if (b > ctx.currentBid && b <= maxBid) return { action: 'bid', amount: b };
  }

  return { action: 'pass' };
}

function strengthToBid(s: number): number | null {
  if (s >= 7.5) return 8;
  if (s >= 6.5) return 7;
  if (s >= 5.5) return 6;
  if (s >= 4.5) return 5;
  return null;
}

function bidThreshold(bid: number): number {
  const thresholds: Record<number, number> = { 5: 4.5, 6: 5.5, 7: 6.5, 8: 7.5 };
  return thresholds[bid] ?? 4.5;
}
