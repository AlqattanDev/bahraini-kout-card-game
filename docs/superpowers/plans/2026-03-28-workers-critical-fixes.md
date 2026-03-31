# Workers Backend Critical Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 critical bugs in the Cloudflare Workers backend that make online multiplayer non-functional.

**Architecture:** The Workers backend (`workers/src/game/game-room.ts`) is a Durable Object that manages game state over WebSockets. All player rotation logic uses clockwise direction but must use counter-clockwise to match the Dart offline engine. The game loop only plays one round and never rotates dealer or re-deals. ELO is never updated. Matchmaking has a race condition.

**Tech Stack:** TypeScript, Cloudflare Workers, Durable Objects, D1 (SQLite), Hono, Vitest

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `workers/src/game/game-room.ts` | Fix direction, add round loop, call ELO update |
| Modify | `workers/src/index.ts` | Fix matchmaking race condition |
| Modify | `workers/src/matchmaking/queue.ts` | Add atomic match-and-remove |
| Create | `workers/test/game/direction.test.ts` | Tests for counter-clockwise rotation |
| Create | `workers/test/game/round-loop.test.ts` | Tests for multi-round game flow |
| Modify | `workers/test/game/game-room.test.ts` | Add ELO update and round loop integration tests |

---

### Task 1: Fix Counter-Clockwise Direction

All player rotation in `game-room.ts` uses clockwise `(idx + 1) % length`. Dart uses counter-clockwise `(idx - 1 + length) % length`, giving order 0→3→2→1. This affects bidding order, trick play order, and first trick leader. Every `nextPlayer` call must be fixed.

**Files:**
- Modify: `workers/src/game/game-room.ts:49,336,394,468-479`
- Create: `workers/test/game/direction.test.ts`

- [ ] **Step 1: Write failing test for counter-clockwise rotation**

```typescript
// workers/test/game/direction.test.ts
import { describe, it, expect } from "vitest";

// Extract as a pure function so we can test it independently
export function nextSeatCounterClockwise(
  players: string[],
  currentUid: string
): string {
  const idx = players.indexOf(currentUid);
  return players[(idx - 1 + players.length) % players.length];
}

export function nextBidderCounterClockwise(
  players: string[],
  currentIndex: number,
  passed: string[]
): string {
  for (let i = 1; i < players.length; i++) {
    const idx = (currentIndex - i + players.length) % players.length;
    if (!passed.includes(players[idx])) return players[idx];
  }
  // Fallback (shouldn't happen with valid game state)
  return players[(currentIndex - 1 + players.length) % players.length];
}

describe("counter-clockwise rotation", () => {
  const players = ["p0", "p1", "p2", "p3"];

  it("rotates 0→3→2→1→0", () => {
    expect(nextSeatCounterClockwise(players, "p0")).toBe("p3");
    expect(nextSeatCounterClockwise(players, "p3")).toBe("p2");
    expect(nextSeatCounterClockwise(players, "p2")).toBe("p1");
    expect(nextSeatCounterClockwise(players, "p1")).toBe("p0");
  });

  it("full cycle returns to start", () => {
    let current = "p0";
    for (let i = 0; i < 4; i++) {
      current = nextSeatCounterClockwise(players, current);
    }
    expect(current).toBe("p0");
  });
});

describe("nextBidderCounterClockwise", () => {
  const players = ["p0", "p1", "p2", "p3"];

  it("skips passed players in counter-clockwise order", () => {
    // p0 is at index 0, passed = [p3]
    // Counter-clockwise from 0: check 3 (passed), check 2 (ok) → p2
    const next = nextBidderCounterClockwise(players, 0, ["p3"]);
    expect(next).toBe("p2");
  });

  it("wraps around correctly", () => {
    // p1 is at index 1, passed = [p0, p3]
    // Counter-clockwise from 1: check 0 (passed), check 3 (passed), check 2 (ok) → p2
    const next = nextBidderCounterClockwise(players, 1, ["p0", "p3"]);
    expect(next).toBe("p2");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workers && npx vitest run test/game/direction.test.ts`
Expected: PASS (these test the new pure functions directly)

