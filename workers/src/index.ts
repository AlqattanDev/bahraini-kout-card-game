import { Hono } from "hono";
import type { Env } from "./env";
import { signToken, verifyToken } from "./auth/jwt";
import { joinQueue, leaveQueue, getQueuedPlayers, removePlayersFromQueue, recordGame, claimMatchedPlayers } from "./matchmaking/queue";
import { findBestMatch, assignSeats } from "./matchmaking/matcher";

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

  await joinQueue(c.env.DB, uid, eloRating ?? 1000);

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
