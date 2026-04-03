# Room-Based Multiplayer: 2 Humans + 2 Server-Side Bots

**Date:** 2026-04-03
**Status:** Approved
**Author:** Ali + Claude

## Summary

Add room-based multiplayer to koutbh. A host creates a room (gets a 6-char code), shares it with a friend, friend joins, host starts the game. Two human players (Team A, seats 0 and 2) play against two server-side bots (Team B, seats 1 and 3). The existing GameRoom Durable Object is extended with a LOBBY phase; no new DO classes are introduced. Bot logic runs inside the DO using storage alarms for turn delays.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Player discovery | Room codes (6-char alphanumeric) | Works with anonymous auth, no friend list needed |
| Bot execution | Server-side (DO-internal) | No host dependency, bots play even during disconnect |
| Room state | Unified GameRoom DO (LOBBY phase) | Reuses existing DO, single WS endpoint, no cross-DO coordination |
| Team assignment | Humans always Team A (seats 0,2) | No gameplay difference between teams, eliminates a settings step |
| Lobby disconnect | Room stays open, rejoin with same code | Standard pattern, 10min idle expiry |
| In-game disconnect | Reuse existing 90s alarm + forfeit | Already implemented, works for room games identically |
| Lobby updates | WebSocket (connect on room enter) | Real-time, reuses existing /ws/game/:gameId endpoint |

## Architecture

### GameRoom DO State Machine

```
POST /api/rooms/create
       │
       ▼
┌─────────────┐
│   LOBBY     │◄── friend disconnects pre-game (room stays open)
│             │
│ host: s0    │── friend joins via room code
│ friend: s2  │
│ bots: s1,s3 │
└──────┬──────┘
       │ POST /api/rooms/start (host only, requires friend in seat 2)
       ▼
┌─────────────┐
│  DEALING    │◄── startNextRound() loops back here
└──────┬──────┘
       ▼
┌─────────────┐
│  BIDDING    │  Bot turn → alarm(0.8-2.0s) → botBid()
└──────┬──────┘
       ▼
┌──────────────────┐
│ TRUMP_SELECTION  │  Bot won bid → alarm → botTrump()
└──────┬───────────┘
       ▼
┌──────────────────┐
│ BID_ANNOUNCEMENT │  2s display pause
└──────┬───────────┘
       ▼
┌─────────────┐
│  PLAYING    │  Bot turn → alarm(0.8-2.0s) → botPlay()
│  8 tricks   │
└──────┬──────┘
       ▼
┌───────────────┐
│ ROUND_SCORING │
└──────┬────────┘
       │
  score >= 31? ──Yes──► GAME_OVER (update ELO, release code)
       │
      No ──► rotate dealer, loop to DEALING
```

### Bot Turn Flow

When any action resolves (human or bot), the DO checks if the next seat is a bot:

1. If human → broadcast state, wait for WebSocket message.
2. If bot → call `storage.setAlarm(Date.now() + delay)` where delay = 800 + random(0, 1200) ms.
3. Alarm fires → read game state from DO storage → run strategy function (`botBid`, `botTrump`, or `botPlay`) → apply action through the same code path as a human action → broadcast updated state → check if next seat is also a bot (schedule next alarm).

**Alarm chaining is strictly sequential.** Only one alarm is active at a time. The DO is single-threaded, so each alarm handler runs to completion, applies the bot's action, persists state, then schedules the next alarm if the next seat is also a bot. No concurrent alarms. This matches the existing alarm pattern in game-room.ts.

Bot-to-bot chaining example (seats 1 and 3 are both bots, playing in a trick):

```
Human seat 0 plays card
→ seat 1 is bot → schedule alarm(~1.2s) → alarm fires → seat 1 plays → persist state
→ seat 2 is human → broadcast state, wait for WS
→ human seat 2 plays
→ seat 3 is bot → schedule alarm(~1.0s) → alarm fires → seat 3 plays → persist state
→ trick complete → resolve winner
```

### Room Code Lifecycle

D1 migration (`002_rooms.sql`):

```sql
CREATE TABLE room_codes (
  code       TEXT PRIMARY KEY,
  do_id      TEXT NOT NULL,
  host_uid   TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status     TEXT DEFAULT 'open'  -- 'open' | 'playing' | 'closed'
);
```

