import type { QueuedPlayer } from "./matcher";
import { expectedScore, newElo, teamAverageElo } from "./elo";

export const QUEUE_STALE_AFTER_SECONDS = 600; // 10 minutes

export async function purgeStaleQueue(db: D1Database): Promise<number> {
  const result = await db
    .prepare(
      `DELETE FROM matchmaking_queue WHERE queued_at < datetime('now', '-' || ? || ' seconds')`
    )
    .bind(QUEUE_STALE_AFTER_SECONDS)
    .run();
  return result.meta.changes ?? 0;
}

export async function joinQueue(
  db: D1Database,
  uid: string,
  eloRating: number
): Promise<void> {
  // Upsert user
  await db
    .prepare(
      "INSERT INTO users (uid, elo_rating) VALUES (?, ?) ON CONFLICT(uid) DO UPDATE SET elo_rating = ?"
    )
    .bind(uid, eloRating, eloRating)
    .run();

  // Check not already in queue
  const existing = await db
    .prepare("SELECT uid FROM matchmaking_queue WHERE uid = ?")
    .bind(uid)
    .first();
  if (existing) {
    throw new Error("Already in queue");
  }

  await db
    .prepare(
      "INSERT INTO matchmaking_queue (uid, elo_rating) VALUES (?, ?)"
    )
    .bind(uid, eloRating)
    .run();
}

export async function leaveQueue(
  db: D1Database,
  uid: string
): Promise<void> {
  const result = await db
    .prepare("DELETE FROM matchmaking_queue WHERE uid = ?")
    .bind(uid)
    .run();
  if (result.meta.changes === 0) {
    throw new Error("Not in queue");
  }
}

export async function getQueuedPlayers(
  db: D1Database
): Promise<QueuedPlayer[]> {
  const rows = await db
    .prepare(
      "SELECT uid, elo_rating as eloRating, queued_at as queuedAt FROM matchmaking_queue WHERE claimed_by IS NULL ORDER BY queued_at ASC"
    )
    .all<{ uid: string; eloRating: number; queuedAt: string }>();
  return rows.results;
}

/**
 * Atomically claim matched players. Returns true if all were claimed
 * (no concurrent match claimed any of them first).
 */
export async function claimMatchedPlayers(
  db: D1Database,
  uids: string[],
  matchId: string
): Promise<boolean> {
  const placeholders = uids.map(() => "?").join(",");
  const result = await db
    .prepare(
      `UPDATE matchmaking_queue SET claimed_by = ? WHERE uid IN (${placeholders}) AND claimed_by IS NULL`
    )
    .bind(matchId, ...uids)
    .run();

  if (result.meta.changes === uids.length) {
    return true;
  }

  // All-or-nothing: unclaim what we got
  await db
    .prepare(
      `UPDATE matchmaking_queue SET claimed_by = NULL WHERE claimed_by = ?`
    )
    .bind(matchId)
    .run();

  return false;
}

export async function removePlayersFromQueue(
  db: D1Database,
  uids: string[]
): Promise<void> {
  const placeholders = uids.map(() => "?").join(",");
  await db
    .prepare(`DELETE FROM matchmaking_queue WHERE uid IN (${placeholders})`)
    .bind(...uids)
    .run();
}

export async function recordGame(
  db: D1Database,
  gameId: string,
  players: string[]
): Promise<void> {
  await db
    .prepare(
      "INSERT INTO game_history (game_id, players, final_scores) VALUES (?, ?, ?)"
    )
    .bind(gameId, JSON.stringify(players), JSON.stringify({ teamA: 0, teamB: 0 }))
    .run();
}

export async function completeGame(
  db: D1Database,
  gameId: string,
  winnerTeam: string,
  finalScores: { teamA: number; teamB: number },
  players: string[] // seat order: 0,2 = teamA, 1,3 = teamB
): Promise<void> {
  // Update game history
  await db
    .prepare(
      "UPDATE game_history SET winner_team = ?, final_scores = ?, completed_at = datetime('now') WHERE game_id = ?"
    )
    .bind(winnerTeam, JSON.stringify(finalScores), gameId)
    .run();

  // Update ELO ratings using proper formula
  const teamAUids = [players[0], players[2]];
  const teamBUids = [players[1], players[3]];
  const allUids = [...teamAUids, ...teamBUids];

  // Fetch current ELOs from DB
  const eloRows = await db
    .prepare(`SELECT uid, elo_rating FROM users WHERE uid IN (${allUids.map(() => "?").join(",")})`)
    .bind(...allUids)
    .all<{ uid: string; elo_rating: number }>();

  const eloMap = new Map<string, number>();
  for (const row of eloRows.results) {
    eloMap.set(row.uid, row.elo_rating);
  }

  const teamAElos = teamAUids.map((uid) => eloMap.get(uid) ?? 1000);
  const teamBElos = teamBUids.map((uid) => eloMap.get(uid) ?? 1000);
  const teamAAvg = teamAverageElo(teamAElos);
  const teamBAvg = teamAverageElo(teamBElos);

  const teamAExpected = expectedScore(teamAAvg, teamBAvg);
  const teamBExpected = expectedScore(teamBAvg, teamAAvg);
  const teamAActual = winnerTeam === "teamA" ? 1 : 0;
  const teamBActual = winnerTeam === "teamB" ? 1 : 0;

  for (const uid of teamAUids) {
    const oldElo = eloMap.get(uid) ?? 1000;
    const updated = Math.max(0, newElo(oldElo, teamAExpected, teamAActual));
    await db
      .prepare("UPDATE users SET elo_rating = ?, updated_at = datetime('now') WHERE uid = ?")
      .bind(updated, uid)
      .run();
  }
  for (const uid of teamBUids) {
    const oldElo = eloMap.get(uid) ?? 1000;
    const updated = Math.max(0, newElo(oldElo, teamBExpected, teamBActual));
    await db
      .prepare("UPDATE users SET elo_rating = ?, updated_at = datetime('now') WHERE uid = ?")
      .bind(updated, uid)
      .run();
  }
}
