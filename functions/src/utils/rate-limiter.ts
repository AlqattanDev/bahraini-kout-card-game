import { HttpsError } from 'firebase-functions/v2/https';

const userActionTimestamps = new Map<string, number[]>();
const MAX_ACTIONS_PER_SECOND = 2;
const WINDOW_MS = 1000;

export function checkRateLimit(uid: string): void {
  const now = Date.now();
  const timestamps = userActionTimestamps.get(uid) ?? [];
  const recent = timestamps.filter((t) => now - t < WINDOW_MS);
  if (recent.length >= MAX_ACTIONS_PER_SECOND) {
    throw new HttpsError('resource-exhausted', 'Rate limit exceeded: max 2 actions per second');
  }
  recent.push(now);
  userActionTimestamps.set(uid, recent);
}

// For testing
export function resetRateLimiter(): void {
  userActionTimestamps.clear();
}
