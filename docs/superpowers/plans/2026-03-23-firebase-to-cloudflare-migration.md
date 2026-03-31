# Firebase → Cloudflare Workers Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all Firebase services (Auth, Firestore, Cloud Functions) with Cloudflare Workers, Durable Objects, and D1 — achieving zero Firebase dependency, WebSocket-based real-time gameplay, and free-tier hosting.

**Architecture:** Each game room is a Durable Object with WebSocket hibernation — players connect via WS, game actions are messages processed single-threaded (no transactions needed), state is broadcast instantly. Matchmaking uses D1 for the global queue. Auth is simple JWT-based anonymous identity.

**Tech Stack:** Cloudflare Workers (TypeScript), Durable Objects (SQLite-backed, WebSocket Hibernation API), D1 (SQLite), Hono (lightweight router), jose (JWT), Vitest (testing), Flutter/Dart (client with `web_socket_channel` package)

---

## Service Mapping

| Firebase | Cloudflare | Notes |
|---|---|---|
| Firebase Auth (anonymous) | Worker `/auth/anonymous` + JWT | Client stores JWT, sends on WS upgrade |
| Firestore game doc + listeners | Durable Object in-memory state + WS broadcast | Single-threaded = no transactions needed |
| Firestore private hands | Per-player WS messages (never broadcast) | Simpler than subcollection security rules |
| Cloud Functions (game actions) | WS message handlers in GameRoom DO | `placeBid`, `playCard`, `selectTrump` |
| Cloud Functions (matchmaking) | Worker HTTP + D1 query | Check for match on every `joinQueue` |
| Firestore matchmaking_queue | D1 table | Persistent, globally queryable |
| Firestore presence + heartbeat | WS connection lifecycle + DO Alarm | No polling needed — WS close = disconnect |
| Firestore security rules | DO single-threaded execution + JWT validation | Authorization is code, not config |

## WebSocket Message Protocol

```
// Client → Server (actions)
{"action": "placeBid", "data": {"bidAmount": 5}}
{"action": "placeBid", "data": {"bidAmount": 0}}     // pass
{"action": "selectTrump", "data": {"suit": "spades"}}
{"action": "playCard", "data": {"card": "SA"}}

// Server → All Clients (broadcast)
{"event": "gameState", "data": {<public game state>}}

// Server → Single Client (private)
{"event": "hand", "data": {"hand": ["SA","HK","C10","D9","S8","SJ","H7","JO"]}}

// Server → Single Client (error)
{"event": "error", "data": {"code": "NOT_YOUR_TURN", "message": "Not your turn"}}

// Server → Single Client (matched)
{"event": "matched", "data": {"gameId": "abc123"}}
```

## File Structure

### New: `workers/` (Cloudflare backend — replaces `functions/`)

```
workers/
├── wrangler.toml
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── src/
│   ├── index.ts                        # Worker entry: Hono router, WS upgrade, DO bindings
│   ├── env.ts                          # Env type definition (bindings)
│   ├── auth/
│   │   └── jwt.ts                      # signToken(uid), verifyToken(token) → uid
│   ├── matchmaking/
│   │   ├── queue.ts                    # D1 queue operations: join, leave, findMatch
│   │   ├── matcher.ts                  # ELO bracket matching (port from match-players.ts)
│   │   └── elo.ts                      # ELO math (direct port)
│   ├── game/
│   │   ├── game-room.ts               # Durable Object class: GameRoom
│   │   ├── types.ts                    # Game types (direct port from functions/src/game/types.ts)
│   │   ├── card.ts                     # Card encode/decode (direct port)
│   │   ├── deck.ts                     # Deck build + deal (direct port)
│   │   ├── bid-validator.ts            # Bid validation (direct port)
│   │   ├── play-validator.ts           # Play validation (direct port)
│   │   ├── trick-resolver.ts           # Trick resolution (direct port)
│   │   └── scorer.ts                   # Scoring (direct port)
│   └── presence/
│       └── disconnect.ts               # Disconnect evaluation (direct port)
├── test/
│   ├── auth/
│   │   └── jwt.test.ts
│   ├── game/
│   │   ├── card.test.ts
│   │   ├── deck.test.ts
│   │   ├── bid-validator.test.ts
│   │   ├── play-validator.test.ts
│   │   ├── trick-resolver.test.ts
│   │   ├── scorer.test.ts
│   │   └── game-room.test.ts
│   ├── matchmaking/
│   │   ├── matcher.test.ts
│   │   └── queue.test.ts
│   └── integration/
│       └── full-game.test.ts
└── migrations/
    └── 0001_init.sql
```

### Modified: Flutter client files

```
lib/
├── main.dart                           # Remove Firebase init, add config
├── app/
│   ├── config.dart                     # NEW: Worker URL, environment config
│   ├── services/
│   │   ├── auth_service.dart           # REWRITE: HTTP POST /auth/anonymous → JWT
│   │   ├── game_service.dart           # REWRITE: WebSocket to GameRoom DO
│   │   ├── matchmaking_service.dart    # REWRITE: HTTP + WebSocket for queue
│   │   └── presence_service.dart       # REWRITE: WebSocket keepalive (trivial)
│   └── models/
│       └── client_game_state.dart      # MODIFY: deserialize from JSON (WS) instead of Firestore
```

### Deleted files

```
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
macos/Runner/GoogleService-Info.plist
firebase.json
firestore.rules
functions/                              # Entire directory
```

---

## Task 1: Scaffold Cloudflare Workers Project

**Files:**
- Create: `workers/package.json`
- Create: `workers/tsconfig.json`
- Create: `workers/wrangler.toml`
- Create: `workers/vitest.config.ts`
- Create: `workers/src/env.ts`
- Create: `workers/src/index.ts` (stub)

- [ ] **Step 1: Create `workers/package.json`**

```json
{
  "name": "bahraini-kout-workers",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest",
    "db:migrate:local": "wrangler d1 execute kout-db --local --file=migrations/0001_init.sql",
    "db:migrate:remote": "wrangler d1 execute kout-db --remote --file=migrations/0001_init.sql"
  },
  "dependencies": {
    "hono": "^4.0.0",
    "jose": "^5.0.0"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.0.0",
    "@cloudflare/vitest-pool-workers": "^0.5.0",
    "typescript": "^5.4.0",
    "vitest": "^2.0.0",
    "wrangler": "^3.0.0"
  }
}
```

- [ ] **Step 2: Create `workers/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types", "@cloudflare/vitest-pool-workers"],
    "strict": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  },
  "include": ["src/**/*.ts", "test/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 3: Create `workers/wrangler.toml`**

```toml
name = "bahraini-kout"
main = "src/index.ts"
compatibility_date = "2026-03-23"

[durable_objects]
bindings = [
  { name = "GAME_ROOM", class_name = "GameRoom" },
  { name = "MATCHMAKING_LOBBY", class_name = "MatchmakingLobby" }
]

[[migrations]]
tag = "v1"
new_sqlite_classes = ["GameRoom", "MatchmakingLobby"]

[[d1_databases]]
binding = "DB"
database_name = "kout-db"
database_id = "placeholder-replace-after-d1-create"

[vars]
JWT_SECRET = "replace-with-actual-secret"
ENVIRONMENT = "development"
```

- [ ] **Step 4: Create `workers/vitest.config.ts`**

```typescript
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
      },
    },
  },
});
```

- [ ] **Step 5: Create `workers/src/env.ts`**

```typescript
export interface Env {
  GAME_ROOM: DurableObjectNamespace;
  MATCHMAKING_LOBBY: DurableObjectNamespace;
  DB: D1Database;
  JWT_SECRET: string;
  ENVIRONMENT: string;
}
```

- [ ] **Step 6: Create stub `workers/src/index.ts`**

```typescript
import { Hono } from "hono";
import type { Env } from "./env";

