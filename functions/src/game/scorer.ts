import { TeamName, BID_SUCCESS_POINTS, BID_FAILURE_POINTS, TARGET_SCORE, POISON_JOKER_PENALTY } from './types';

export interface RoundResult {
  winningTeam: TeamName;
  points: number;
}

/**
 * Calculates the result of a round based on bid and tricks won.
 */
export function calculateRoundResult(
  bid: number,
  biddingTeam: TeamName,
  tricksWon: Record<TeamName, number>
): RoundResult {
  const biddingTeamTricks = tricksWon[biddingTeam] ?? 0;
  const success = biddingTeamTricks >= bid;

  if (success) {
    return { winningTeam: biddingTeam, points: BID_SUCCESS_POINTS[bid] };
  } else {
    const opponent: TeamName = biddingTeam === 'teamA' ? 'teamB' : 'teamA';
    return { winningTeam: opponent, points: BID_FAILURE_POINTS[bid] };
  }
}

/**
 * Calculates the result when a poison joker is triggered.
 * The team that holds the joker at the end loses — the opponent always gains POISON_JOKER_PENALTY points.
 */
export function calculatePoisonJokerResult(
  poisonTeam: TeamName
): RoundResult {
  const opponent: TeamName = poisonTeam === 'teamA' ? 'teamB' : 'teamA';
  return { winningTeam: opponent, points: POISON_JOKER_PENALTY };
}

/**
 * Applies points to the winning team's score and returns new scores.
 */
export function applyScore(
  scores: Record<TeamName, number>,
  winningTeam: TeamName,
  points: number
): Record<TeamName, number> {
  const result: Record<TeamName, number> = { teamA: 0, teamB: 0 };
  const teams: TeamName[] = ['teamA', 'teamB'];
  for (const team of teams) {
    if (team === winningTeam) {
      result[team] = (scores[team] ?? 0) + points;
    } else {
      result[team] = Math.max(0, scores[team] ?? 0);
    }
  }
  return result;
}

/**
 * Checks if the game is over. Returns the winning team or null.
 */
export function checkGameOver(
  scores: Record<TeamName, number>
): TeamName | null {
  const teams: TeamName[] = ['teamA', 'teamB'];
  for (const team of teams) {
    if ((scores[team] ?? 0) >= TARGET_SCORE) return team;
  }
  return null;
}