Lifecycle:

1. **Create**: Generate 6-char alphanumeric (charset: `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, no ambiguous 0OIl1). INSERT into D1. Retry on collision (max 3). Create DO, call `/init` with host UID.
2. **Join**: SELECT do_id WHERE code = ? AND status = 'open'. Forward to DO `/join`.
3. **Start**: Forward to DO `/start`. DO validates friend is seated. UPDATE status = 'playing'. Deal cards.
4. **Close**: On GAME_OVER or 10min idle expiry → UPDATE status = 'closed'.

## API Surface

### New Endpoints

**POST /api/rooms/create**
- Auth: JWT required
- Body: (none)
- Response: `{ roomCode: "KOUT7X", gameId: "abc123..." }`
- Errors: 500 on code generation failure

**POST /api/rooms/join**
- Auth: JWT required
- Body: `{ code: "KOUT7X" }`
- Response: `{ gameId: "abc123..." }`
- Errors: 404 room not found, 409 room full, 410 game already started

**POST /api/rooms/start**
- Auth: JWT required
- Body: `{ gameId: "abc123..." }`
- Response: `{ ok: true }`
- Errors: 403 not host, 400 friend not joined

**GET /api/rooms/:code/status**
- Auth: JWT required
- Response: `{ status: "open"|"playing"|"closed", seats: [...] }`

### Existing Endpoints (unchanged)

All matchmaking, auth, and WebSocket endpoints remain untouched. The existing `/ws/game/:gameId` is reused for room games — humans connect here during both LOBBY and game phases.

## WebSocket Protocol

### Lobby Phase Messages

Humans connect to `/ws/game/:gameId` as soon as they enter the room.

Server → Client (on connect, during LOBBY):

```json
{
  "type": "lobby_state",
  "seats": [
    { "seat": 0, "uid": "abc", "isBot": false, "connected": true },
    { "seat": 1, "uid": null, "isBot": true },
    { "seat": 2, "uid": null, "isBot": false, "connected": false },
    { "seat": 3, "uid": null, "isBot": true }
  ],
  "roomCode": "KOUT7X",
  "isHost": true
}
```

Server → All (friend joins): Updated `lobby_state` with seat 2 filled and `connected: true`.

Server → All (friend disconnects during lobby): Updated `lobby_state` with seat 2 cleared (`uid: null`, `connected: false`). Client uses the `connected` field on human seats to determine UI state: `uid != null && connected == false` → "Player disconnected", `uid == null` → "Waiting for player...".

Server → All (host disconnects during lobby): Updated `lobby_state` with seat 0 `connected: false`. Friend sees "Host disconnected, waiting..." Room stays open per idle expiry timer.

Server → All (game starts): `{ "type": "game_state", "phase": "DEALING", ... }` followed by individual `hand` messages.

**Reconnection during lobby:** Same as in-game — client auto-reconnects to `/ws/game/:gameId` using existing `GameService` reconnection logic (5 retries, exponential backoff). On reconnect, DO sends current `lobby_state`. No special rejoin endpoint needed.

### Game Phase Messages

Identical to existing protocol. Bot turns are invisible — clients just see `game_state` updates arriving as if another human played.

## Server-Side Bot Engine

### Module: `workers/src/game/bot-engine.ts`

```typescript
interface BotContext {
  hand: Card[];
  scores: { teamA: number; teamB: number };
  myTeam: 'A' | 'B';
  mySeat: number;
  bidHistory: Array<{ seat: number; action: 'bid' | 'pass'; amount?: number }>;
  trickHistory: Array<{ winner: number; plays: TrickPlay[] }>;
  trumpSuit?: Suit;
  currentBid?: number;
  currentTrick: TrickPlay[];
  isLead: boolean;
  isForced: boolean;  // forced bid (last player, no bids yet)
}

interface BotEngine {
  decideBid(ctx: BotContext): BidAction | PassAction;
  decideTrump(ctx: BotContext): Suit;
  decidePlay(ctx: BotContext): Card;
}
```

Ported from Dart bot strategies (`lib/offline/bot/`). The `BotContext` carries the same information that the Dart `BidStrategy`, `TrumpStrategy`, and `PlayStrategy` classes receive (hand, scores, team, seat, bid history, trick history). Same strategic logic, TypeScript syntax:

- **Bidding**: Hand evaluation based on high cards, trump-length potential, joker presence. Score-aware (more aggressive when behind). Forced bid logic.
- **Trump selection**: Longest suit with most honors (A, K, Q, J).
- **Play**: Lead strongest suit, follow high when winning / low when losing, trump when void in led suit, protect joker from becoming poison. Tracks voids from trick history.

Difficulty: "balanced" (hardcoded for v1). Reuses existing `bid-validator.ts`, `play-validator.ts`, and `trick-resolver.ts` for validation.

## GameRoom DO Changes

### Dual-Mode `/init`

The existing `/init` endpoint currently accepts `{ players: string[] }` (4 human UIDs from matchmaking). It is extended to support both modes:

```typescript
// Mode 1: Matchmaking (existing, unchanged)
POST /init { mode: "matchmaking", players: ["uid1", "uid2", "uid3", "uid4"] }
// → All 4 seats are human, deal immediately, phase = DEALING

// Mode 2: Room (new)
POST /init { mode: "room", hostUid: "abc123" }
// → Seat 0 = host (human), seats 1,3 = bots, seat 2 = empty (awaiting friend)
// → Phase = LOBBY, cards NOT dealt
```

**Bot seat representation in DO storage:**

```typescript
interface SeatState {
  uid: string | null;    // null = empty seat awaiting player
  isBot: boolean;        // true for seats 1, 3 in room mode
  connected: boolean;    // WS connection status (always true for bots)
}

// Room mode initial state:
seats: [
  { uid: "host_uid", isBot: false, connected: false },  // connected becomes true on WS connect
  { uid: "bot_1",    isBot: true,  connected: true },    // synthetic UID, never has WS
  { uid: null,       isBot: false, connected: false },   // seat 2, awaiting friend
  { uid: "bot_3",    isBot: true,  connected: true },    // synthetic UID, never has WS
]
```

Bot UIDs are synthetic strings like `"bot_1"`, `"bot_3"` — they exist so the game state arrays (hands, tricks, etc.) can reference them consistently. They never have WebSocket connections. The `isBotSeat(seat)` helper checks `seats[seat].isBot`.

### New Internal Endpoints

- **`/join` (new)**: Accepts `{ playerUid }`. Validates phase is LOBBY and seat 2 is empty. Assigns player to seat 2. Broadcasts updated `lobby_state`.
- **`/start` (new)**: Validates caller UID matches host UID (from JWT, checked against `seats[0].uid`). Validates seat 2 is filled. Deals cards, sets phase to DEALING, begins game loop. If first bidder is a bot, schedules bot alarm. Returns 403 if not host, 400 if friend not joined.
- **`/status` (new)**: Returns current seat assignments and phase.

### Modified Game Loop

The `advanceToNextPlayer()` function gains a bot check:

```
function advanceToNextPlayer(state) {
  const nextSeat = getNextSeat(state);
  if (isBotSeat(nextSeat)) {
    scheduleBotAlarm(state);  // 0.8-2.0s delay
  } else {
    broadcastState();         // wait for human WS message
  }
}
```

The `alarm()` handler gains a bot action branch:

```
async alarm() {
  const state = await this.loadState();

  if (state.pendingBotAction) {
    const action = runBotStrategy(state);
    applyAction(state, action);  // same path as human actions
    broadcastState();
    advanceToNextPlayer(state);  // may chain another bot alarm
    return;
  }

  // existing alarm logic (disconnect timeout, round delay, etc.)
}
```

### Room Expiry

A 10-minute idle alarm is set when the room enters LOBBY. Reset on any activity (join, WS message). If it fires, the DO closes all WebSockets, updates D1 status to 'closed'.

## Flutter Client Changes

### New: `lib/app/services/room_service.dart`

```dart
class RoomService {
  final AppConfig config;
  final AuthService auth;

  Future<({String roomCode, String gameId})> createRoom();
  Future<String> joinRoom(String code);
  Future<void> startGame(String gameId);
  Future<RoomStatus> getRoomStatus(String code);
}
```

### Modified: `lib/app/models/game_mode.dart`

```dart
sealed class GameMode {}

class OnlineGameMode extends GameMode {
  final String gameId, myUid, token;
}

class OfflineGameMode extends GameMode {
  final List<SeatConfig> seats;
}

class RoomGameMode extends GameMode {
  final String gameId, myUid, token, roomCode;
  final bool isHost;
}
```

### New: `lib/app/screens/room_lobby_screen.dart`

Two display modes:

- **Host**: Shows room code (large, tap-to-copy), 4 seat cards (you, bot, waiting..., bot), "Share Code" button (platform share sheet), "Start Game" button (enabled when friend joins).
- **Guest**: Shows seat assignments, "Waiting for host to start...", "Leave Room" button.

Both connect to `/ws/game/:gameId` on enter and listen for `lobby_state` updates. On `game_state` with phase DEALING → navigate to GameScreen with RoomGameMode.

### Modified: `lib/app/screens/home_screen.dart`

Add "Play with Friend" button between existing "Play Offline" and "Play Online". Navigates to a choice: Create Room / Join Room.

### Modified: `lib/app/screens/game_screen.dart`

Add `RoomGameMode` handling — functionally identical to `OnlineGameMode` (creates GameService, connects WS). The only difference is metadata (roomCode, isHost) for potential UI display.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Invalid room code | 404 → "Room not found" dialog |
| Room full | 409 → "Room is full" dialog |
| Game already started | 410 → "Game in progress" dialog |
| Host disconnects (lobby) | Room stays open 10min. Host can reconnect. |
| Friend disconnects (lobby) | Seat 2 cleared, lobby_state broadcast. Friend can rejoin. Host's Start button disabled. |
| Either human disconnects (in-game) | Existing 90s alarm. Bots keep playing their turns. Game pauses only when disconnected human's turn arrives. Forfeit after 90s. |
| Room idle expiry | 10min alarm in LOBBY → close room, close WebSockets, update D1. |
| Room code collision | Retry code generation up to 3 times. |
| Bot turn during disconnect grace | Bot still plays. No pause for bot turns. |

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `workers/src/game/bot-engine.ts` | Server-side bot decision logic (TS port of Dart strategies) |
| `workers/src/migrations/002_rooms.sql` | D1 migration: room_codes table |
| `lib/app/services/room_service.dart` | Room create/join/start API client |
| `lib/app/screens/room_lobby_screen.dart` | Host and guest lobby UI |

### Modified Files

| File | Changes |
|------|---------|
| `workers/src/index.ts` | Add room API routes (create, join, start, status) |
| `workers/src/game/game-room.ts` | Add LOBBY phase, bot turn handling via alarms, /join /start /status endpoints, room expiry alarm |
| `lib/app/models/game_mode.dart` | Add RoomGameMode sealed class variant |
| `lib/app/models/client_game_state.dart` | Parse lobby_state messages |
| `lib/app/screens/home_screen.dart` | Add "Play with Friend" button |
| `lib/app/screens/game_screen.dart` | Handle RoomGameMode (same as OnlineGameMode with metadata) |
| `workers/wrangler.jsonc` | Add D1 binding if missing |

### Untouched

- `lib/shared/` — Pure game logic, no changes.
- `lib/offline/` — Offline mode, no changes.
- `lib/game/` — Flame engine, no changes.
- `workers/src/matchmaking/` — Queue matchmaking, no changes.
- `lib/app/services/auth_service.dart` — Reused as-is.
- `lib/app/services/game_service.dart` — Reused as-is for room games.
- `lib/app/services/matchmaking_service.dart` — Untouched.

## Testing Strategy

### Worker Tests (Vitest)

- **bot-engine.test.ts**: Unit test each strategy function. Verify bid validation, trump selection logic, play legality.
- **game-room.test.ts**: Integration tests for room lifecycle: create → join → start → full game with bots. Test bot chaining, disconnect during bot turn, room expiry.
- **room-api.test.ts**: HTTP endpoint tests: create room, join with valid/invalid codes, start without friend, double join.

### Flutter Tests

- **room_service_test.dart**: Mock HTTP, test create/join/start/status calls.
- **room_lobby_screen_test.dart**: Widget test host and guest modes, seat updates, button states.
- **game_mode_test.dart**: Verify RoomGameMode serialization and routing.

### Manual E2E

- Two browser tabs (or devices) → create room → share code → join → start → play full game against bots.
- Test disconnect/reconnect in lobby and mid-game.
- Test room expiry by creating and abandoning a room.