const app = new Hono<{ Bindings: Env }>();

app.get("/health", (c) => c.json({ status: "ok" }));

export default app;

// Durable Object exports will be added in later tasks
```

- [ ] **Step 7: Install dependencies and verify build**

Run: `cd workers && npm install && npx wrangler dev --dry-run`
Expected: Clean install, no TypeScript errors

- [ ] **Step 8: Commit**

```bash
git add workers/
git commit -m "feat: scaffold Cloudflare Workers project with Hono, DO bindings, D1"
```

---

## Task 2: Port Game Logic (Pure TypeScript — Zero Changes)

These files are direct ports from `functions/src/game/` with one change: remove the `firebase-admin/firestore` Timestamp import from `types.ts`.

**Files:**
- Create: `workers/src/game/types.ts`
- Create: `workers/src/game/card.ts`
- Create: `workers/src/game/deck.ts`
- Create: `workers/src/game/bid-validator.ts`
- Create: `workers/src/game/play-validator.ts`
- Create: `workers/src/game/trick-resolver.ts`
- Create: `workers/src/game/scorer.ts`
- Create: `workers/src/presence/disconnect.ts`
- Create: `workers/src/matchmaking/elo.ts`
- Create: `workers/test/game/card.test.ts`
- Create: `workers/test/game/bid-validator.test.ts`
- Create: `workers/test/game/trick-resolver.test.ts`
- Create: `workers/test/game/scorer.test.ts`

- [ ] **Step 1: Port `workers/src/game/types.ts`**

Copy from `functions/src/game/types.ts` verbatim, replacing the `metadata` field's `Timestamp` type with `string` (ISO 8601):

```typescript
export type SuitName = 'spades' | 'hearts' | 'clubs' | 'diamonds';
export type RankName = 'ace' | 'king' | 'queen' | 'jack' | 'ten' | 'nine' | 'eight' | 'seven';

export interface GameCard {
  suit: SuitName | null;
  rank: RankName | null;
  isJoker: boolean;
  code: string;
}

export type GamePhase = 'WAITING' | 'DEALING' | 'BIDDING' | 'TRUMP_SELECTION' | 'PLAYING' | 'ROUND_SCORING' | 'GAME_OVER';
export type TeamName = 'teamA' | 'teamB';

export interface TrickPlay {
  player: string;
  card: string;
}

export interface BiddingState {
  currentBidder: string;
  highestBid: number | null;
  highestBidder: string | null;
  passed: string[];
}

export interface GameDocument {
  phase: GamePhase;
  players: string[];
  currentTrick: { lead: string; plays: TrickPlay[] } | null;
  tricks: Record<TeamName, number>;
  scores: Record<TeamName, number>;
  bid: { player: string; amount: number } | null;
  biddingState: BiddingState | null;
  trumpSuit: SuitName | null;
  dealer: string;
  currentPlayer: string;
  reshuffleCount: number;
  roundHistory: TrickPlay[][];
  metadata: { createdAt: string; status: string; winner?: TeamName };
}

export const RANK_VALUES: Record<RankName, number> = {
  ace: 14, king: 13, queen: 12, jack: 11, ten: 10, nine: 9, eight: 8, seven: 7,
};

export const BID_SUCCESS_POINTS: Record<number, number> = { 5: 5, 6: 6, 7: 7, 8: 31 };
export const BID_FAILURE_POINTS: Record<number, number> = { 5: 10, 6: 12, 7: 14, 8: 31 };
export const TARGET_SCORE = 31;
export const POISON_JOKER_PENALTY = 10;
```

- [ ] **Step 2: Copy remaining game logic files verbatim**

Copy these files with zero changes (they have no Firebase imports):
- `functions/src/game/card.ts` → `workers/src/game/card.ts`
- `functions/src/game/deck.ts` → `workers/src/game/deck.ts`
- `functions/src/game/bid-validator.ts` → `workers/src/game/bid-validator.ts`
- `functions/src/game/play-validator.ts` → `workers/src/game/play-validator.ts`
- `functions/src/game/trick-resolver.ts` → `workers/src/game/trick-resolver.ts`
- `functions/src/game/scorer.ts` → `workers/src/game/scorer.ts`
- `functions/src/presence/disconnect-handler.ts` → `workers/src/presence/disconnect.ts`
- `functions/src/matchmaking/elo.ts` → `workers/src/matchmaking/elo.ts`

For `disconnect.ts`: remove the `import { BID_FAILURE_POINTS }` from `firebase-functions` path and update to relative `'../game/types'`.

- [ ] **Step 3: Write tests for ported game logic**

Create `workers/test/game/card.test.ts`:

```typescript
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
```

Create `workers/test/game/bid-validator.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { validateBid, validatePass, checkBiddingComplete, checkMalzoom } from "../../src/game/bid-validator";

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

describe("checkMalzoom", () => {
  it("returns none when fewer than 4 passed", () => {
    expect(checkMalzoom(["p1", "p2", "p3"], 0)).toBe("none");
  });

  it("returns reshuffle on first all-pass", () => {
    expect(checkMalzoom(["p1", "p2", "p3", "p4"], 0)).toBe("reshuffle");
  });

  it("returns forcedBid on second all-pass", () => {
    expect(checkMalzoom(["p1", "p2", "p3", "p4"], 1)).toBe("forcedBid");
  });
});
```

Create `workers/test/game/trick-resolver.test.ts`:

```typescript
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
```

Create `workers/test/game/scorer.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyScore,
  checkGameOver,
} from "../../src/game/scorer";

describe("calculateRoundResult", () => {
  it("awards success points when bidding team wins enough tricks", () => {
    const result = calculateRoundResult(5, "teamA", { teamA: 5, teamB: 3 });
    expect(result).toEqual({ winningTeam: "teamA", points: 5 });
  });

  it("awards double penalty to opponent when bidding team fails", () => {
    const result = calculateRoundResult(6, "teamA", { teamA: 4, teamB: 4 });
    expect(result).toEqual({ winningTeam: "teamB", points: 12 });
  });

  it("kout success gives 31 points", () => {
    const result = calculateRoundResult(8, "teamA", { teamA: 8, teamB: 0 });
    expect(result).toEqual({ winningTeam: "teamA", points: 31 });
  });

  it("kout failure gives 31 to opponent", () => {
    const result = calculateRoundResult(8, "teamA", { teamA: 7, teamB: 1 });
    expect(result).toEqual({ winningTeam: "teamB", points: 31 });
  });
});

describe("checkGameOver", () => {
  it("returns null when no team at 31", () => {
    expect(checkGameOver({ teamA: 20, teamB: 15 })).toBeNull();
  });

  it("returns winning team at 31", () => {
    expect(checkGameOver({ teamA: 31, teamB: 10 })).toBe("teamA");
  });
});

describe("poisonJoker", () => {
  it("gives 10 points to opponent", () => {
    const result = calculatePoisonJokerResult("teamA");
    expect(result).toEqual({ winningTeam: "teamB", points: 10 });
  });
});
```

- [ ] **Step 4: Run tests**

Run: `cd workers && npx vitest run`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add workers/src/game/ workers/src/presence/ workers/src/matchmaking/elo.ts workers/test/game/
git commit -m "feat: port game logic from Firebase Cloud Functions to Workers (zero Firebase deps)"
```

---

## Task 3: JWT Authentication

**Files:**
- Create: `workers/src/auth/jwt.ts`
- Create: `workers/test/auth/jwt.test.ts`

- [ ] **Step 1: Write failing test**

Create `workers/test/auth/jwt.test.ts`:

```typescript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workers && npx vitest run test/auth/`
Expected: FAIL — module not found

- [ ] **Step 3: Implement `workers/src/auth/jwt.ts`**

