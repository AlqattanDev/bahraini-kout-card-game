import { TeamName, BID_SUCCESS_POINTS, BID_FAILURE_POINTS, TARGET_SCORE, TRICKS_PER_ROUND } from './types';

export interface RoundResult {
  winningTeam: TeamName;
  points: number;
}

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

export function calculatePoisonJokerResult(
  poisonTeam: TeamName
): RoundResult {
  const opponent: TeamName = poisonTeam === 'teamA' ? 'teamB' : 'teamA';
  // Poison joker = instant game loss; points field unused (applyPoisonJoker handles scoring).
  return { winningTeam: opponent, points: 0 };
}

/** Poison Joker instant loss: uses the same mechanism as Kout — sets opponent to TARGET_SCORE. */
export function applyPoisonJoker(poisonTeam: TeamName): Record<TeamName, number> {
  const opponent: TeamName = poisonTeam === 'teamA' ? 'teamB' : 'teamA';
  return applyKout(opponent);
}

/** Tug-of-war scoring: points reduce opponent's score first, remainder goes to winner. */
export function applyScore(
  scores: Record<TeamName, number>,
  winningTeam: TeamName,
  points: number
): Record<TeamName, number> {
  const losingTeam: TeamName = winningTeam === 'teamA' ? 'teamB' : 'teamA';
  const net = (scores[winningTeam] ?? 0) + points - (scores[losingTeam] ?? 0);
  if (net >= 0) {
    return { [winningTeam]: net, [losingTeam]: 0 } as Record<TeamName, number>;
  } else {
    return { [winningTeam]: 0, [losingTeam]: -net } as Record<TeamName, number>;
  }
}

/** Kout instant win: sets winning team to 31 regardless of current score. */
export function applyKout(winningTeam: TeamName): Record<TeamName, number> {
  const losingTeam: TeamName = winningTeam === 'teamA' ? 'teamB' : 'teamA';
  return { [winningTeam]: TARGET_SCORE, [losingTeam]: 0 } as Record<TeamName, number>;
}

export function checkGameOver(
  scores: Record<TeamName, number>
): TeamName | null {
  const teams: TeamName[] = ['teamA', 'teamB'];
  for (const team of teams) {
    if ((scores[team] ?? 0) >= TARGET_SCORE) return team;
  }
  return null;
}

/** Returns true when the round outcome is mathematically decided. */
export function isRoundDecided(
  bid: number,
  biddingTeam: TeamName,
  tricksWon: Record<TeamName, number>
): boolean {
  const bidderTricks = tricksWon[biddingTeam] ?? 0;
  const opponent: TeamName = biddingTeam === 'teamA' ? 'teamB' : 'teamA';
  const opponentTricks = tricksWon[opponent] ?? 0;
  return bidderTricks >= bid || opponentTricks > TRICKS_PER_ROUND - bid;
}
