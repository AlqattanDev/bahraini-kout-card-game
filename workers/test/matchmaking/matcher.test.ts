import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { findBestMatch, calculateBracket, assignSeats } from "../../src/matchmaking/matcher";

describe("calculateBracket", () => {
  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => { vi.useRealTimers(); });

  it("starts at 200", () => {
    const now = new Date("2026-03-23T12:00:00Z");
    vi.setSystemTime(now);
    expect(calculateBracket(now.toISOString())).toBe(200);
  });

  it("expands to 300 after 15s", () => {
    const now = new Date("2026-03-23T12:00:15Z");
    vi.setSystemTime(now);
    expect(calculateBracket("2026-03-23T12:00:00Z")).toBe(300);
  });

  it("caps at 500", () => {
    const now = new Date("2026-03-23T12:05:00Z");
    vi.setSystemTime(now);
    expect(calculateBracket("2026-03-23T12:00:00Z")).toBe(500);
  });
});

describe("findBestMatch", () => {
  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => { vi.useRealTimers(); });

  it("returns null with fewer than 4 players", () => {
    expect(findBestMatch([
      { uid: "a", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
    ])).toBeNull();
  });

  it("matches 4 players within ELO bracket", () => {
    vi.setSystemTime(new Date("2026-03-23T12:00:00Z"));
    const players = [
      { uid: "a", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "b", eloRating: 1100, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "c", eloRating: 1050, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "d", eloRating: 1150, queuedAt: "2026-03-23T12:00:00Z" },
    ];
    const result = findBestMatch(players);
    expect(result).not.toBeNull();
    expect(result!.length).toBe(4);
  });
});

describe("assignSeats", () => {
  it("assigns all 4 players to unique seats", () => {
    const players = [
      { uid: "a", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "b", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "c", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "d", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
    ];
    const seats = assignSeats(players);
    expect(seats.length).toBe(4);
    expect(new Set(seats).size).toBe(4);
  });
});