```typescript
import * as jose from "jose";

const ALG = "HS256";
const ISSUER = "bahraini-kout";
const EXPIRATION = "30d";

export async function signToken(uid: string, secret: string): Promise<string> {
  const key = new TextEncoder().encode(secret);
  return new jose.SignJWT({ uid })
    .setProtectedHeader({ alg: ALG })
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(EXPIRATION)
    .sign(key);
}

export async function verifyToken(token: string, secret: string): Promise<string> {
  const key = new TextEncoder().encode(secret);
  const { payload } = await jose.jwtVerify(token, key, { issuer: ISSUER });
  const uid = payload.uid;
  if (typeof uid !== "string") {
    throw new Error("Invalid token: missing uid");
  }
  return uid;
}
```

- [ ] **Step 4: Run tests**

Run: `cd workers && npx vitest run test/auth/`
Expected: All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add workers/src/auth/ workers/test/auth/
git commit -m "feat: add JWT-based anonymous auth (replaces Firebase Auth)"
```

---

## Task 4: D1 Schema + Matchmaking Queue

**Files:**
- Create: `workers/migrations/0001_init.sql`
- Create: `workers/src/matchmaking/queue.ts`
- Create: `workers/src/matchmaking/matcher.ts`
- Create: `workers/test/matchmaking/matcher.test.ts`
- Create: `workers/test/matchmaking/queue.test.ts`

- [ ] **Step 1: Create D1 migration**

Create `workers/migrations/0001_init.sql`:

```sql
-- Users: anonymous identities with ELO
CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,
  elo_rating INTEGER NOT NULL DEFAULT 1000,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Matchmaking queue
CREATE TABLE IF NOT EXISTS matchmaking_queue (
  uid TEXT PRIMARY KEY REFERENCES users(uid),
  elo_rating INTEGER NOT NULL,
  queued_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Game history (for ELO updates after games end)
CREATE TABLE IF NOT EXISTS game_history (
  game_id TEXT PRIMARY KEY,
  players TEXT NOT NULL,          -- JSON array of UIDs in seat order
  winner_team TEXT,               -- 'teamA' | 'teamB' | null (in progress)
  final_scores TEXT NOT NULL,     -- JSON: {"teamA": N, "teamB": N}
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_queue_elo ON matchmaking_queue(elo_rating);
CREATE INDEX IF NOT EXISTS idx_queue_time ON matchmaking_queue(queued_at);
```

- [ ] **Step 2: Port matcher logic**

Create `workers/src/matchmaking/matcher.ts` — port from `functions/src/matchmaking/match-players.ts`, extracting only the pure functions (`findBestMatch`, `calculateBracket`, `assignSeats`). Remove all Firebase imports and Firestore trigger code:

```typescript
export interface QueuedPlayer {
  uid: string;
  eloRating: number;
  queuedAt: string; // ISO 8601
}

export function calculateBracket(queuedAt: string): number {
  const waitTimeMs = Date.now() - new Date(queuedAt).getTime();
  const waitTimeSec = waitTimeMs / 1000;
  const expansions = Math.floor(waitTimeSec / 15);
  return Math.min(200 + expansions * 100, 500);
}

export function findBestMatch(players: QueuedPlayer[]): QueuedPlayer[] | null {
  if (players.length < 4) return null;

  const sorted = [...players].sort((a, b) => a.eloRating - b.eloRating);

  let bestWindow: QueuedPlayer[] | null = null;
  let bestSpread = Infinity;

  for (let i = 0; i <= sorted.length - 4; i++) {
    const window = sorted.slice(i, i + 4);
    const spread = window[3].eloRating - window[0].eloRating;

    const maxBracket = Math.max(
      ...window.map((p) => calculateBracket(p.queuedAt))
    );

    if (spread <= maxBracket * 2 && spread < bestSpread) {
      bestSpread = spread;
      bestWindow = window;
    }
  }

  return bestWindow;
}

export function assignSeats(players: QueuedPlayer[]): string[] {
  const seats = [0, 1, 2, 3];
  for (let i = seats.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [seats[i], seats[j]] = [seats[j], seats[i]];
  }
  const playersInSeatOrder = new Array<string>(4);
  players.forEach((p, idx) => {
    playersInSeatOrder[seats[idx]] = p.uid;
  });
  return playersInSeatOrder;
}
```

- [ ] **Step 3: Implement D1 queue operations**

Create `workers/src/matchmaking/queue.ts`:

```typescript
import type { QueuedPlayer } from "./matcher";

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
      "SELECT uid, elo_rating as eloRating, queued_at as queuedAt FROM matchmaking_queue ORDER BY queued_at ASC"
    )
    .all<{ uid: string; eloRating: number; queuedAt: string }>();
  return rows.results;
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

  // Update ELO ratings
  const teamAUids = [players[0], players[2]];
  const teamBUids = [players[1], players[3]];
  const winners = winnerTeam === "teamA" ? teamAUids : teamBUids;
  const losers = winnerTeam === "teamA" ? teamBUids : teamAUids;

  // Simple ELO: winners +16, losers -16 (K=32, expected=0.5 for equal teams)
  for (const uid of winners) {
    await db
      .prepare("UPDATE users SET elo_rating = elo_rating + 16, updated_at = datetime('now') WHERE uid = ?")
      .bind(uid)
      .run();
  }
  for (const uid of losers) {
    await db
      .prepare("UPDATE users SET elo_rating = MAX(0, elo_rating - 16), updated_at = datetime('now') WHERE uid = ?")
      .bind(uid)
      .run();
  }
}
```

- [ ] **Step 4: Write matcher tests**

Create `workers/test/matchmaking/matcher.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { findBestMatch, calculateBracket, assignSeats } from "../../src/matchmaking/matcher";

describe("calculateBracket", () => {
  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => { vi.useRealTimers(); });

  it("starts at 200", () => {
    const now = new Date("2026-03-23T12:00:00Z");
    vi.setSystemTime(now);
    expect(calculateBracket(now.toISOString())).toBe(200);
  });

  it("expands to 300 after 15s", () => {
    const now = new Date("2026-03-23T12:00:15Z");
    vi.setSystemTime(now);
    expect(calculateBracket("2026-03-23T12:00:00Z")).toBe(300);
  });

  it("caps at 500", () => {
    const now = new Date("2026-03-23T12:05:00Z");
    vi.setSystemTime(now);
    expect(calculateBracket("2026-03-23T12:00:00Z")).toBe(500);
  });
});

describe("findBestMatch", () => {
  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => { vi.useRealTimers(); });

  it("returns null with fewer than 4 players", () => {
    expect(findBestMatch([
      { uid: "a", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
    ])).toBeNull();
  });

  it("matches 4 players within ELO bracket", () => {
    vi.setSystemTime(new Date("2026-03-23T12:00:00Z"));
    const players = [
      { uid: "a", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "b", eloRating: 1100, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "c", eloRating: 1050, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "d", eloRating: 1150, queuedAt: "2026-03-23T12:00:00Z" },
    ];
    const result = findBestMatch(players);
    expect(result).not.toBeNull();
    expect(result!.length).toBe(4);
  });
});

