import { checkRateLimit, resetRateLimiter } from '../../src/utils/rate-limiter';

describe('checkRateLimit', () => {
  beforeEach(() => {
    resetRateLimiter();
  });

  it('allows the first action for a user', () => {
    expect(() => checkRateLimit('uid1')).not.toThrow();
  });

  it('allows 2 actions within 1 second', () => {
    expect(() => checkRateLimit('uid1')).not.toThrow();
    expect(() => checkRateLimit('uid1')).not.toThrow();
  });

  it('rejects the 3rd action within 1 second', () => {
    checkRateLimit('uid1');
    checkRateLimit('uid1');
    expect(() => checkRateLimit('uid1')).toThrow();
  });

  it('rejected error has resource-exhausted code', () => {
    checkRateLimit('uid1');
    checkRateLimit('uid1');
    try {
      checkRateLimit('uid1');
      fail('Should have thrown');
    } catch (err: unknown) {
      const httpsError = err as { code: string; message: string };
      expect(httpsError.code).toBe('resource-exhausted');
      expect(httpsError.message).toContain('Rate limit exceeded');
    }
  });

  it('rate limits are per-user — different users do not affect each other', () => {
    // Fill uid1's limit
    checkRateLimit('uid1');
    checkRateLimit('uid1');

    // uid2 should still be allowed
    expect(() => checkRateLimit('uid2')).not.toThrow();
    expect(() => checkRateLimit('uid2')).not.toThrow();

    // uid1 is still blocked
    expect(() => checkRateLimit('uid1')).toThrow();
  });

  it('allows actions after the window expires', async () => {
    // Use fake timers to simulate time passing
    jest.useFakeTimers();

    checkRateLimit('uid1');
    checkRateLimit('uid1');

    // Advance time by 1001ms (past the 1-second window)
    jest.advanceTimersByTime(1001);

    // Should now be allowed again
    expect(() => checkRateLimit('uid1')).not.toThrow();

    jest.useRealTimers();
  });

  it('resets cleanly between tests via resetRateLimiter', () => {
    checkRateLimit('uid1');
    checkRateLimit('uid1');
    expect(() => checkRateLimit('uid1')).toThrow();

    resetRateLimiter();

    // After reset, uid1 should be allowed again
    expect(() => checkRateLimit('uid1')).not.toThrow();
    expect(() => checkRateLimit('uid1')).not.toThrow();
  });

  it('allows exactly MAX_ACTIONS_PER_SECOND (2) actions', () => {
    const uid = 'test-exact-limit';
    // First two should succeed
    expect(() => checkRateLimit(uid)).not.toThrow();
    expect(() => checkRateLimit(uid)).not.toThrow();
    // Third should fail
    expect(() => checkRateLimit(uid)).toThrow();
  });
});
