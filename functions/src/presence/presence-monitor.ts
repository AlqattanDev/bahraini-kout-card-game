/**
 * Presence Monitor
 *
 * Handles the logic triggered when a player's presence document is deleted
 * (e.g. TTL expiry or explicit deletion on disconnect).
 *
 * When a presence doc is deleted we create a disconnect_timer document that
 * gives the player 90 seconds to reconnect before their game is forfeited.
 */

export const DISCONNECT_GRACE_PERIOD_MS = 90_000; // 90 seconds

export interface PresenceExpiredPayload {
  uid: string;
  gameId: string;
}

export interface DisconnectTimerDoc {
  uid: string;
  gameId: string;
  expiresAt: Date;
  createdAt: Date;
}

/**
 * Core logic: builds the disconnect timer document that should be written
 * to Firestore when a player's presence expires.
 *
 * Returns the timer doc data — the caller is responsible for persisting it.
 */
export function buildDisconnectTimer(payload: PresenceExpiredPayload, now: Date): DisconnectTimerDoc {
  return {
    uid: payload.uid,
    gameId: payload.gameId,
    expiresAt: new Date(now.getTime() + DISCONNECT_GRACE_PERIOD_MS),
    createdAt: now,
  };
}

/**
 * Returns the Firestore document ID for a disconnect timer.
 * Format: `{gameId}_{uid}` — unique per player per game.
 */
export function disconnectTimerDocId(gameId: string, uid: string): string {
  return `${gameId}_${uid}`;
}