describe("assignSeats", () => {
  it("assigns all 4 players to unique seats", () => {
    const players = [
      { uid: "a", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "b", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "c", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
      { uid: "d", eloRating: 1000, queuedAt: "2026-03-23T12:00:00Z" },
    ];
    const seats = assignSeats(players);
    expect(seats.length).toBe(4);
    expect(new Set(seats).size).toBe(4);
  });
});
```

- [ ] **Step 5: Run tests**

Run: `cd workers && npx vitest run test/matchmaking/`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add workers/migrations/ workers/src/matchmaking/ workers/test/matchmaking/
git commit -m "feat: add D1 matchmaking queue + ELO bracket matcher (replaces Firestore trigger)"
```

---

## Task 5: GameRoom Durable Object

This is the core of the migration. The GameRoom DO replaces Firestore game documents, Cloud Functions transactions, and real-time listeners — all in one class.

> **Note:** This task is large but the GameRoom class is a single cohesive unit. Implement in stages: scaffold → bidding → trump → playing → disconnect. Test each handler after adding it.

**Files:**
- Create: `workers/src/game/game-room.ts`
- Create: `workers/test/game/game-room.test.ts`

- [ ] **Step 1a: Create GameRoom scaffold with init, state persistence, and WebSocket upgrade**

Start with just the constructor, `initGame()`, `fetch()` (WS upgrade + /init), `persistState()`, `loadState()`, `getPublicState()`, and broadcast helpers. No game action handlers yet.

- [ ] **Step 1b: Add bidding handler (`handleBid`)**

Add the `handleBid` method and wire it into `webSocketMessage`. Test manually or with a unit test that the bid state transitions work.

- [ ] **Step 1c: Add trump selection handler (`handleSelectTrump`)**

Add `handleSelectTrump`. Verify phase transitions from TRUMP_SELECTION → PLAYING.

- [ ] **Step 1d: Add play card handler (`handlePlayCard`)**

Add `handlePlayCard` with poison joker detection, trick resolution, and round completion. This is the most complex handler.

- [ ] **Step 1e: Add disconnect/alarm handler (`webSocketClose`, `alarm`, `handleForfeit`)**

Add WebSocket close handling, alarm scheduling, and forfeit logic.

- [ ] **Step 1f: Add reshuffle handler (`reshuffleDeal`)**

Add the malzoom reshuffle-and-redeal flow.

- [ ] **Step 1 (full): Complete GameRoom implementation**

The full file, assembled from steps 1a-1f:

Create `workers/src/game/game-room.ts`:

```typescript
import { DurableObject } from "cloudflare:workers";
import type { Env } from "../env";
import type {
  GameDocument,
  GamePhase,
  TeamName,
  SuitName,
  TrickPlay,
  BiddingState,
} from "./types";
import { buildFourPlayerDeck, dealHands } from "./deck";
import { decodeCard } from "./card";
import { validateBid, validatePass, checkBiddingComplete, checkMalzoom } from "./bid-validator";
import { validatePlay, detectPoisonJoker } from "./play-validator";
import { resolveTrick } from "./trick-resolver";
import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyScore,
  checkGameOver,
} from "./scorer";

interface PlayerConnection {
  uid: string;
  ws: WebSocket;
}

type ClientAction =
  | { action: "placeBid"; data: { bidAmount: number } }
  | { action: "selectTrump"; data: { suit: string } }
  | { action: "playCard"; data: { card: string } };

export class GameRoom extends DurableObject<Env> {
  private game: GameDocument | null = null;
  private hands: Map<string, string[]> = new Map();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Auto ping/pong without waking DO
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair("ping", "pong")
    );
  }

  /**
   * Called by the Worker to initialize a new game with 4 players.
   */
  async initGame(playerUids: string[]): Promise<string> {
    const gameId = this.ctx.id.toString();

    const deck = buildFourPlayerDeck();
    const dealtHands = dealHands(deck);

    const dealer = playerUids[0];
    const firstBidder = playerUids[1];

    this.game = {
      phase: "BIDDING",
      players: playerUids,
      currentTrick: null,
      tricks: { teamA: 0, teamB: 0 },
      scores: { teamA: 0, teamB: 0 },
      bid: null,
      biddingState: {
        currentBidder: firstBidder,
        highestBid: null,
        highestBidder: null,
        passed: [],
      },
      trumpSuit: null,
      dealer,
      currentPlayer: firstBidder,
      reshuffleCount: 0,
      roundHistory: [],
      metadata: { createdAt: new Date().toISOString(), status: "active" },
    };

    // Store hands
    for (let i = 0; i < 4; i++) {
      const hand = dealtHands[i].map((c) => c.code);
      this.hands.set(playerUids[i], hand);
    }

    // Persist to storage
    await this.persistState();

    return gameId;
  }

  /**
   * HTTP fetch handler — used for WebSocket upgrade.
   */
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/ws") {
      if (request.headers.get("Upgrade") !== "websocket") {
        return new Response("Expected WebSocket", { status: 426 });
      }

      const uid = url.searchParams.get("uid");
      if (!uid) {
        return new Response("Missing uid", { status: 400 });
      }

      // Restore state if needed
      await this.loadState();

      if (this.game && !this.game.players.includes(uid)) {
        return new Response("Not a player in this game", { status: 403 });
      }

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      // Tag the WebSocket with the player's UID for later identification
      this.ctx.acceptWebSocket(server, [uid]);

      // Send initial state to this player
      server.send(JSON.stringify({
        event: "gameState",
        data: this.getPublicState(),
      }));

      const hand = this.hands.get(uid);
      if (hand) {
        server.send(JSON.stringify({
          event: "hand",
          data: { hand },
        }));
      }

      // Cancel any disconnect alarm for this player
      const alarmKey = `disconnect:${uid}`;
      await this.ctx.storage.delete(alarmKey);

      return new Response(null, { status: 101, webSocket: client });
    }

    if (url.pathname === "/init") {
      const body = await request.json<{ players: string[] }>();
      const gameId = await this.initGame(body.players);
      return Response.json({ gameId });
    }

    return new Response("Not found", { status: 404 });
  }

  /**
   * Handle incoming WebSocket messages from players.
   */
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message !== "string") return;

    const tags = this.ctx.getTags(ws);
    const uid = tags[0];
    if (!uid) return;

    await this.loadState();
    if (!this.game) {
      this.sendError(ws, "NO_GAME", "No game in progress");
      return;
    }

    let parsed: ClientAction;
    try {
      parsed = JSON.parse(message) as ClientAction;
    } catch {
      this.sendError(ws, "INVALID_JSON", "Could not parse message");
      return;
    }

    try {
      switch (parsed.action) {
        case "placeBid":
          await this.handleBid(uid, parsed.data.bidAmount);
          break;
        case "selectTrump":
          await this.handleSelectTrump(uid, parsed.data.suit);
          break;
        case "playCard":
          await this.handlePlayCard(uid, parsed.data.card);
          break;
        default:
          this.sendError(ws, "UNKNOWN_ACTION", `Unknown action`);
          return;
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      this.sendError(ws, "ACTION_FAILED", msg);
    }
  }

  /**
   * Handle WebSocket close — start disconnect timer.
   */
  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean): Promise<void> {
    const tags = this.ctx.getTags(ws);
    const uid = tags[0];
    if (!uid) return;

    await this.loadState();
    if (!this.game || this.game.phase === "GAME_OVER") return;

    // Set a disconnect alarm for 90 seconds
    const alarmKey = `disconnect:${uid}`;
    await this.ctx.storage.put(alarmKey, Date.now());

    // Schedule alarm if not already set
    const currentAlarm = await this.ctx.storage.getAlarm();
    if (!currentAlarm) {
      await this.ctx.storage.setAlarm(Date.now() + 90_000);
    }

    ws.close(code, reason);
  }

  /**
   * Alarm handler — check for expired disconnect timers.
   */
  async alarm(): Promise<void> {
    await this.loadState();
    if (!this.game || this.game.phase === "GAME_OVER") return;

    const now = Date.now();
    let nextAlarm: number | null = null;

    for (const uid of this.game.players) {
      const alarmKey = `disconnect:${uid}`;
      const disconnectTime = await this.ctx.storage.get<number>(alarmKey);
      if (!disconnectTime) continue;

      const elapsed = now - disconnectTime;
      if (elapsed >= 90_000) {
        // Player has been disconnected for 90s — forfeit
        await this.handleForfeit(uid);
        await this.ctx.storage.delete(alarmKey);
        // After forfeit, game state changed — re-check if game is over
        if (this.game?.phase === "GAME_OVER") return;
        continue; // Check remaining players too
      } else {
        // Not yet expired — schedule next check
        const remaining = 90_000 - elapsed;
        if (!nextAlarm || remaining < nextAlarm) {
          nextAlarm = remaining;
        }
      }
    }

    if (nextAlarm) {
      await this.ctx.storage.setAlarm(Date.now() + nextAlarm);
    }
  }

  // ─── Game Action Handlers ────────────────────────────────────────────────

  private async handleBid(uid: string, bidAmount: number): Promise<void> {
    const game = this.game!;
    if (game.phase !== "BIDDING") throw new Error("Not in BIDDING phase");

    const biddingState = game.biddingState!;
    if (biddingState.currentBidder !== uid) throw new Error("Not your turn to bid");

    const isPass = bidAmount === 0;

    if (isPass) {
      const validation = validatePass(biddingState.passed, uid);
      if (!validation.valid) throw new Error(validation.error!);

      const newPassed = [...biddingState.passed, uid];
      const malzoomOutcome = checkMalzoom(newPassed, game.reshuffleCount);

      if (malzoomOutcome === "reshuffle") {
        await this.reshuffleDeal();
        return;
      }

      if (malzoomOutcome === "forcedBid") {
        game.phase = "TRUMP_SELECTION";
        game.bid = { player: game.dealer, amount: 5 };
        game.biddingState = {
          ...biddingState,
          passed: newPassed,
          highestBid: 5,
          highestBidder: game.dealer,
        };
        game.currentPlayer = game.dealer;
        await this.persistAndBroadcast();
        return;
      }

      const complete = checkBiddingComplete(
        newPassed,
        biddingState.highestBid,
        biddingState.highestBidder
      );

      if (complete.complete) {
        game.phase = "TRUMP_SELECTION";
        game.bid = { player: complete.winner!, amount: complete.bid! };
        game.biddingState = { ...biddingState, passed: newPassed };
        game.currentPlayer = complete.winner!;
        await this.persistAndBroadcast();
        return;
      }

      // Advance to next bidder
      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = this.nextBidder(game.players, currentIndex, newPassed);
      game.biddingState = { ...biddingState, passed: newPassed, currentBidder: nextPlayer };
      game.currentPlayer = nextPlayer;
    } else {
      const validation = validateBid(bidAmount, biddingState.highestBid, biddingState.passed, uid);
      if (!validation.valid) throw new Error(validation.error!);

      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = this.nextBidder(game.players, currentIndex, biddingState.passed);
      game.biddingState = {
        ...biddingState,
        highestBid: bidAmount,
        highestBidder: uid,
        currentBidder: nextPlayer,
      };
      game.currentPlayer = nextPlayer;
    }

    await this.persistAndBroadcast();
  }

  private async handleSelectTrump(uid: string, suit: string): Promise<void> {
    const game = this.game!;
    if (game.phase !== "TRUMP_SELECTION") throw new Error("Not in TRUMP_SELECTION phase");
    if (!game.bid || game.bid.player !== uid) throw new Error("Only winning bidder can select trump");

    const validSuits: SuitName[] = ["spades", "hearts", "clubs", "diamonds"];
    if (!validSuits.includes(suit as SuitName)) throw new Error(`Invalid suit: ${suit}`);

    const firstPlayer = this.nextPlayerClockwise(game.players, uid);
    game.phase = "PLAYING";
    game.trumpSuit = suit as SuitName;
    game.currentPlayer = firstPlayer;
    game.currentTrick = { lead: firstPlayer, plays: [] };
    game.tricks = { teamA: 0, teamB: 0 };

    await this.persistAndBroadcast();
  }

  private async handlePlayCard(uid: string, card: string): Promise<void> {
    const game = this.game!;
    if (game.phase !== "PLAYING") throw new Error("Not in PLAYING phase");
    if (game.currentPlayer !== uid) throw new Error("Not your turn to play");

    const hand = this.hands.get(uid);
    if (!hand) throw new Error("Hand not found");

    // Poison Joker check
    if (detectPoisonJoker(hand)) {
      const poisonTeam = this.getTeamForPlayer(uid);
      const roundResult = calculatePoisonJokerResult(poisonTeam);
      const newScores = applyScore(game.scores, roundResult.winningTeam, roundResult.points);
      const gameWinner = checkGameOver(newScores);

      game.scores = newScores;
      game.phase = gameWinner ? "GAME_OVER" : "ROUND_SCORING";
      if (gameWinner) {
        game.metadata = { ...game.metadata, status: "completed", winner: gameWinner };
      }

      this.hands.set(uid, []);
      await this.persistAndBroadcast();
      this.broadcastHands();
      return;
    }

    // Validate play
    const currentTrick = game.currentTrick!;
    const isLeadPlay = currentTrick.plays.length === 0;
    const ledSuit = isLeadPlay ? null : (() => {
      const leadCard = decodeCard(currentTrick.plays[0].card);
      return leadCard.isJoker ? null : leadCard.suit;
    })();

    const validation = validatePlay(card, hand, ledSuit, isLeadPlay);
    if (!validation.valid) throw new Error(validation.error!);

    // Remove from hand
    const newHand = hand.filter((c) => c !== card);
    this.hands.set(uid, newHand);

    // Add play to trick
    const newPlay: TrickPlay = { player: uid, card };
    const newPlays = [...currentTrick.plays, newPlay];

    if (newPlays.length < 4) {
      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = game.players[(currentIndex + 1) % game.players.length];
      game.currentTrick = { ...currentTrick, plays: newPlays };
      game.currentPlayer = nextPlayer;
      await this.persistAndBroadcast();
      this.sendHandToPlayer(uid, newHand);
      return;
    }

    // Resolve trick
    const completedPlays = newPlays;
    const leadCardObj = decodeCard(completedPlays[0].card);
    const resolvedLedSuit = leadCardObj.isJoker ? game.trumpSuit! : leadCardObj.suit!;
    const trickWinner = resolveTrick(completedPlays, resolvedLedSuit, game.trumpSuit!);
    const winnerTeam = this.getTeamForPlayer(trickWinner);

    game.tricks[winnerTeam] += 1;
    const totalTricks = game.tricks.teamA + game.tricks.teamB;
    game.roundHistory = [...(game.roundHistory ?? []), completedPlays];

    if (totalTricks < 8) {
      game.currentTrick = { lead: trickWinner, plays: [] };
      game.currentPlayer = trickWinner;
      await this.persistAndBroadcast();
      this.broadcastHands();
      return;
    }

    // Round complete
    const bidInfo = game.bid!;
    const biddingTeam = this.getTeamForPlayer(bidInfo.player);
    const roundResult = calculateRoundResult(bidInfo.amount, biddingTeam, game.tricks);
    const newScores = applyScore(game.scores, roundResult.winningTeam, roundResult.points);
    const gameWinner = checkGameOver(newScores);

    game.phase = gameWinner ? "GAME_OVER" : "ROUND_SCORING";
    game.scores = newScores;
    game.currentTrick = null;
    if (gameWinner) {
      game.metadata = { ...game.metadata, status: "completed", winner: gameWinner };
    }

    await this.persistAndBroadcast();
    this.broadcastHands();
  }

  private async handleForfeit(disconnectedUid: string): Promise<void> {
    const game = this.game!;
    const playerTeam = this.getTeamForPlayer(disconnectedUid);
    const winningTeam: TeamName = playerTeam === "teamA" ? "teamB" : "teamA";

    // Use bid failure penalty if bid is active, otherwise 10
    let penalty = 10;
    if (game.bid) {
      const { 5: p5, 6: p6, 7: p7, 8: p8 } = { 5: 10, 6: 12, 7: 14, 8: 31 };
      const penaltyMap: Record<number, number> = { 5: p5, 6: p6, 7: p7, 8: p8 };
      penalty = penaltyMap[game.bid.amount] ?? 10;
    }

    game.scores[winningTeam] += penalty;
    const gameWinner = checkGameOver(game.scores);
    game.phase = gameWinner ? "GAME_OVER" : "ROUND_SCORING";
    if (gameWinner) {
      game.metadata = { ...game.metadata, status: "completed", winner: gameWinner };
    }

    await this.persistAndBroadcast();
  }

  private async reshuffleDeal(): Promise<void> {
    const game = this.game!;
    const deck = buildFourPlayerDeck();
    const dealtHands = dealHands(deck);

    for (let i = 0; i < 4; i++) {
      this.hands.set(game.players[i], dealtHands[i].map((c) => c.code));
    }

    game.reshuffleCount += 1;
    game.phase = "BIDDING";
    game.bid = null;
    game.trumpSuit = null;
    game.currentTrick = null;
    game.tricks = { teamA: 0, teamB: 0 };

    // Rotate dealer
    const dealerIdx = game.players.indexOf(game.dealer);
    game.dealer = game.players[(dealerIdx + 1) % game.players.length];
    const firstBidder = game.players[(game.players.indexOf(game.dealer) + 1) % game.players.length];
    game.biddingState = {
      currentBidder: firstBidder,
      highestBid: null,
      highestBidder: null,
      passed: [],
    };
    game.currentPlayer = firstBidder;

    await this.persistAndBroadcast();
    this.broadcastHands();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  private getTeamForPlayer(uid: string): TeamName {
    const idx = this.game!.players.indexOf(uid);
    return idx % 2 === 0 ? "teamA" : "teamB";
  }

  private nextPlayerClockwise(players: string[], currentUid: string): string {
    const idx = players.indexOf(currentUid);
    return players[(idx + 1) % players.length];
  }

  private nextBidder(players: string[], currentIndex: number, passed: string[]): string {
    for (let i = 1; i < players.length; i++) {
      const idx = (currentIndex + i) % players.length;
      if (!passed.includes(players[idx])) return players[idx];
    }
    return players[(currentIndex + 1) % players.length];
  }

  private getPublicState(): Omit<GameDocument, "metadata"> & { gameId: string } {
    const game = this.game!;
    return {
      gameId: this.ctx.id.toString(),
      phase: game.phase,
      players: game.players,
      currentTrick: game.currentTrick,
      tricks: game.tricks,
      scores: game.scores,
      bid: game.bid,
      biddingState: game.biddingState,
      trumpSuit: game.trumpSuit,
      dealer: game.dealer,
      currentPlayer: game.currentPlayer,
      reshuffleCount: game.reshuffleCount,
      roundHistory: game.roundHistory,
    };
  }

  private broadcastAll(message: object): void {
    const json = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(json);
      } catch {
        // WebSocket already closed
      }
    }
  }

  private broadcastHands(): void {
    for (const ws of this.ctx.getWebSockets()) {
      const tags = this.ctx.getTags(ws);
      const uid = tags[0];
      if (!uid) continue;
      const hand = this.hands.get(uid);
      if (hand) {
        try {
          ws.send(JSON.stringify({ event: "hand", data: { hand } }));
        } catch {
          // closed
        }
      }
    }
  }

  private sendHandToPlayer(uid: string, hand: string[]): void {
    for (const ws of this.ctx.getWebSockets()) {
      const tags = this.ctx.getTags(ws);
      if (tags[0] === uid) {
        try {
          ws.send(JSON.stringify({ event: "hand", data: { hand } }));
        } catch {
          // closed
        }
        return;
      }
    }
  }

  private sendError(ws: WebSocket, code: string, message: string): void {
    try {
      ws.send(JSON.stringify({ event: "error", data: { code, message } }));
    } catch {
      // closed
    }
  }

  private async persistAndBroadcast(): Promise<void> {
    await this.persistState();
    this.broadcastAll({ event: "gameState", data: this.getPublicState() });
  }

  private async persistState(): Promise<void> {
    await this.ctx.storage.put("game", this.game);
    const handsObj: Record<string, string[]> = {};
    for (const [uid, hand] of this.hands) {
      handsObj[uid] = hand;
    }
    await this.ctx.storage.put("hands", handsObj);
  }

  private async loadState(): Promise<void> {
    if (this.game) return; // Already loaded
    this.game = (await this.ctx.storage.get<GameDocument>("game")) ?? null;
    const handsObj = await this.ctx.storage.get<Record<string, string[]>>("hands");
    if (handsObj) {
      this.hands = new Map(Object.entries(handsObj));
    }
  }
}
```

- [ ] **Step 2: Write GameRoom unit test**

Create `workers/test/game/game-room.test.ts`:

```typescript
import { describe, it, expect } from "vitest";

// GameRoom is a Durable Object — full integration testing requires
// the Cloudflare test pool. For now, test the logic indirectly
// through the pure game logic functions (already tested in other files).
// This file will contain miniflare-based integration tests.

describe("GameRoom (integration placeholder)", () => {
  it.todo("initializes game with 4 players and deals 8 cards each");
  it.todo("accepts WebSocket upgrade for valid player");
  it.todo("rejects WebSocket upgrade for non-player");
  it.todo("broadcasts state update after bid");
  it.todo("sends private hand only to owning player");
  it.todo("handles full game flow: bid → trump → play → score");
  it.todo("handles poison joker scenario");
  it.todo("handles malzoom reshuffle and forced bid");
  it.todo("handles disconnect → alarm → forfeit");
});
```

- [ ] **Step 3: Run tests**

Run: `cd workers && npx vitest run`
Expected: All existing tests pass, placeholder todos are skipped

- [ ] **Step 4: Commit**

```bash
git add workers/src/game/game-room.ts workers/test/game/game-room.test.ts
git commit -m "feat: implement GameRoom Durable Object (replaces Firestore + Cloud Functions)"
```

---

## Task 6: MatchmakingLobby Durable Object

Players waiting in queue connect via WebSocket to a lobby DO that notifies them when a match is found.

**Files:**
- Create: `workers/src/matchmaking/lobby.ts`

- [ ] **Step 1: Implement MatchmakingLobby DO**

Create `workers/src/matchmaking/lobby.ts`:

```typescript
import { DurableObject } from "cloudflare:workers";
import type { Env } from "../env";

/**
 * Single global lobby DO that players connect to while waiting for a match.
 * When the Worker finds a match, it calls /notify on this DO to inform players.
 */
export class MatchmakingLobby extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair("ping", "pong")
    );
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/ws") {
      if (request.headers.get("Upgrade") !== "websocket") {
        return new Response("Expected WebSocket", { status: 426 });
      }

      const uid = url.searchParams.get("uid");
      if (!uid) return new Response("Missing uid", { status: 400 });

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      this.ctx.acceptWebSocket(server, [uid]);

      return new Response(null, { status: 101, webSocket: client });
    }

    if (url.pathname === "/notify") {
      const body = await request.json<{ gameId: string; players: string[] }>();
      const { gameId, players } = body;

      for (const ws of this.ctx.getWebSockets()) {
        const tags = this.ctx.getTags(ws);
        const uid = tags[0];
        if (uid && players.includes(uid)) {
          try {
            ws.send(JSON.stringify({ event: "matched", data: { gameId } }));
            ws.close(1000, "matched");
          } catch {
            // already closed
          }
        }
      }

      return Response.json({ notified: players.length });
    }

    if (url.pathname === "/remove") {
      const body = await request.json<{ uid: string }>();
      for (const ws of this.ctx.getWebSockets()) {
        const tags = this.ctx.getTags(ws);
        if (tags[0] === body.uid) {
          try {
            ws.close(1000, "left queue");
          } catch {
            // closed
          }
        }
      }
      return Response.json({ removed: true });
    }

    return new Response("Not found", { status: 404 });
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string): Promise<void> {
    ws.close(code, reason);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add workers/src/matchmaking/lobby.ts
git commit -m "feat: add MatchmakingLobby Durable Object for queue notifications"
```

---

## Task 7: Worker Router (Tying It All Together)

Wire up the Hono router with all HTTP endpoints and WebSocket upgrade paths.

**Files:**
- Modify: `workers/src/index.ts`
- Modify: `workers/src/env.ts`

- [ ] **Step 1: Implement full Worker router**

Replace `workers/src/index.ts`:

```typescript
import { Hono } from "hono";
import type { Env } from "./env";
import { signToken, verifyToken } from "./auth/jwt";
import { joinQueue, leaveQueue, getQueuedPlayers, removePlayersFromQueue, recordGame } from "./matchmaking/queue";
import { findBestMatch, assignSeats } from "./matchmaking/matcher";
import { buildFourPlayerDeck, dealHands } from "./game/deck";

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
    const playersInSeatOrder = assignSeats(matched);
    const matchedUids = matched.map((p) => p.uid);

    // Remove matched players from D1 queue
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
  const url = new URL(c.req.url);
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
```

- [ ] **Step 2: Run type check**

Run: `cd workers && npx tsc --noEmit`
Expected: No TypeScript errors

- [ ] **Step 3: Commit**

```bash
git add workers/src/index.ts
git commit -m "feat: wire up Hono router with auth, matchmaking, and WebSocket game endpoints"
```

---

## Task 8: Rewrite Flutter Client Services

Remove all Firebase dependencies and replace with HTTP + WebSocket calls.

**Files:**
- Create: `lib/app/config.dart`
- Modify: `lib/main.dart`
- Rewrite: `lib/app/services/auth_service.dart`
- Rewrite: `lib/app/services/game_service.dart`
- Rewrite: `lib/app/services/matchmaking_service.dart`
- Rewrite: `lib/app/services/presence_service.dart`
- Modify: `lib/app/models/client_game_state.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Update `pubspec.yaml` — remove Firebase, add HTTP + WS deps**

Remove:
```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
cloud_functions: ^5.0.0
firebase_messaging: ^15.0.0
```

Add:
```yaml
http: ^1.2.0
web_socket_channel: ^3.0.0
shared_preferences: ^2.2.0
```

- [ ] **Step 2: Create `lib/app/config.dart`**

```dart
class AppConfig {
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'http://localhost:8787',
  );

  static String get wsUrl {
    final uri = Uri.parse(workerUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}';
  }
}
```

- [ ] **Step 3: Rewrite `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KoutApp());
}
```

- [ ] **Step 4: Rewrite `lib/app/services/auth_service.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  String? _uid;
  String? _token;

  String? get currentUid => _uid;
  String? get token => _token;
  bool get isAuthenticated => _uid != null && _token != null;

  Future<void> signInAnonymously() async {
    // Check for cached credentials
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('auth_token');
    final cachedUid = prefs.getString('auth_uid');

    if (cachedToken != null && cachedUid != null) {
      _token = cachedToken;
      _uid = cachedUid;
      return;
    }

    // Request new anonymous identity
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/auth/anonymous'),
    );

    if (response.statusCode != 200) {
      throw Exception('Auth failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _uid = body['uid'] as String;
    _token = body['token'] as String;

    // Cache credentials
    await prefs.setString('auth_token', _token!);
    await prefs.setString('auth_uid', _uid!);
  }

  Future<void> signOut() async {
    _uid = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_uid');
  }
}
```

- [ ] **Step 5: Rewrite `lib/app/services/matchmaking_service.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

