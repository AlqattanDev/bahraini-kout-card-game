import { TeamName, BID_FAILURE_POINTS } from '../game/types';

export const DEFAULT_DISCONNECT_PENALTY = 10;

export interface DisconnectCheckInput {
  uid: string;
  gameId: string;
  isPresent: boolean;
  hasBid: boolean;
  bidAmount?: number;
  playerTeam: TeamName;
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

export function evaluateDisconnect(input: DisconnectCheckInput): DisconnectOutcome {
  if (input.isPresent) {
    return { action: 'cancel', reason: 'reconnected' };
  }

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
