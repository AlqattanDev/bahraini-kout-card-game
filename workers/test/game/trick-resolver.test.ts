import { describe, it, expect } from "vitest";
import { resolveTrick } from "../../src/game/trick-resolver";

describe("resolveTrick", () => {
  it("joker always wins", () => {
    const plays = [
      { player: "p1", card: "SA" },
      { player: "p2", card: "JO" },
      { player: "p3", card: "SK" },
      { player: "p4", card: "SQ" },
    ];
    expect(resolveTrick(plays, "spades", "hearts")).toBe("p2");
  });

  it("highest trump wins over led suit", () => {
    const plays = [
      { player: "p1", card: "SA" },
      { player: "p2", card: "H7" },
      { player: "p3", card: "SK" },
      { player: "p4", card: "HA" },
    ];
    expect(resolveTrick(plays, "spades", "hearts")).toBe("p4");
  });

  it("highest of led suit wins when no trump played", () => {
    const plays = [
      { player: "p1", card: "S9" },
      { player: "p2", card: "SA" },
      { player: "p3", card: "S7" },
      { player: "p4", card: "SK" },
    ];
    expect(resolveTrick(plays, "spades", "hearts")).toBe("p2");
  });
});
