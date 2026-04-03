import { Hono } from "hono";
import type { Env } from "./env";
import { signToken, verifyToken } from "./auth/jwt";
import { joinQueue, leaveQueue, getQueuedPlayers, removePlayersFromQueue, recordGame, claimMatchedPlayers } from "./matchmaking/queue";
import { findBestMatch, assignSeats } from "./matchmaking/matcher";

const ROOM_CHARSET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

function generateRoomCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += ROOM_CHARSET[Math.floor(Math.random() * ROOM_CHARSET.length)];
  }
  return code;
}

// Re-export Durable Object classes
export { GameRoom } from "./game/game-room";
export { MatchmakingLobby } from "./matchmaking/lobby";

const app = new Hono<{ Bindings: Env }>();

// ─── Middleware: extract uid from JWT ──────────────────────────────────────
app.use("/api/*", async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return c.json({ error: "Missing or invalid Authorization header" }, 401);
  }
  const token = authHeader.slice(7);
  try {
    const uid = await verifyToken(token, c.env.JWT_SECRET);
    c.set("uid" as never, uid);
    await next();
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }
});

// ─── Auth ──────────────────────────────────────────────────────────────────
app.post("/auth/anonymous", async (c) => {
  const uid = crypto.randomUUID();
  const token = await signToken(uid, c.env.JWT_SECRET);

  // Create user record in D1
  await c.env.DB.prepare(
    "INSERT OR IGNORE INTO users (uid) VALUES (?)"
  ).bind(uid).run();

  return c.json({ uid, token });
});

// ─── Matchmaking ───────────────────────────────────────────────────────────
app.post("/api/matchmaking/join", async (c) => {
  const uid = c.get("uid" as never) as string;
  const { eloRating } = await c.req.json<{ eloRating: number }>();

  try {
    await joinQueue(c.env.DB, uid, eloRating ?? 1000);
  } catch (e: any) {
    if (e?.message === "Already in queue") {
      return c.json({ status: "error", message: "Already in queue" }, 409);
    }
    throw e;
  }

  // Check for a match
  const allPlayers = await getQueuedPlayers(c.env.DB);
  const matched = findBestMatch(allPlayers);

  if (matched) {
    const matchedUids = matched.map((p) => p.uid);
    const matchId = crypto.randomUUID();

    // Atomically claim matched players to prevent race condition
    const claimed = await claimMatchedPlayers(c.env.DB, matchedUids, matchId);
    if (!claimed) {
      // Another concurrent request already claimed some of these players
      return c.json({ status: "queued" });
    }

    const playersInSeatOrder = assignSeats(matched);

    // Remove claimed players from queue
    await removePlayersFromQueue(c.env.DB, matchedUids);

    // Create GameRoom DO
    const gameRoomId = c.env.GAME_ROOM.newUniqueId();
    const gameRoomStub = c.env.GAME_ROOM.get(gameRoomId);
    await gameRoomStub.fetch(new Request("https://do/init", {
      method: "POST",
      body: JSON.stringify({ players: playersInSeatOrder }),
      headers: { "Content-Type": "application/json" },
    }));

    const gameId = gameRoomId.toString();

    // Record game in D1
    await recordGame(c.env.DB, gameId, playersInSeatOrder);

    // Notify all matched players via MatchmakingLobby DO
    const lobbyId = c.env.MATCHMAKING_LOBBY.idFromName("global");
    const lobbyStub = c.env.MATCHMAKING_LOBBY.get(lobbyId);
    await lobbyStub.fetch(new Request("https://do/notify", {
      method: "POST",
      body: JSON.stringify({ gameId, players: matchedUids }),
      headers: { "Content-Type": "application/json" },
    }));

    return c.json({ status: "matched", gameId });
  }

  return c.json({ status: "queued" });
});

app.post("/api/matchmaking/leave", async (c) => {
  const uid = c.get("uid" as never) as string;
  await leaveQueue(c.env.DB, uid);

  // Disconnect from lobby
  const lobbyId = c.env.MATCHMAKING_LOBBY.idFromName("global");
  const lobbyStub = c.env.MATCHMAKING_LOBBY.get(lobbyId);
  await lobbyStub.fetch(new Request("https://do/remove", {
    method: "POST",
    body: JSON.stringify({ uid }),
    headers: { "Content-Type": "application/json" },
  }));

  return c.json({ status: "left" });
});

// ─── Rooms ────────────────────────────────────────────────────────────────
app.post("/api/rooms/create", async (c) => {
  const uid = c.get("uid" as never) as string;

  let code: string | null = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    const candidate = generateRoomCode();
    const existing = await c.env.DB.prepare(
      "SELECT code FROM room_codes WHERE code = ?"
    ).bind(candidate).first();
    if (!existing) { code = candidate; break; }
  }
  if (!code) {
    return c.json({ error: "Failed to generate room code" }, 500);
  }

  const gameRoomId = c.env.GAME_ROOM.newUniqueId();
  const stub = c.env.GAME_ROOM.get(gameRoomId);
  await stub.fetch(new Request("https://do/init", {
    method: "POST",
    body: JSON.stringify({ mode: "room", hostUid: uid, roomCode: code }),
    headers: { "Content-Type": "application/json" },
  }));

  const gameId = gameRoomId.toString();

  await c.env.DB.prepare(
    "INSERT INTO room_codes (code, do_id, host_uid, created_at, status) VALUES (?, ?, ?, ?, 'open')"
  ).bind(code, gameId, uid, Date.now()).run();

  return c.json({ roomCode: code, gameId });
});