class MatchmakingService {
  final String _token;
  final String _myUid;
  WebSocketChannel? _lobbyChannel;

  MatchmakingService({required String token, required String myUid})
      : _token = token,
        _myUid = myUid;

  Future<String?> joinQueue(int eloRating) async {
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/matchmaking/join'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'eloRating': eloRating}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to join queue: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] == 'matched') {
      return body['gameId'] as String;
    }

    return null; // Queued, wait for WS notification
  }

  Stream<String> listenForMatch() {
    final controller = StreamController<String>();

    _lobbyChannel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsUrl}/ws/matchmaking?token=$_token'),
    );

    _lobbyChannel!.stream.listen(
      (message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        if (data['event'] == 'matched') {
          final gameId = (data['data'] as Map<String, dynamic>)['gameId'] as String;
          controller.add(gameId);
          controller.close();
        }
      },
      onError: (error) {
        controller.addError(error as Object);
        controller.close();
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    return controller.stream;
  }

  Future<void> leaveQueue() async {
    _lobbyChannel?.sink.close();
    _lobbyChannel = null;

    await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/matchmaking/leave'),
      headers: {'Authorization': 'Bearer $_token'},
    );
  }

  void dispose() {
    _lobbyChannel?.sink.close();
    _lobbyChannel = null;
  }
}
```

- [ ] **Step 6: Rewrite `lib/app/services/game_service.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/client_game_state.dart';