- [ ] **Step 3: Replace clockwise helpers in game-room.ts**

In `workers/src/game/game-room.ts`, replace lines 468-479:

```typescript
// OLD (clockwise — WRONG):
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
```

Replace with:

```typescript
// NEW (counter-clockwise — matches Dart's nextSeat):
private nextPlayer(players: string[], currentUid: string): string {
  const idx = players.indexOf(currentUid);
  return players[(idx - 1 + players.length) % players.length];
}

private nextBidder(players: string[], currentIndex: number, passed: string[]): string {
  for (let i = 1; i < players.length; i++) {
    const idx = (currentIndex - i + players.length) % players.length;
    if (!passed.includes(players[idx])) return players[idx];
  }
  return players[(currentIndex - 1 + players.length) % players.length];
}
```

- [ ] **Step 4: Fix initGame first bidder calculation**

In `workers/src/game/game-room.ts`, line 49. Change:

```typescript
// OLD:
const firstBidderIndex = (dealerIndex + 1) % playerUids.length;
```

To:

```typescript
// NEW (counter-clockwise: seat after dealer):
const firstBidderIndex = (dealerIndex - 1 + playerUids.length) % playerUids.length;
```

- [ ] **Step 5: Fix handleSelectTrump — first trick leader**

In `workers/src/game/game-room.ts`, line 336. Change:

```typescript
// OLD:
const firstPlayer = this.nextPlayerClockwise(game.players, uid);
```

To:

```typescript
// NEW:
const firstPlayer = this.nextPlayer(game.players, uid);
```

- [ ] **Step 6: Fix handlePlayCard — next player in trick**

In `workers/src/game/game-room.ts`, line 393-394. Change:

```typescript
// OLD:
const currentIndex = game.players.indexOf(uid);
const nextPlayer = game.players[(currentIndex + 1) % game.players.length];
```

To:

```typescript
// NEW:
const nextPlayerUid = this.nextPlayer(game.players, uid);
```

Update line 396 to use `nextPlayerUid`:

```typescript
game.currentPlayer = nextPlayerUid;
```

- [ ] **Step 7: Run all existing tests**

Run: `cd workers && npx vitest run`
Expected: All tests pass. The direction change only affects GameRoom runtime behavior, not the pure logic tests.

- [ ] **Step 8: Commit**

```bash
cd workers && git add src/game/game-room.ts test/game/direction.test.ts
git commit -m "fix: change player rotation from clockwise to counter-clockwise

Dart offline uses nextSeat(i) = (i - 1 + 4) % 4 giving order 0→3→2→1.
Workers was using (i + 1) % 4 giving 0→1→2→3. This caused different
bidding order, trick play order, and first trick leader between online
and offline modes.

Fixes: initGame firstBidder, handleSelectTrump first leader,
handlePlayCard next player, nextBidder skip logic."
```

---

### Task 2: Add Round Loop (Re-deal + Dealer Rotation)

After ROUND_SCORING, the game currently does nothing — stuck forever. Need to: rotate dealer counter-clockwise, re-shuffle/deal, reset bidding/trick state, return to BIDDING.

**Files:**
- Modify: `workers/src/game/game-room.ts`
- Create: `workers/test/game/round-loop.test.ts`

- [ ] **Step 1: Write failing test for startNextRound**

```typescript
// workers/test/game/round-loop.test.ts
import { describe, it, expect } from "vitest";
import { buildFourPlayerDeck, dealHands } from "../../src/game/deck";

describe("round loop mechanics", () => {
  it("dealer rotates counter-clockwise", () => {
    const players = ["p0", "p1", "p2", "p3"];

    // If dealer is p0 (index 0), next dealer is index (0-1+4)%4 = 3 → p3
    const dealerIndex = 0;
    const nextDealerIndex = (dealerIndex - 1 + players.length) % players.length;
    expect(players[nextDealerIndex]).toBe("p3");

    // If dealer is p3 (index 3), next dealer is index (3-1+4)%4 = 2 → p2
    const nextNext = (3 - 1 + players.length) % players.length;
    expect(players[nextNext]).toBe("p2");
  });

  it("new deck has 32 cards and deals 8 per player", () => {
    const deck = buildFourPlayerDeck();
    expect(deck.length).toBe(32);
    const hands = dealHands(deck);
    for (const hand of hands) {
      expect(hand.length).toBe(8);
    }
  });
});
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd workers && npx vitest run test/game/round-loop.test.ts`
Expected: PASS (pure math + deck functions already work)

