import { describe, it, expect } from "vitest";
import { encodeCard, decodeCard, makeCard, makeJoker } from "../../src/game/card";

describe("card encoding", () => {
  it("encodes spade ace as SA", () => {
    const card = makeCard("spades", "ace");
    expect(encodeCard(card)).toBe("SA");
  });

  it("encodes ten of clubs as C10", () => {
    const card = makeCard("clubs", "ten");
    expect(encodeCard(card)).toBe("C10");
  });

  it("encodes joker as JO", () => {
    expect(encodeCard(makeJoker())).toBe("JO");
  });

  it("round-trips all standard cards", () => {
    const card = makeCard("diamonds", "king");
    expect(decodeCard(encodeCard(card))).toEqual(card);
  });

  it("round-trips joker", () => {
    const joker = makeJoker();
    expect(decodeCard(encodeCard(joker))).toEqual(joker);
  });
});