class GameService {
  final String _gameId;
  final String _myUid;
  final String _token;

  WebSocketChannel? _channel;
  final _stateController = StreamController<ClientGameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  Stream<ClientGameState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;

  List<String> _myHand = [];
  Map<String, dynamic>? _lastPublicState;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  GameService({
    required String gameId,
    required String myUid,
    required String token,
  })  : _gameId = gameId,
        _myUid = myUid,
        _token = token;

  void startListening() {
    _connect();
  }

  void _connect() {
    if (_disposed) return;

    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsUrl}/ws/game/$_gameId?token=$_token'),
    );

    _channel!.stream.listen(
      (message) {
        _reconnectAttempts = 0; // Reset on successful message
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final event = data['event'] as String;

        switch (event) {
          case 'gameState':
            _lastPublicState = data['data'] as Map<String, dynamic>;
            _stateController.add(
              ClientGameState.fromMap(_lastPublicState!, _myUid, _myHand),
            );
          case 'hand':
            final handData = data['data'] as Map<String, dynamic>;
            _myHand = List<String>.from(handData['hand'] as List<dynamic>);
            // Re-emit state with updated hand
            if (_lastPublicState != null) {
              _stateController.add(
                ClientGameState.fromMap(_lastPublicState!, _myUid, _myHand),
              );
            }
          case 'error':
            final errorData = data['data'] as Map<String, dynamic>;
            _errorController.add(errorData['message'] as String);
        }
      },
      onError: (error) {
        _errorController.add('Connection error: $error');
        _attemptReconnect();
      },
      onDone: () {
        if (!_disposed) _attemptReconnect();
      },
    );
  }

  void _attemptReconnect() {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    Future.delayed(delay, () => _connect());
  }

  void _sendAction(String action, Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode({'action': action, 'data': data}));
  }

  void sendBid(int bidAmount) =>
      _sendAction('placeBid', {'bidAmount': bidAmount});

  void sendPass() =>
      _sendAction('placeBid', {'bidAmount': 0});

  void sendTrumpSelection(String suit) =>
      _sendAction('selectTrump', {'suit': suit});

  void sendPlayCard(String cardCode) =>
      _sendAction('playCard', {'card': cardCode});

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _stateController.close();
    _errorController.close();
  }
}
```

- [ ] **Step 7: Rewrite `lib/app/services/presence_service.dart`**

```dart
/// Presence is now handled by the WebSocket connection itself.
/// When connected → present. When WS closes → GameRoom DO starts
/// a 90s disconnect alarm. No client-side heartbeat needed.
///
/// This class is kept for API compatibility but is essentially a no-op.
class PresenceService {
  void start() {
    // No-op: WebSocket connection IS the presence signal
  }

