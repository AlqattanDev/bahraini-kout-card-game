export interface BidValidationResult {
  valid: boolean;
  error?: string;
}

export interface BiddingCompleteResult {
  complete: boolean;
  winner?: string;
  bid?: number;
}

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

export function isLastBidder(
  passedPlayers: string[],
  playerId: string,
  playerCount: number = 4
): boolean {
  if (passedPlayers.includes(playerId)) return false;
  const activePlayers = playerCount - passedPlayers.length;
  return activePlayers === 1;
}

export function validatePass(
  passedPlayers: string[],
  playerId: string,
  playerCount: number = 4,
  currentHighest: number | null = null
): BidValidationResult {
  if (passedPlayers.includes(playerId)) {
    return { valid: false, error: 'already-passed' };
  }
  if (isLastBidder(passedPlayers, playerId, playerCount) && currentHighest === null) {
    return { valid: false, error: 'must-bid' };
  }
  return { valid: true };
}

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
