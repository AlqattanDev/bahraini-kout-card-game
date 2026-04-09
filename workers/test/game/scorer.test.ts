import { describe, it, expect } from "vitest";
import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyPoisonJoker,
  applyScore,
  applyKout,
  checkGameOver,
  isRoundDecided,
} from "../../src/game/scorer";

describe("calculateRoundResult", () => {
  it("awards success points when bidding team wins enough tricks", () => {
    const result = calculateRoundResult(5, "teamA", { teamA: 5, teamB: 3 });
    expect(result).toEqual({ winningTeam: "teamA", points: 5 });
  });

  it("awards double penalty to opponent when bidding team fails", () => {
    const result = calculateRoundResult(6, "teamA", { teamA: 4, teamB: 4 });
    expect(result).toEqual({ winningTeam: "teamB", points: 12 });
  });

  it("kout success gives 31 points", () => {
    const result = calculateRoundResult(8, "teamA", { teamA: 8, teamB: 0 });
    expect(result).toEqual({ winningTeam: "teamA", points: 31 });
  });

  it("kout failure gives 16 to opponent", () => {
    const result = calculateRoundResult(8, "teamA", { teamA: 7, teamB: 1 });
    expect(result).toEqual({ winningTeam: "teamB", points: 16 });
  });
});

describe("applyScore (tug-of-war)", () => {
  it("from zero: points go to winning team", () => {
    expect(applyScore({ teamA: 0, teamB: 0 }, "teamA", 5)).toEqual({ teamA: 5, teamB: 0 });
  });

  it("deducts from opponent first, remainder to winner", () => {
    expect(applyScore({ teamA: 7, teamB: 0 }, "teamB", 10)).toEqual({ teamA: 0, teamB: 3 });
  });

  it("partial deduction stays with original leader", () => {
    expect(applyScore({ teamA: 10, teamB: 0 }, "teamB", 3)).toEqual({ teamA: 7, teamB: 0 });
  });
});

describe("applyKout", () => {
  it("kout instant win sets winner to 31", () => {
    expect(applyKout("teamA")).toEqual({ teamA: 31, teamB: 0 });
  });
});

describe("checkGameOver", () => {
  it("returns null when no team at 31", () => {
    expect(checkGameOver({ teamA: 20, teamB: 0 })).toBeNull();
  });

  it("returns winning team at 31", () => {
    expect(checkGameOver({ teamA: 31, teamB: 0 })).toBe("teamA");
  });
});

describe("poisonJoker", () => {
  it("winning team is opponent of joker holder", () => {
    const result = calculatePoisonJokerResult("teamA");
    expect(result.winningTeam).toBe("teamB");
  });

  it("applyPoisonJoker sets opponent to 31 (instant game loss)", () => {
    const scores = applyPoisonJoker("teamA");
    expect(scores).toEqual({ teamA: 0, teamB: 31 });
  });

  it("applyPoisonJoker causes game over", () => {
    const scores = applyPoisonJoker("teamB");
    expect(checkGameOver(scores)).toBe("teamA");
  });
});

describe("isRoundDecided", () => {
  it("decided when bidder reaches bid", () => {
    expect(isRoundDecided(5, "teamA", { teamA: 5, teamB: 2 })).toBe(true);
  });

  it("decided when opponent kills bid", () => {
    expect(isRoundDecided(5, "teamA", { teamA: 2, teamB: 4 })).toBe(true);
  });

  it("not decided when outcome still open", () => {
    expect(isRoundDecided(5, "teamA", { teamA: 4, teamB: 3 })).toBe(false);
  });

  it("kout needs all 8 or 1 opponent win", () => {
    expect(isRoundDecided(8, "teamA", { teamA: 7, teamB: 0 })).toBe(false);
    expect(isRoundDecided(8, "teamA", { teamA: 8, teamB: 0 })).toBe(true);
    expect(isRoundDecided(8, "teamA", { teamA: 0, teamB: 1 })).toBe(true);
  });
});