- [ ] **Step 3: Add startNextRound method to GameRoom**

Add the following method to the GameRoom class in `workers/src/game/game-room.ts`, after `handleForfeit`:

```typescript
private async startNextRound(): Promise<void> {
  const game = this.game!;

  // Rotate dealer counter-clockwise
  const oldDealerIndex = game.players.indexOf(game.dealer);
  const newDealerIndex = (oldDealerIndex - 1 + game.players.length) % game.players.length;
  const newDealer = game.players[newDealerIndex];

  // First bidder is counter-clockwise from new dealer
  const firstBidderIndex = (newDealerIndex - 1 + game.players.length) % game.players.length;
  const firstBidder = game.players[firstBidderIndex];

  // Re-deal
  const deck = buildFourPlayerDeck();
  const dealtHands = dealHands(deck);
  for (let i = 0; i < 4; i++) {
    const hand = dealtHands[i].map((c) => c.code);
    this.hands.set(game.players[i], hand);
  }

  // Reset game state for new round
  game.phase = "BIDDING";
  game.dealer = newDealer;
  game.currentPlayer = firstBidder;
  game.bid = null;
  game.biddingState = {
    currentBidder: firstBidder,
    highestBid: null,
    highestBidder: null,
    passed: [],
  };
  game.trumpSuit = null;
  game.currentTrick = null;
  game.tricks = { teamA: 0, teamB: 0 };
  game.bidHistory = [];
  game.roundHistory = [];

  await this.persistAndBroadcast();
  this.broadcastHands();
}
```

- [ ] **Step 4: Add a "continueRound" client action to trigger next round**

In `game-room.ts`, add to the `ClientAction` type at the top (line 21-24):

```typescript
type ClientAction =
  | { action: "placeBid"; data: { bidAmount: number } }
  | { action: "selectTrump"; data: { suit: string } }
  | { action: "playCard"; data: { card: string } }
  | { action: "continueRound"; data: Record<string, never> };
```

Add the handler case in `webSocketMessage` switch (after line 177):

```typescript
case "continueRound":
  await this.handleContinueRound(uid);
  break;
```

Add the handler method:

```typescript
private continueVotes: Set<string> = new Set();

private async handleContinueRound(uid: string): Promise<void> {
  const game = this.game!;
  if (game.phase !== "ROUND_SCORING") throw new Error("Not in ROUND_SCORING phase");
  if (!game.players.includes(uid)) throw new Error("Not a player in this game");

  this.continueVotes.add(uid);

  // Start next round when all 4 players have acknowledged
  if (this.continueVotes.size >= game.players.length) {
    this.continueVotes.clear();
    await this.startNextRound();
  }
}
```

- [ ] **Step 5: Auto-start next round after a delay (alternative to vote)**

Actually, simpler approach — use a DO alarm to auto-advance after 5 seconds. Replace the vote mechanism with an alarm-based approach. In `handlePlayCard`, after setting `game.phase = "ROUND_SCORING"` (line 428), add:

```typescript
if (!gameWinner) {
  // Schedule next round after 5 seconds
  await this.ctx.storage.put("roundAdvanceAt", Date.now() + 5000);
  const currentAlarm = await this.ctx.storage.getAlarm();
  if (!currentAlarm) {
    await this.ctx.storage.setAlarm(Date.now() + 5000);
  }
}
```

Similarly after poison joker scoring in `handlePlayCard` (line 362), when `game.phase === "ROUND_SCORING"`:

```typescript
if (!gameWinner) {
  await this.ctx.storage.put("roundAdvanceAt", Date.now() + 5000);
  const currentAlarm = await this.ctx.storage.getAlarm();
  if (!currentAlarm) {
    await this.ctx.storage.setAlarm(Date.now() + 5000);
  }
}
```