app.post("/api/rooms/join", async (c) => {
  const uid = c.get("uid" as never) as string;
  const { code } = await c.req.json<{ code: string }>();

  const row = await c.env.DB.prepare(
    "SELECT do_id, status FROM room_codes WHERE code = ?"
  ).bind(code.toUpperCase()).first<{ do_id: string; status: string }>();

  if (!row) return c.json({ error: "Room not found" }, 404);
  if (row.status === 'playing') return c.json({ error: "Game already started" }, 410);
  if (row.status === 'closed') return c.json({ error: "Room closed" }, 410);

  const doId = c.env.GAME_ROOM.idFromString(row.do_id);
  const stub = c.env.GAME_ROOM.get(doId);
  const res = await stub.fetch(new Request("https://do/join", {
    method: "POST",
    body: JSON.stringify({ playerUid: uid }),
    headers: { "Content-Type": "application/json" },
  }));

  if (!res.ok) {
    const err = await res.json<{ error: string }>();
    return c.json(err, res.status as any);
  }

  return c.json({ gameId: row.do_id });
});

app.post("/api/rooms/start", async (c) => {
  const uid = c.get("uid" as never) as string;
  const { gameId } = await c.req.json<{ gameId: string }>();

  const doId = c.env.GAME_ROOM.idFromString(gameId);
  const stub = c.env.GAME_ROOM.get(doId);
  const res = await stub.fetch(new Request("https://do/start", {
    method: "POST",
    body: JSON.stringify({ hostUid: uid }),
    headers: { "Content-Type": "application/json" },
  }));

  if (!res.ok) {
    const err = await res.json<{ error: string }>();
    return c.json(err, res.status as any);
  }

  await c.env.DB.prepare(
    "UPDATE room_codes SET status = 'playing' WHERE do_id = ?"
  ).bind(gameId).run();

  return c.json({ ok: true });
});

app.get("/api/rooms/:code/status", async (c) => {
  const code = c.req.param("code").toUpperCase();

  const row = await c.env.DB.prepare(
    "SELECT do_id, status FROM room_codes WHERE code = ?"
  ).bind(code).first<{ do_id: string; status: 'open' | 'playing' | 'closed' }>();

  if (!row) return c.json({ error: "Room not found" }, 404);

  if (row.status === 'open' || row.status === 'playing') {
    const doId = c.env.GAME_ROOM.idFromString(row.do_id);
    const stub = c.env.GAME_ROOM.get(doId);
    const res = await stub.fetch(new Request("https://do/status"));
    const doStatus = await res.json<{ phase: string; seats: any[]; closed: boolean }>();

    if (doStatus.closed) {
      await c.env.DB.prepare(
        "UPDATE room_codes SET status = 'closed' WHERE code = ?"
      ).bind(code).run();
      return c.json({ status: 'closed', seats: doStatus.seats });
    }

    return c.json({ status: row.status, seats: doStatus.seats });
  }

  return c.json({ status: row.status, seats: [] });
});

// ─── WebSocket Upgrade: Game Room ──────────────────────────────────────────
app.get("/ws/game/:gameId", async (c) => {
  const gameId = c.req.param("gameId");

  // Verify JWT from query param (WS can't use headers easily)
  const token = c.req.query("token");
  if (!token) return c.json({ error: "Missing token" }, 401);

  let uid: string;
  try {
    uid = await verifyToken(token, c.env.JWT_SECRET);
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }

  const doId = c.env.GAME_ROOM.idFromString(gameId);
  const stub = c.env.GAME_ROOM.get(doId);

  // Forward the upgrade request to the DO
  return stub.fetch(new Request(`https://do/ws?uid=${uid}`, {
    headers: c.req.raw.headers,
  }));
});

// ─── WebSocket Upgrade: Matchmaking Lobby ──────────────────────────────────
app.get("/ws/matchmaking", async (c) => {
  const token = c.req.query("token");
  if (!token) return c.json({ error: "Missing token" }, 401);

  let uid: string;
  try {
    uid = await verifyToken(token, c.env.JWT_SECRET);
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }

  const lobbyId = c.env.MATCHMAKING_LOBBY.idFromName("global");
  const stub = c.env.MATCHMAKING_LOBBY.get(lobbyId);

  return stub.fetch(new Request(`https://do/ws?uid=${uid}`, {
    headers: c.req.raw.headers,
  }));
});

// ─── Health ────────────────────────────────────────────────────────────────
app.get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }));

export default app;
