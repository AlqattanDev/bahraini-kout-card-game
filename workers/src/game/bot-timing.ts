/**
 * Mirrors lib/shared/constants/timing.dart GameTiming.botThinkingDelay
 * so online bot pacing matches offline.
 */
export function botThinkingDelayMs(opts: {
  phase: 'bidding' | 'trump' | 'playing';
  isForcedBid?: boolean;
  bidAmount?: number;
  legalMoves?: number;
  trickNumber?: number;
}): number {
  const rng = (min: number, max: number) =>
    min + Math.floor(Math.random() * (max - min + 1));

  if (opts.phase === 'bidding') {
    if (opts.isForcedBid) return rng(1000, 2000);
    return rng(1500, 2500);
  }
  if (opts.phase === 'trump') {
    const a = opts.bidAmount;
    if (a === 7 || a === 8) return rng(2500, 4000);
    return rng(1500, 2500);
  }
  const legal = opts.legalMoves ?? 1;
  const trick = opts.trickNumber ?? 1;
  if (legal === 1) return rng(500, 1000);
  if (trick >= 7) return rng(2000, 4000);
  return rng(1500, 3500);
}

/** Same duration as GameTiming.dealDelay (300ms). */
export const DEAL_DELAY_MS = 300;

/** Same as GameTiming.humanTurnTimeout (15s). */
export const HUMAN_TURN_TIMEOUT_MS = 15_000;