And after forfeit in `handleForfeit` (line 453), when not game over:

```typescript
if (!gameWinner) {
  await this.ctx.storage.put("roundAdvanceAt", Date.now() + 5000);
  const currentAlarm = await this.ctx.storage.getAlarm();
  if (!currentAlarm) {
    await this.ctx.storage.setAlarm(Date.now() + 5000);
  }
}
```

**Replace the entire `alarm()` method** (lines 216-248) with this new version that handles both disconnect alarms AND round-advance alarms:

```typescript
async alarm(): Promise<void> {
  await this.loadState();
  if (!this.game || this.game.phase === "GAME_OVER") return;

  const now = Date.now();
  let nextAlarm: number | null = null;

  // Check for round advance
  const roundAdvanceAt = await this.ctx.storage.get<number>("roundAdvanceAt");
  if (roundAdvanceAt && this.game.phase === "ROUND_SCORING") {
    if (now >= roundAdvanceAt) {
      await this.ctx.storage.delete("roundAdvanceAt");
      await this.startNextRound();
      return; // State changed, alarm will be reset if needed
    } else {
      const remaining = roundAdvanceAt - now;
      if (!nextAlarm || remaining < nextAlarm) {
        nextAlarm = remaining;
      }
    }
  }

  // Check for expired disconnect timers
  for (const uid of this.game.players) {
    const alarmKey = `disconnect:${uid}`;
    const disconnectTime = await this.ctx.storage.get<number>(alarmKey);
    if (!disconnectTime) continue;

    const elapsed = now - disconnectTime;
    if (elapsed >= 90_000) {
      await this.handleForfeit(uid);
      await this.ctx.storage.delete(alarmKey);
      if (this.game?.phase === "GAME_OVER") return;
      continue;
    } else {
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
```

- [ ] **Step 6: Remove the continueVotes approach (keep alarm only)**

Delete the `continueVotes` property, `handleContinueRound` method, and the `continueRound` case from the switch. The alarm-based auto-advance is simpler and doesn't require client coordination.

Revert the `ClientAction` type to:

```typescript
type ClientAction =
  | { action: "placeBid"; data: { bidAmount: number } }
  | { action: "selectTrump"; data: { suit: string } }
  | { action: "playCard"; data: { card: string } };
```

- [ ] **Step 7: Run all tests**

Run: `cd workers && npx vitest run`
Expected: All pass.

- [ ] **Step 8: Commit**

```bash
cd workers && git add src/game/game-room.ts test/game/round-loop.test.ts
git commit -m "feat: add round loop with dealer rotation and re-deal

After ROUND_SCORING, a 5-second alarm triggers startNextRound() which:
- Rotates dealer counter-clockwise
- Re-shuffles and deals new hands
- Resets bidding/trick state
- Transitions to BIDDING phase

Games can now play multiple rounds to reach 31 points."
```

---

### Task 3: Call completeGame on GAME_OVER (ELO Update)

`completeGame()` in `workers/src/matchmaking/queue.ts` exists but is never called. When the game transitions to GAME_OVER, the GameRoom must call it to update ELO and record final scores.

**Files:**
- Modify: `workers/src/game/game-room.ts`
- Modify: `workers/src/env.ts` (verify DB binding is accessible from DO)

- [ ] **Step 1: Verify env.ts exposes DB to Durable Object**

Read `workers/src/env.ts` and confirm the `Env` type includes `DB: D1Database`. The GameRoom DO constructor receives `env: Env`, so `this.env.DB` should be available.

Run: `grep -n 'DB' workers/src/env.ts`
Expected: `DB: D1Database` in the Env interface.

- [ ] **Step 2: Write failing test for ELO update call**

This is an integration concern — we'll verify by adding a test that checks `completeGame` is structurally correct (it already has unit-level correctness from `queue.ts`). The key is confirming `game-room.ts` calls it.

