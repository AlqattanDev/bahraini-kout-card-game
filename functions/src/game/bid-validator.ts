export interface BidValidationResult {
  valid: boolean;
  error?: string;
}

export interface BiddingCompleteResult {
  complete: boolean;
  winner?: string;
  bid?: number;
}

export type MalzoomOutcome = 'none' | 'reshuffle' | 'forcedBid';

/**
 * Validates a bid attempt.
 */
export function validateBid(
  bidAmount: number,
  currentHighest: number | null,
  passedPlayers: string[],
  playerId: string
): BidValidationResult {
  if (passedPlayers.includes(playerId)) {
    return { valid: false, error: 'already-passed' };
  }
  if (currentHighest !== null && bidAmount <= currentHighest) {
    return { valid: false, error: 'bid-not-higher' };
  }
  return { valid: true };
}

/**
 * Validates a pass attempt.
 */
export function validatePass(
  passedPlayers: string[],
  playerId: string
): BidValidationResult {
  if (passedPlayers.includes(playerId)) {
    return { valid: false, error: 'already-passed' };
  }
  return { valid: true };
}

/**
 * Checks whether bidding is complete (3 players passed with a winner).
 */
export function checkBiddingComplete(
  passedPlayers: string[],
  currentHighest: number | null,
  highestBidder: string | null
): BiddingCompleteResult {
  if (passedPlayers.length >= 3 && currentHighest !== null && highestBidder !== null) {
    return { complete: true, winner: highestBidder, bid: currentHighest };
  }
  return { complete: false };
}

/**
 * Checks for the malzoom condition (all 4 players passed).
 */
export function checkMalzoom(
  passedPlayers: string[],
  reshuffleCount: number
): MalzoomOutcome {
  if (passedPlayers.length < 4) return 'none';
  if (reshuffleCount < 1) return 'reshuffle';
  return 'forcedBid';
}
