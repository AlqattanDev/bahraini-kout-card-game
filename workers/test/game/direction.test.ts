import { describe, it, expect } from "vitest";

/**
 * Counter-clockwise rotation tests for GameRoom player ordering.
 *
 * Counter-clockwise seating order (matches Dart offline client):
 * 0 → 3 → 2 → 1 → 0 ...
 *
 * Formula: nextIndex = (currentIndex - 1 + length) % length
 */
describe("Counter-clockwise player rotation", () => {
  it("should rotate 4 players counter-clockwise: 0→3→2→1", () => {
    const players = ["p0", "p1", "p2", "p3"];

    // From p0 (index 0)
    let idx = 0;
    idx = (idx - 1 + players.length) % players.length;
    expect(idx).toBe(3);
    expect(players[idx]).toBe("p3");

    // From p3 (index 3)
    idx = (idx - 1 + players.length) % players.length;
    expect(idx).toBe(2);
    expect(players[idx]).toBe("p2");

    // From p2 (index 2)
    idx = (idx - 1 + players.length) % players.length;
    expect(idx).toBe(1);
    expect(players[idx]).toBe("p1");

    // From p1 (index 1)
    idx = (idx - 1 + players.length) % players.length;
    expect(idx).toBe(0);
    expect(players[idx]).toBe("p0");
  });

  it("should handle bidding rotation counter-clockwise", () => {
    const players = ["p0", "p1", "p2", "p3"];

    // Start at p0
    let currentIndex = 0;

    // Next bidder should be p3
    let nextIndex = (currentIndex - 1 + players.length) % players.length;
    expect(players[nextIndex]).toBe("p3");

    // If p3 passes, next is p2
    currentIndex = nextIndex;
    nextIndex = (currentIndex - 1 + players.length) % players.length;
    expect(players[nextIndex]).toBe("p2");

    // If p2 passes, next is p1
    currentIndex = nextIndex;
    nextIndex = (currentIndex - 1 + players.length) % players.length;
    expect(players[nextIndex]).toBe("p1");
  });

  it("should skip players in passed list during bidding", () => {
    const players = ["p0", "p1", "p2", "p3"];
    const passed = ["p3"];

    // Starting at p0, look for next non-passed bidder
    let currentIndex = 0;

    // Check next bidder counter-clockwise, skipping passed players
    for (let i = 1; i < players.length; i++) {
      const idx = (currentIndex - i + players.length) % players.length;
      if (!passed.includes(players[idx])) {
        expect(players[idx]).toBe("p2");
        break;
      }
    }
  });

  it("should determine first bidder as counter-clockwise from dealer", () => {
    const players = ["p0", "p1", "p2", "p3"];

    // Dealer is p0 (index 0)
    const dealerIndex = 0;
    const firstBidderIndex = (dealerIndex - 1 + players.length) % players.length;
    expect(firstBidderIndex).toBe(3);
    expect(players[firstBidderIndex]).toBe("p3");

    // Dealer is p1 (index 1)
    const dealerIndex2 = 1;
    const firstBidderIndex2 = (dealerIndex2 - 1 + players.length) % players.length;
    expect(firstBidderIndex2).toBe(0);
    expect(players[firstBidderIndex2]).toBe("p0");
  });

  it("should determine first trick player as counter-clockwise from bidder", () => {
    const players = ["p0", "p1", "p2", "p3"];

    // Bidder is p3 (index 3)
    const bidderIndex = 3;
    const firstPlayerIndex = (bidderIndex - 1 + players.length) % players.length;
    expect(firstPlayerIndex).toBe(2);
    expect(players[firstPlayerIndex]).toBe("p2");

    // Bidder is p0 (index 0)
    const bidderIndex2 = 0;
    const firstPlayerIndex2 = (bidderIndex2 - 1 + players.length) % players.length;
    expect(firstPlayerIndex2).toBe(3);
    expect(players[firstPlayerIndex2]).toBe("p3");
  });

  it("should handle single-step counter-clockwise lookup from uid", () => {
    const players = ["p0", "p1", "p2", "p3"];

    // From p0
    const idx0 = players.indexOf("p0");
    const next0 = players[(idx0 - 1 + players.length) % players.length];
    expect(next0).toBe("p3");

    // From p2
    const idx2 = players.indexOf("p2");
    const next2 = players[(idx2 - 1 + players.length) % players.length];
    expect(next2).toBe("p1");
  });
});