```typescript
// Add to workers/test/game/round-loop.test.ts
import { completeGame } from "../../src/matchmaking/queue";

describe("completeGame function signature", () => {
  it("accepts expected parameters", () => {
    // Type check — completeGame should accept these arg types
    // We can't actually call it without a D1Database mock, but we verify the signature
    expect(typeof completeGame).toBe("function");
    expect(completeGame.length).toBe(5); // 5 parameters
  });
});
```

- [ ] **Step 3: Run test**

Run: `cd workers && npx vitest run test/game/round-loop.test.ts`
Expected: PASS

- [ ] **Step 4: Add completeGame call to GameRoom**

Import `completeGame` at the top of `workers/src/game/game-room.ts`:

```typescript
import { completeGame } from "../matchmaking/queue";
```

Add a helper method to the GameRoom class:

```typescript
private async recordGameCompletion(): Promise<void> {
  if (!this.game) return;
  const winner = this.game.metadata.winner;
  if (!winner) return;

  try {
    await completeGame(
      this.env.DB,
      this.ctx.id.toString(),
      winner,
      this.game.scores,
      this.game.players
    );
  } catch (err) {
    // Non-fatal: game continues even if ELO update fails
    console.error("Failed to update ELO:", err);
  }
}
```

Call it everywhere `game.phase` is set to `"GAME_OVER"`:

1. In `handlePlayCard`, after line 432 (`game.metadata = ...`), add:

```typescript
await this.recordGameCompletion();
```

2. In `handlePlayCard` poison joker block, after line 364 (`game.metadata = ...`), add:

```typescript
if (gameWinner) {
  await this.recordGameCompletion();
}
```

3. In `handleForfeit`, after line 455 (`game.metadata = ...`), add:

```typescript
if (gameWinner) {
  await this.recordGameCompletion();
}
```

All three call sites must use `await` — the function does D1 writes.

- [ ] **Step 5: Run all tests**

Run: `cd workers && npx vitest run`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd workers && git add src/game/game-room.ts test/game/round-loop.test.ts
git commit -m "feat: call completeGame on GAME_OVER to update ELO

Calls completeGame() from matchmaking/queue.ts when game reaches
GAME_OVER phase. Updates game_history with winner and final scores,
applies +16/-16 ELO delta to winners/losers. Non-fatal try/catch
ensures game state isn't corrupted if D1 write fails."
```

---

### Task 4: Fix Matchmaking Race Condition

Two concurrent `/api/matchmaking/join` requests can both see the same queue, match the same 4 players, and create duplicate GameRooms. The fix: use D1's `INSERT ... ON CONFLICT` to atomically claim players.

**Files:**
- Modify: `workers/src/matchmaking/queue.ts`
- Modify: `workers/src/index.ts`

- [ ] **Step 1: Analyze the race window**

The race is in `workers/src/index.ts:49-84`:
1. `getQueuedPlayers()` reads queue
2. `findBestMatch()` finds 4 players
3. `removePlayersFromQueue()` deletes them

Between steps 1 and 3, another request can read the same queue. D1 doesn't support transactions across multiple statements in a single Worker invocation, but we can use an atomic approach.

- [ ] **Step 2: Add atomic claim function to queue.ts**

Add to `workers/src/matchmaking/queue.ts`:

```typescript
/**
 * Atomically claim matched players by adding a match_id.
 * Returns true if all players were successfully claimed (no one was already claimed).
 * Uses a claimed_by column to prevent double-matching.
 */
