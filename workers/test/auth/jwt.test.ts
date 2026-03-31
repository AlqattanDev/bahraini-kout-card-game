import { describe, it, expect } from "vitest";
import { signToken, verifyToken } from "../../src/auth/jwt";

const TEST_SECRET = "test-secret-key-for-unit-tests-only-32chars!!";

describe("JWT auth", () => {
  it("signs and verifies a token", async () => {
    const token = await signToken("user-123", TEST_SECRET);
    const uid = await verifyToken(token, TEST_SECRET);
    expect(uid).toBe("user-123");
  });

  it("rejects tampered token", async () => {
    const token = await signToken("user-123", TEST_SECRET);
    await expect(verifyToken(token + "x", TEST_SECRET)).rejects.toThrow();
  });

  it("rejects token signed with wrong secret", async () => {
    const token = await signToken("user-123", TEST_SECRET);
    await expect(verifyToken(token, "wrong-secret-key-that-is-32chars!!!!!")).rejects.toThrow();
  });
});
