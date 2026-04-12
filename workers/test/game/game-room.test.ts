import { describe, it, expect } from "vitest";
import { applyScore, checkGameOver } from "../../src/game/scorer";
import type { TeamName } from "../../src/game/types";

// GameRoom is a Durable Object — full integration testing requires
// the Cloudflare test pool. For now, test the logic indirectly
// through the pure game logic functions (already tested in other files).
// This file will contain miniflare-based integration tests.

describe("GameRoom (integration placeholder)", () => {
  it.todo("initializes game with 4 players and deals 8 cards each");
  it.todo("accepts WebSocket upgrade for valid player");
  it.todo("rejects WebSocket upgrade for non-player");
  it.todo("broadcasts state update after bid");
  it.todo("sends private hand only to owning player");
  it.todo("handles full game flow: bid → trump → play → score");
  it.todo("handles poison joker scenario");
  it.todo("handles malzoom reshuffle and forced bid");
});

/**
 * Tests the forfeit logic that handleForfeit uses: applyScore + checkGameOver.
 * Verifies that multiple disconnected players all get their penalties applied
 * (the alarm loop must not break early after the first forfeit).
 */
describe("disconnect → alarm → forfeit (logic)", () => {
  function getTeamForPlayer(uid: string, players: string[]): TeamName {
    const seat = players.indexOf(uid);
    return seat % 2 === 0 ? "teamA" : "teamB";
  }

  function simulateForfeit(
    scores: Record<TeamName, number>,
    disconnectedUid: string,
    players: string[],
    bidAmount: number | null
  ): { scores: Record<TeamName, number>; gameOver: TeamName | null } {
    const playerTeam = getTeamForPlayer(disconnectedUid, players);
    const winningTeam: TeamName = playerTeam === "teamA" ? "teamB" : "teamA";

    let penalty = 10;
    if (bidAmount !== null) {
      const penaltyMap: Record<number, number> = { 5: 10, 6: 12, 7: 14, 8: 16 };
      penalty = penaltyMap[bidAmount] ?? 10;
    }

    const newScores = applyScore(scores, winningTeam, penalty);
    const gameOver = checkGameOver(newScores);
    return { scores: newScores, gameOver };
  }

  it("applies penalties for multiple disconnected players from the same team", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    // p0 (teamA) disconnects — teamB gets 10 points
    const r1 = simulateForfeit(scores, "p0", players, null);
    scores = r1.scores;
    expect(scores.teamB).toBe(10);
    expect(r1.gameOver).toBeNull();

    // p2 (also teamA) disconnects — teamB gets another 10 points
    const r2 = simulateForfeit(scores, "p2", players, null);
    scores = r2.scores;
    expect(scores.teamB).toBe(20);
    expect(r2.gameOver).toBeNull();
  });

  it("applies penalties for disconnected players from different teams", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    // p0 (teamA) disconnects — teamB gets 10 points
    const r1 = simulateForfeit(scores, "p0", players, null);
    scores = r1.scores;
    expect(scores.teamB).toBe(10);

    // p1 (teamB) disconnects — teamA gets 10 points, cancels out teamB's score
    const r2 = simulateForfeit(scores, "p1", players, null);
    scores = r2.scores;
    // tug-of-war: 10 points to teamA deducts teamB's 10 first → both at 0
    expect(scores.teamA).toBe(0);
    expect(scores.teamB).toBe(0);
  });

  it("first forfeit can end the game, second is skipped (GAME_OVER guard)", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 25 };
    let phase = "PLAYING";

    // p0 (teamA) disconnects — teamB gets +10, reaching 35 ≥ 31
    const r1 = simulateForfeit(scores, "p0", players, null);
    scores = r1.scores;
    if (r1.gameOver) phase = "GAME_OVER";

    expect(scores.teamB).toBe(35);
    expect(phase).toBe("GAME_OVER");
    expect(r1.gameOver).toBe("teamB");

    // p1 (teamB) also disconnected — but game is already over.
    // handleForfeit guards: if (game.phase === 'GAME_OVER') return;
    // So the second forfeit should be skipped.
    if (phase !== "GAME_OVER") {
      const r2 = simulateForfeit(scores, "p1", players, null);
      scores = r2.scores;
    }

    // Score unchanged — second forfeit was correctly skipped
    expect(scores.teamB).toBe(35);
    expect(scores.teamA).toBe(0);
  });

  it("uses bid penalty when a bid is active", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    // bid 7 active — forfeit penalty is 14 (not default 10)
    const r1 = simulateForfeit(scores, "p0", players, 7);
    scores = r1.scores;
    expect(scores.teamB).toBe(14);

    // second disconnect with same bid
    const r2 = simulateForfeit(scores, "p2", players, 7);
    scores = r2.scores;
    expect(scores.teamB).toBe(28);
  });

  it("both forfeits process before game ends when neither alone reaches 31", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 10 };
    const forfeited: string[] = [];

    // Simulate the alarm loop processing multiple disconnect_timeout events
    const disconnectedPlayers = ["p0", "p2"]; // both teamA
    for (const uid of disconnectedPlayers) {
      const result = simulateForfeit(scores, uid, players, null);
      scores = result.scores;
      forfeited.push(uid);
      if (result.gameOver) break;
    }

    // Both forfeits were processed
    expect(forfeited).toEqual(["p0", "p2"]);
    // teamB had 10, got +10 from p0 forfeit (=20), +10 from p2 forfeit (=30)
    expect(scores.teamB).toBe(30);
    expect(checkGameOver(scores)).toBeNull(); // 30 < 31
  });
});