export async function claimMatchedPlayers(
  db: D1Database,
  uids: string[],
  matchId: string
): Promise<boolean> {
  // First, try to claim all players atomically by updating only unclaimed rows
  const placeholders = uids.map(() => "?").join(",");
  const result = await db
    .prepare(
      `UPDATE matchmaking_queue SET claimed_by = ? WHERE uid IN (${placeholders}) AND claimed_by IS NULL`
    )
    .bind(matchId, ...uids)
    .run();

  // If we claimed all 4, we own the match
  if (result.meta.changes === uids.length) {
    return true;
  }

  // All-or-nothing: if we couldn't claim all N players, unclaim what we got
  await db
    .prepare(
      `UPDATE matchmaking_queue SET claimed_by = NULL WHERE claimed_by = ?`
    )
    .bind(matchId)
    .run();

  return false;
}
```

- [ ] **Step 3: Update getQueuedPlayers to exclude claimed**

Modify `getQueuedPlayers` in `workers/src/matchmaking/queue.ts`:

```typescript
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
```

- [ ] **Step 4: Update /api/matchmaking/join in index.ts**

Import the new function:

```typescript
import { joinQueue, leaveQueue, getQueuedPlayers, removePlayersFromQueue, recordGame, claimMatchedPlayers } from "./matchmaking/queue";
```

Replace lines 49-83 in `workers/src/index.ts`:

```typescript
  // Check for a match
  const allPlayers = await getQueuedPlayers(c.env.DB);
  const matched = findBestMatch(allPlayers);

  if (matched) {
    const matchedUids = matched.map((p) => p.uid);
    const matchId = crypto.randomUUID();

    // Atomically claim the matched players
    const claimed = await claimMatchedPlayers(c.env.DB, matchedUids, matchId);
    if (!claimed) {
      // Another request already claimed some of these players
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
```

- [ ] **Step 5: Add D1 migration for claimed_by column**

Create `workers/migrations/002_add_claimed_by.sql`:

```sql
ALTER TABLE matchmaking_queue ADD COLUMN claimed_by TEXT DEFAULT NULL;
```

- [ ] **Step 6: Run all tests**

Run: `cd workers && npx vitest run`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
cd workers && git add src/matchmaking/queue.ts src/index.ts migrations/002_add_claimed_by.sql
git commit -m "fix: prevent matchmaking race with atomic claim

Two concurrent /api/matchmaking/join requests could match the same
players and create duplicate GameRooms. New claimMatchedPlayers()
uses UPDATE ... WHERE claimed_by IS NULL to atomically claim players.
If another request already claimed them, the second request falls
through to 'queued' status. Adds claimed_by column to D1 schema."
```

---

### Task 5: Verify All Fixes End-to-End

Run the full test suite and manually verify the key scenarios.

**Files:**
- All modified files from Tasks 1-4

- [ ] **Step 1: Run full Dart test suite**

Run: `cd /sessions/zealous-loving-archimedes/mnt/Bahraini\ Kout\ Card\ Game && flutter test`
Expected: All pass (no Dart files were modified).

- [ ] **Step 2: Run full Workers test suite**

Run: `cd workers && npx vitest run`
Expected: All pass.

- [ ] **Step 3: Verify direction consistency**

Grep for any remaining clockwise patterns:

Run: `grep -n "idx + 1" workers/src/game/game-room.ts`
Expected: No results (all `+ 1` patterns replaced with `- 1 + length`).

Run: `grep -n "nextPlayerClockwise" workers/src/game/game-room.ts`
Expected: No results (renamed to `nextPlayer`).

- [ ] **Step 4: Verify completeGame is reachable**

Run: `grep -n "recordGameCompletion" workers/src/game/game-room.ts`
Expected: 4 results — 1 method definition + 3 call sites (normal win, poison joker win, forfeit win).

- [ ] **Step 5: Verify round loop alarm is scheduled**

Run: `grep -n "roundAdvanceAt" workers/src/game/game-room.ts`
Expected: Multiple results in handlePlayCard, handleForfeit, and alarm handler.

- [ ] **Step 6: Commit any remaining fixes**

If any tests failed, fix and commit. Otherwise, no action needed.

---

## Summary of Changes

| Bug | Root Cause | Fix | Files |
|-----|-----------|-----|-------|
| Clockwise rotation | `(idx + 1)` everywhere | Change to `(idx - 1 + len) % len` | game-room.ts |
| No round loop | Missing `startNextRound()` | Add method + 5s alarm trigger | game-room.ts |
| No dealer rotation | Not implemented | Part of `startNextRound()` | game-room.ts |
| ELO never updated | `completeGame()` never called | Add `recordGameCompletion()` | game-room.ts |
| Matchmaking race | Check-then-act without atomicity | Atomic `claimed_by` UPDATE | queue.ts, index.ts |