  void stop() {
    // No-op
  }

  Future<void> disconnect() async {
    // No-op: closing the WebSocket triggers server-side disconnect handling
  }

  void dispose() {
    // No-op
  }
}
```

- [ ] **Step 8: Commit**

```bash
git add lib/ pubspec.yaml
git commit -m "feat: rewrite Flutter services from Firebase to HTTP+WebSocket (Cloudflare Workers)"
```

---

## Task 9: Remove Firebase Files

**Files:**
- Delete: `lib/firebase_options.dart`
- Delete: `android/app/google-services.json`
- Delete: `ios/Runner/GoogleService-Info.plist`
- Delete: `macos/Runner/GoogleService-Info.plist`
- Delete: `firebase.json`
- Delete: `firestore.rules`
- Delete: `functions/` (entire directory)

- [ ] **Step 1: Remove all Firebase files**

```bash
rm -f lib/firebase_options.dart
rm -f android/app/google-services.json
rm -f ios/Runner/GoogleService-Info.plist
rm -f macos/Runner/GoogleService-Info.plist
rm -f firebase.json
rm -f firestore.rules
rm -rf functions/
```

- [ ] **Step 2: Remove Firebase plugin from Android build**

Edit `android/app/build.gradle`:
- Remove `apply plugin: 'com.google.gms.google-services'` (usually at the bottom)

Edit `android/build.gradle` (project-level):
- Remove `classpath 'com.google.gms:google-services:X.X.X'` from dependencies

- [ ] **Step 3: Remove Firebase from iOS/macOS**

```bash
cd ios && rm -f Podfile.lock && pod install && cd ..
cd macos && rm -f Podfile.lock && pod install && cd ..
```

Edit `ios/Runner/Info.plist` — remove any Firebase-specific entries if present.
Edit `macos/Runner/Info.plist` — same.

- [ ] **Step 4: Run `flutter pub get` and verify clean build**

```bash
flutter pub get
flutter analyze
flutter build apk --debug --dart-define=WORKER_URL=http://localhost:8787
```

Expected: No Firebase references in build output, no analysis errors

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove all Firebase files and dependencies"
```

