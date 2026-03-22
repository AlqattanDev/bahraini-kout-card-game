/**
 * Disconnect Handler
 *
 * Contains the logic for processing expired disconnect timers.
 * If the player reconnected within the grace period (presence doc exists),
 * the timer is cancelled. Otherwise the game is forfeited with a penalty.
 */

import { TeamName, BID_FAILURE_POINTS } from '../game/types';

export const DEFAULT_DISCONNECT_PENALTY = 10;

export interface DisconnectCheckInput {
  uid: string;
  gameId: string;
  /** Whether the player has an active presence document (i.e. reconnected). */
  isPresent: boolean;
  /** Whether the game currently has an active bid. */
  hasBid: boolean;
  /** The bid amount if a bid is active, otherwise undefined. */
  bidAmount?: number;
  /** The team of the disconnected player. */
  playerTeam: TeamName;
  /** Current scores at the time of the disconnect timer firing. */
  scores: Record<TeamName, number>;
}

export type DisconnectOutcome =
  | { action: 'cancel'; reason: 'reconnected' }
  | {
      action: 'forfeit';
      penaltyPoints: number;
      penaltyAgainstTeam: TeamName;
      winningTeam: TeamName;
      newScores: Record<TeamName, number>;
    };

/**
 * Evaluates what to do when a disconnect timer expires.
 *
 * - If the player reconnected → cancel the timer, no penalty.
 * - If still disconnected → forfeit:
 *     - If a bid is active: use BID_FAILURE_POINTS for that bid amount
 *     - Otherwise: DEFAULT_DISCONNECT_PENALTY (+10)
 *   The penalty is *added* to the opponent team's score.
 */
export function evaluateDisconnect(input: DisconnectCheckInput): DisconnectOutcome {
  if (input.isPresent) {
    return { action: 'cancel', reason: 'reconnected' };
  }

  // Player still disconnected — forfeit
  const penaltyAgainstTeam = input.playerTeam;
  const winningTeam: TeamName = penaltyAgainstTeam === 'teamA' ? 'teamB' : 'teamA';

  let penaltyPoints: number;
  if (input.hasBid && input.bidAmount !== undefined && BID_FAILURE_POINTS[input.bidAmount] !== undefined) {
    penaltyPoints = BID_FAILURE_POINTS[input.bidAmount];
  } else {
    penaltyPoints = DEFAULT_DISCONNECT_PENALTY;
  }

  const newScores: Record<TeamName, number> = {
    teamA: input.scores.teamA,
    teamB: input.scores.teamB,
  };
  newScores[winningTeam] = (newScores[winningTeam] ?? 0) + penaltyPoints;

  return {
    action: 'forfeit',
    penaltyPoints,
    penaltyAgainstTeam,
    winningTeam,
    newScores,
  };
}
