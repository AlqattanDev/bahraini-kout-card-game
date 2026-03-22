import { expectedScore, newElo, teamAverageElo } from '../../src/matchmaking/elo';

describe('expectedScore', () => {
  it('returns 0.5 when both players have equal ELO', () => {
    expect(expectedScore(1200, 1200)).toBeCloseTo(0.5);
  });

  it('returns > 0.5 for a higher-rated player', () => {
    expect(expectedScore(1400, 1200)).toBeGreaterThan(0.5);
  });

  it('returns < 0.5 for a lower-rated player', () => {
    expect(expectedScore(1000, 1200)).toBeLessThan(0.5);
  });

  it('matches the standard formula: 1 / (1 + 10^((opp-player)/400))', () => {
    const player = 1500;
    const opp = 1300;
    const expected = 1 / (1 + Math.pow(10, (opp - player) / 400));
    expect(expectedScore(player, opp)).toBeCloseTo(expected, 10);
  });
});

describe('newElo', () => {
  it('uses K=32 — gain 32 points for unexpected win (expected 0)', () => {
    // If player was expected to score 0 and won (actual=1), gain = 32 * (1 - 0) = 32
    expect(newElo(1000, 0, 1)).toBe(1032);
  });

  it('loses 32 points for unexpected loss (expected 1)', () => {
    expect(newElo(1000, 1, 0)).toBe(968);
  });

  it('no change when result matches expectation exactly', () => {
    expect(newElo(1000, 0.5, 0.5)).toBe(1000);
  });

  it('rounds to nearest integer', () => {
    // 1200, expected ~0.76, actual 1: gain = 32 * (1 - 0.76) ≈ 7.68 → rounded
    const exp = expectedScore(1200, 1400);
    const result = newElo(1200, exp, 1);
    expect(Number.isInteger(result)).toBe(true);
  });

  it('applies K=32 correctly for a typical scenario', () => {
    // Player 1200 vs 1200: expected = 0.5, win (actual = 1)
    // new = 1200 + 32 * (1 - 0.5) = 1200 + 16 = 1216
    expect(newElo(1200, 0.5, 1)).toBe(1216);
  });
});

describe('teamAverageElo', () => {
  it('computes the arithmetic mean', () => {
    expect(teamAverageElo([1000, 1200])).toBe(1100);
  });

  it('works for a single player', () => {
    expect(teamAverageElo([1400])).toBe(1400);
  });

  it('works for four players', () => {
    expect(teamAverageElo([1000, 1100, 1200, 1300])).toBe(1150);
  });
});
