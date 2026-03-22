import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyScore,
  checkGameOver,
} from '../../src/game/scorer';

describe('calculateRoundResult', () => {
  test('bid 5 success (5+ tricks) → +5 to bidding team', () => {
    const result = calculateRoundResult(5, 'teamA', { teamA: 5, teamB: 3 });
    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(5);
  });

  test('bid 5 success with 8 tricks → still +5', () => {
    const result = calculateRoundResult(5, 'teamA', { teamA: 8, teamB: 0 });
    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(5);
  });

  test('bid 6 failure (4 tricks) → +12 to opponent', () => {
    const result = calculateRoundResult(6, 'teamA', { teamA: 4, teamB: 4 });
    expect(result.winningTeam).toBe('teamB');
    expect(result.points).toBe(12);
  });

  test('bid 7 failure (6 tricks) → +14 to opponent', () => {
    const result = calculateRoundResult(7, 'teamB', { teamA: 2, teamB: 6 });
    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(14);
  });

  test('kout success (8 tricks) → +31 to bidding team', () => {
    const result = calculateRoundResult(8, 'teamA', { teamA: 8, teamB: 0 });
    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(31);
  });

  test('kout failure (7 tricks) → +31 to opponent', () => {
    const result = calculateRoundResult(8, 'teamA', { teamA: 7, teamB: 1 });
    expect(result.winningTeam).toBe('teamB');
    expect(result.points).toBe(31);
  });
});

describe('calculatePoisonJokerResult', () => {
  test('poison joker → +10 to opponent of poison team', () => {
    const result = calculatePoisonJokerResult('teamB');
    // teamB holds the joker, teamA gets +10
    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(10);
  });
});

describe('applyScore', () => {
  test('adds points to winning team only, losing team unchanged', () => {
    const scores = applyScore({ teamA: 10, teamB: 5 }, 'teamA', 7);
    expect(scores.teamA).toBe(17);
    expect(scores.teamB).toBe(5);
  });

  test('scores clamp at 0 (never negative)', () => {
    const scores = applyScore({ teamA: 0, teamB: 0 }, 'teamA', 5);
    expect(scores.teamA).toBe(5);
    expect(scores.teamB).toBe(0);
  });
});

describe('checkGameOver', () => {
  test('game over when team reaches 31', () => {
    expect(checkGameOver({ teamA: 31, teamB: 10 })).toBe('teamA');
  });

  test('game over when team exceeds 31', () => {
    expect(checkGameOver({ teamA: 12, teamB: 35 })).toBe('teamB');
  });

  test('game not over below 31', () => {
    expect(checkGameOver({ teamA: 20, teamB: 30 })).toBeNull();
  });
});
