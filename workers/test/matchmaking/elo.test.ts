import { describe, it, expect } from "vitest";
import { expectedScore, newElo, teamAverageElo } from "../../src/matchmaking/elo";

describe("expectedScore", () => {
  it("returns 0.5 for equal ELO", () => {
    expect(expectedScore(1000, 1000)).toBe(0.5);
  });

  it("returns higher expectation for stronger player", () => {
    const strong = expectedScore(1200, 1000);
    const weak = expectedScore(1000, 1200);
    expect(strong).toBeGreaterThan(0.5);
    expect(weak).toBeLessThan(0.5);
  });

  it("expected scores of opponents sum to 1", () => {
    const eA = expectedScore(1200, 1000);
    const eB = expectedScore(1000, 1200);
    expect(eA + eB).toBeCloseTo(1, 10);
  });

  it("400 ELO difference gives ~0.91 expected score", () => {
    const e = expectedScore(1400, 1000);
    expect(e).toBeCloseTo(1 / (1 + Math.pow(10, -1)), 5);
    // 1 / (1 + 0.1) ≈ 0.9091
    expect(e).toBeCloseTo(0.9091, 3);
  });
});

describe("newElo", () => {
  it("winner gains rating when winning against equal opponent", () => {
    const result = newElo(1000, 0.5, 1);
    // K * (1 - 0.5) = 32 * 0.5 = 16
    expect(result).toBe(1016);
  });

  it("loser loses rating when losing against equal opponent", () => {
    const result = newElo(1000, 0.5, 0);
    // K * (0 - 0.5) = 32 * -0.5 = -16
    expect(result).toBe(984);
  });

  it("gains less for expected wins", () => {
    // Strong player (high expected score) beats weak player
    const expected = expectedScore(1400, 1000); // ~0.91
    const gain = newElo(1400, expected, 1);
    // K * (1 - 0.91) ≈ 32 * 0.09 ≈ 3
    expect(gain).toBe(1400 + Math.round(32 * (1 - expected)));
    expect(gain - 1400).toBeLessThan(16); // less than equal-match gain
  });

  it("loses more for unexpected losses", () => {
    // Strong player loses to weak player
    const expected = expectedScore(1400, 1000); // ~0.91
    const loss = newElo(1400, expected, 0);
    // K * (0 - 0.91) ≈ 32 * -0.91 ≈ -29
    expect(loss).toBeLessThan(1400);
    expect(1400 - loss).toBeGreaterThan(16); // more than equal-match loss
  });

  it("zero-sum: winner gain equals loser loss for equal ELOs", () => {
    const winnerNew = newElo(1000, 0.5, 1);
    const loserNew = newElo(1000, 0.5, 0);
    expect(winnerNew - 1000).toBe(1000 - loserNew);
  });
});

describe("teamAverageElo", () => {
  it("returns single player's ELO for solo team", () => {
    expect(teamAverageElo([1200])).toBe(1200);
  });

  it("returns average for two players", () => {
    expect(teamAverageElo([1000, 1200])).toBe(1100);
  });

  it("handles uneven ELOs", () => {
    expect(teamAverageElo([800, 1400])).toBe(1100);
  });
});

describe("ELO integration: full game scenario", () => {
  it("calculates correct ELO changes for a team game", () => {
    // teamA: [1000, 1000], teamB: [1000, 1000], teamA wins
    const teamAAvg = teamAverageElo([1000, 1000]);
    const teamBAvg = teamAverageElo([1000, 1000]);

    const teamAExpected = expectedScore(teamAAvg, teamBAvg);
    const teamBExpected = expectedScore(teamBAvg, teamAAvg);

    // Equal teams: expected = 0.5 each
    expect(teamAExpected).toBe(0.5);
    expect(teamBExpected).toBe(0.5);

    // teamA wins (actual = 1), teamB loses (actual = 0)
    const winnerNew = newElo(1000, teamAExpected, 1);
    const loserNew = newElo(1000, teamBExpected, 0);

    expect(winnerNew).toBe(1016);
    expect(loserNew).toBe(984);
  });

  it("calculates correct ELO changes for mismatched teams", () => {
    // teamA: [1200, 1200], teamB: [800, 800], teamB upsets teamA
    const teamAAvg = teamAverageElo([1200, 1200]);
    const teamBAvg = teamAverageElo([800, 800]);

    const teamAExpected = expectedScore(teamAAvg, teamBAvg);
    const teamBExpected = expectedScore(teamBAvg, teamAAvg);

    // teamB wins the upset
    const strongLoser = newElo(1200, teamAExpected, 0);
    const weakWinner = newElo(800, teamBExpected, 1);

    // Strong team loses more, weak team gains more
    expect(1200 - strongLoser).toBeGreaterThan(16);
    expect(weakWinner - 800).toBeGreaterThan(16);
  });
});