---

## Task 10: Update Screen Wiring

Update the screens to use the new service constructors (they now need `token` parameter instead of Firebase instances).

**Files:**
- Modify: `lib/app/screens/home_screen.dart`
- Modify: `lib/app/screens/matchmaking_screen.dart`
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Update `home_screen.dart`**

Replace `FirebaseAuth` usage with new `AuthService`:

```dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    await _authService.signInAnonymously();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bahraini Kout', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/matchmaking',
                        arguments: {
                          'uid': _authService.currentUid,
                          'token': _authService.token,
                        },
                      );
                    },
                    child: const Text('Play'),
                  ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update `matchmaking_screen.dart`**

Replace `FirebaseFunctions` + `FirebaseFirestore` usage with new HTTP + WS service:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/matchmaking_service.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  late MatchmakingService _matchmakingService;
  StreamSubscription? _matchSub;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final uid = args['uid'] as String;
    final token = args['token'] as String;

    _matchmakingService = MatchmakingService(token: token, myUid: uid);
    _startMatchmaking(uid, token);
  }

  Future<void> _startMatchmaking(String uid, String token) async {
    // Try immediate match
    final immediateGameId = await _matchmakingService.joinQueue(1000);
    if (immediateGameId != null) {
      _navigateToGame(immediateGameId, uid, token);
      return;
    }

    // Listen for async match via WebSocket
    _matchSub = _matchmakingService.listenForMatch().listen((gameId) {
      _navigateToGame(gameId, uid, token);
    });
  }

  void _navigateToGame(String gameId, String uid, String token) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/game',
      arguments: {'gameId': gameId, 'uid': uid, 'token': token},
    );
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _matchmakingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text('Searching for opponents...'),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                _matchmakingService.leaveQueue();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update `game_screen.dart`**

Replace `FirebaseFirestore` + `FirebaseFunctions` with WebSocket-based `GameService`:

The `game_screen.dart` constructor now receives `token` in arguments. Update the service creation:

```dart
// In didChangeDependencies, change:
final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
final gameId = args['gameId'] as String;
final uid = args['uid'] as String;
final token = args['token'] as String;

_gameService = GameService(gameId: gameId, myUid: uid, token: token);
_gameService.startListening();

// PresenceService is now a no-op, can be removed or kept for API compat
```

- [ ] **Step 4: Verify build for each environment**

Local dev:
```bash
flutter run --dart-define=WORKER_URL=http://localhost:8787
```

Staging (after `wrangler deploy`):
```bash
flutter run --dart-define=WORKER_URL=https://bahraini-kout.YOUR_SUBDOMAIN.workers.dev
```

Production (custom domain):
```bash
flutter build apk --release --dart-define=WORKER_URL=https://api.yourdomain.com
flutter build ios --release --dart-define=WORKER_URL=https://api.yourdomain.com
```

Run analysis:
```bash
flutter analyze
```
Expected: No analysis errors, successful build

- [ ] **Step 5: Commit**

```bash
git add lib/app/screens/
git commit -m "feat: update screens to use new Cloudflare Workers-backed services"
```

---

## Task 11: Deploy + E2E Verification

**Files:**
- Modify: `workers/wrangler.toml` (update D1 database ID after creation)

- [ ] **Step 1: Create D1 database**

```bash
cd workers && npx wrangler d1 create kout-db
```

Update `wrangler.toml` with the returned `database_id`.

- [ ] **Step 2: Run D1 migration**

```bash
npx wrangler d1 execute kout-db --local --file=migrations/0001_init.sql
```

Expected: Tables created successfully

- [ ] **Step 3: Run all Workers tests**

```bash
cd workers && npx vitest run
```

Expected: All tests pass

- [ ] **Step 4: Start local dev server**

```bash
cd workers && npx wrangler dev
```

Expected: Server starts on port 8787

- [ ] **Step 5: Smoke test with curl**

```bash
# Anonymous auth
curl -s http://localhost:8787/auth/anonymous | jq

# Join queue (use token from above)
TOKEN="<token from above>"
curl -s -X POST http://localhost:8787/api/matchmaking/join \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"eloRating": 1000}' | jq

# Health check
curl -s http://localhost:8787/health | jq
```

- [ ] **Step 6: Deploy to Cloudflare**

```bash
cd workers
npx wrangler d1 execute kout-db --remote --file=migrations/0001_init.sql
npx wrangler secret put JWT_SECRET
npx wrangler deploy
```

- [ ] **Step 7: Update Flutter config and test**

```bash
flutter run --dart-define=WORKER_URL=https://bahraini-kout.<your-subdomain>.workers.dev
```

- [ ] **Step 8: Final commit**

```bash
git add -A
git commit -m "chore: deploy to Cloudflare Workers, remove all Firebase dependency"
```

---

## Migration Difficulty Assessment

| Component | Effort | Notes |
|---|---|---|
| Game logic (TS) | **Trivial** | Direct copy, zero Firebase deps in these files |
| GameRoom DO | **Medium** | Biggest piece — but it's essentially the Cloud Functions logic consolidated into one class |
| Matchmaking | **Easy** | D1 replaces Firestore, same algorithm |
| Auth | **Easy** | Simpler than Firebase Auth |
| Flutter services | **Medium** | 4 service files rewritten, same interfaces |
| Presence | **Trivial** | WebSocket lifecycle replaces polling |
| Delete Firebase | **Trivial** | rm -rf |

**Total estimate:** ~4-6 hours of AI-assisted coding time. The game logic ports are copy-paste. The real work is the GameRoom DO and the Flutter service rewrites.
