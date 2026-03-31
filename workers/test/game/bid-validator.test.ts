import { describe, it, expect } from "vitest";
import { validateBid, validatePass, isLastBidder } from "../../src/game/bid-validator";

describe("validateBid", () => {
  it("rejects bid from passed player", () => {
    expect(validateBid(6, 5, ["p1"], "p1").valid).toBe(false);
  });

  it("rejects bid not higher than current", () => {
    expect(validateBid(5, 5, [], "p1").valid).toBe(false);
  });

  it("accepts valid higher bid", () => {
    expect(validateBid(6, 5, [], "p1").valid).toBe(true);
  });

  it("accepts first bid with no current highest", () => {
    expect(validateBid(5, null, [], "p1").valid).toBe(true);
  });
});

describe("isLastBidder", () => {
  it("returns false if player already passed", () => {
    expect(isLastBidder(["p1", "p2", "p3"], "p1", 4)).toBe(false);
  });

  it("returns true when 3 of 4 have passed and player hasn't", () => {
    expect(isLastBidder(["p1", "p2", "p3"], "p4", 4)).toBe(true);
  });

  it("returns false when only 2 have passed", () => {
    expect(isLastBidder(["p1", "p2"], "p3", 4)).toBe(false);
  });
});

describe("validatePass", () => {
  it("rejects already-passed player", () => {
    expect(validatePass(["p1", "p2"], "p1", 4, null).valid).toBe(false);
  });

  it("allows pass when not last bidder", () => {
    expect(validatePass(["p1", "p2"], "p3", 4, null).valid).toBe(true);
  });

  it("rejects pass when last bidder and no existing bid", () => {
    const result = validatePass(["p1", "p2", "p3"], "p4", 4, null);
    expect(result.valid).toBe(false);
    expect(result.error).toBe("must-bid");
  });

  it("allows pass when last bidder but someone already bid", () => {
    expect(validatePass(["p1", "p2", "p3"], "p4", 4, 5).valid).toBe(true);
  });
});
