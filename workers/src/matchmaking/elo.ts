const K = 32;

export function expectedScore(playerElo: number, opponentElo: number): number {
  return 1 / (1 + Math.pow(10, (opponentElo - playerElo) / 400));
}

export function newElo(oldElo: number, expected: number, actual: number): number {
  return Math.round(oldElo + K * (actual - expected));
}

export function teamAverageElo(elos: number[]): number {
  return elos.reduce((a, b) => a + b, 0) / elos.length;
}
