# CLAUDE.md — Workers Backend

Backend for **koutbh** (Bahraini trick-taking card game). Cloudflare Workers + Hono + Durable Objects + D1.

## Quick Reference

```bash
npm run dev          # local dev server :8787
npx vitest           # run all tests (watch mode)
npx vitest run       # run tests once
npx wrangler deploy  # deploy to prod
```

## Architecture

```
src/
├── index.ts              ← Hono app: REST routes + WS upgrade endpoints
├── env.ts                ← Env type (GAME_ROOM DO, MATCHMAKING_LOBBY DO, DB, JWT_SECRET)
├── auth/jwt.ts           ← signToken / verifyToken (jose, HS256)
├── game/
│   ├── game-room.ts      ← GameRoom Durable Object (~1100 lines) — THE core file
│   ├── types.ts           ← GameDocument, GamePhase, BotContext types, constants
│   ├── card.ts            ← encode/decode cards, makeCard, makeJoker, beatsCard
│   ├── bid-validator.ts   ← validateBid, validatePass, isLastBidder, checkBiddingComplete
│   ├── play-validator.ts  ← validatePlay, detectPoisonJoker
│   ├── trick-resolver.ts  ← resolveTrick (Joker > trump > led suit)
│   ├── scorer.ts          ← calculateRoundResult, applyScore, applyKout, applyPoisonJoker, isRoundDecided
│   └── bot/
│       ├── index.ts       ← BotEngine facade, buildBotContext, buildTrackerFromRaw
│       ├── types.ts       ← BotContext interface, teamForSeat
│       ├── hand-evaluator.ts  ← evaluateHand → HandStrength, effectiveTricks
│       ├── bid-strategy.ts    ← decideBid (thresholds, shape floor, seven/kout gates)
│       ├── trump-strategy.ts  ← decideTrump (weighted scoring, honor tiebreak)
│       ├── play-strategy.ts   ← decidePlay (lead/follow logic, strategic dump)
│       └── card-tracker.ts    ← CardTracker (played cards, void inference, remaining)
├── matchmaking/
│   ├── lobby.ts           ← MatchmakingLobby DO (WS notifications)
│   ├── matcher.ts         ← findBestMatch, calculateBracket, assignSeats
│   └── queue.ts           ← D1 queue ops (joinQueue, leaveQueue, etc.)
└── presence/              ← (empty — future)
```

## Game Domain Rules

These rules are **not derivable from code reading** — they're the spec the code must implement.

### Deck
32 cards. S/H/C have 8 each (A,K,Q,J,10,9,8,7). Diamonds has 7 (no 7♦). Plus 1 Joker. 8 cards per player.

### Teams & Seating
Seats 0,2 = teamA. Seats 1,3 = teamB. Counter-clockwise: `nextSeat(i) = (i - 1 + 4) % 4` → 0→3→2→1.

### Bidding
- Bids: 5 (Bab), 6, 7, 8 (Kout). Must exceed current highest.
- Single CCW orbit from seat after dealer. Each player bids or passes once.
- Pass = permanently out. Kout = bidding ends immediately.
- **Forced bid**: if 3 pass with no bid, 4th MUST bid Bab. If someone already bid, 4th CAN pass.

### Trump & Trick Play
- Winning bidder picks trump suit.
- Seat after bidder leads first trick. Must follow led suit if able. Joker exempt.
- Winner: Joker > highest trump > highest of led suit.
- Kout first trick: leader must play trump if they have it.

### Joker Rules
- Leading the Joker = instant game loss (opponent score set to 31, uses `applyPoisonJoker`).
- Poison Joker: if player's last card is Joker, team auto-loses (opponent score set to 31).
- Both use same scoring path → `applyPoisonJoker` → `applyKout(opponent)`.

### Scoring (Tug-of-War to 31)
Single shared score starting at 0. Points deduct from opponent first, remainder goes to winner. Only one team ever has non-zero score.

| Bid | Win | Lose |
|-----|-----|------|
| 5   | +5  | +10  |
| 6   | +6  | +12  |
| 7   | +7  | +14  |
| 8   | score=31 | +16  |

Bidding team wins round if tricks >= bid value.

### Dealer Rotation
Losing team deals. Dealer stays if already on losing team, else rotates one CCW. Tied = dealer stays.

## Card Encoding

`SA` = Ace of Spades, `HK` = King of Hearts, `D10` = 10 of Diamonds, `JO` = Joker. Functions: `encodeCard`, `decodeCard`, `makeCard`, `makeJoker` in `card.ts`.

## GameRoom Durable Object — Key Flow

```
initGame(players)       → deal 8 cards, set phase BIDDING, schedule bot turn
  ↓
handleBid / handlePass  → validate via bid-validator, advance bidder CCW
  ↓                       forced bid if 3 pass + no bid
checkBiddingComplete    → winner picks trump
  ↓
handleSelectTrump       → set trumpSuit, phase BID_ANNOUNCEMENT, 2.5s alarm
  ↓
alarm (bid_announcement) → phase PLAYING, schedule first player
  ↓
handlePlayCard          → validate via play-validator
  ↓                       check poison joker (isLeadPlay && detectPoisonJoker)
resolveTrick            → trick-resolver, update tricks count
  ↓                       check isRoundDecided (early exit)
  ↓                       after 8 tricks → finalizeRound
finalizeRound           → scorer.calculateRoundResult + applyScore/applyKout
  ↓                       checkGameOver → GAME_OVER or startNextRound
startNextRound          → dealer rotation, re-deal, roundIndex++
```

### Alarm-Based Event System
GameRoom uses `PendingEvent` queue stored in DO state. Types: `bot_turn`, `disconnect_timeout`, `lobby_expiry`, `round_delay`, `bid_announcement`, `human_timeout`.

### Online-Only Features
- WebSocket management (connect/disconnect/reconnect)
- 90s disconnect timeout → forfeit
- 15s human turn timeout → auto-pass or random legal card
- Bot turn delays: 800-2000ms random
- Room/Lobby mode: host creates, friend joins seat 2, bots at 1+3
- D1 game completion recording via `completeGame`

## Bot Strategy Pipeline

```
evaluateHand(hand) → HandStrength { personalTricks, strongestSuit }
  ↓
effectiveTricks(strength, partnerAction) → ET (clamped 0-8)
  ↓
decideBid(ctx) → bid amount or pass
  - Thresholds: ET >= 5/6/7/8
  - Shape floor from suit lengths
  - Seven gate (6+ suit, Joker+5+AK, 3A+Joker)
  - Kout gate (7+ suit, Joker+6+AKQ, Joker+5+3A, ET>=7.6)
  - Partner rule: never outbid partner unless Kout
  - Desperation: +1.0 when opp >= 21
  ↓
decideTrump(ctx) → SuitName
  - Weighted: length*2.5 + strength*0.45 (Kout: 1.5/2.0)
  - Honor tiebreak within epsilon=0.5
  ↓
decidePlay(ctx, tracker) → card code
  - Lead: masters → aces (A-K combo) → trump strip (bidding, 3+) → partner void → short suit
  - Follow: position-aware (2nd/3rd=highest winner, 4th=lowest winner)
  - Void: winning trumps → lowest trump → Joker → strategic dump
  - Joker countdown: <=2 tricks + urgency > 0.7
  - Poison prevention: hand.length <= 2 + has Joker → play Joker
```

### BotContext Signals (computed in buildBotContext)
- `roundControlUrgency` — need/remaining ratio for bidding team
- `partnerLikelyWinningTrick` — partner currently winning current trick
- `partnerNeedsProtection` — partner winning but trump could override
- `opponentLikelyVoidInLedSuit` / `partnerLikelyVoidInLedSuit` — from CardTracker voids

### CardTracker
Rebuilt each turn from `roundHistory` via `buildTrackerFromRaw`. Tracks: `playedCards`, `knownVoids` (inferred when player doesn't follow suit), `isHighestRemaining`, `trumpsRemaining`, `remainingCards`, `isSuitExhausted`.

## Dual Implementation Sync

Game logic exists in both **Dart** (`lib/shared/logic/`, `lib/offline/bot/`) and **TypeScript** (this codebase). They MUST stay in sync. Reference doc: `OFFLINE_VS_ONLINE_GAPS.md` in project root.

When modifying any game logic or bot strategy:
1. Make the change in TypeScript
2. Document what changed so the Dart side can be updated
3. Run `npx vitest run` to verify

Key parity files:
| TypeScript | Dart |
|-----------|------|
| `bid-validator.ts` | `lib/shared/logic/bid_validator.dart` |
| `play-validator.ts` | `lib/shared/logic/play_validator.dart` |
| `trick-resolver.ts` | `lib/shared/logic/trick_resolver.dart` |
| `scorer.ts` | `lib/shared/logic/scorer.dart` |
| `bot/hand-evaluator.ts` | `lib/offline/bot/hand_evaluator.dart` |
| `bot/bid-strategy.ts` | `lib/offline/bot/bid_strategy.dart` |
| `bot/trump-strategy.ts` | `lib/offline/bot/trump_strategy.dart` |
| `bot/play-strategy.ts` | `lib/offline/bot/play_strategy.dart` |

## Testing

```bash
npx vitest run                    # all tests
npx vitest run test/game/         # game logic only
npx vitest run test/game/bot/     # bot strategy only
```

Config: `vitest.config.ts` — standard Vitest, no Cloudflare pool (yet). Tests import source directly.

### Test File Map
| File | Covers |
|------|--------|
| `test/game/card.test.ts` | encode/decode round-trip |
| `test/game/bid-validator.test.ts` | bid validation, pass rules, forced bid |
| `test/game/trick-resolver.test.ts` | Joker wins, trump wins, led suit wins |
| `test/game/scorer.test.ts` | round result, tug-of-war, kout, poison joker, isRoundDecided |
| `test/game/direction.test.ts` | CCW rotation, bidding order, trick lead order |
| `test/game/bot/hand-evaluator.test.ts` | probability scoring, texture bonus, strongest suit |
| `test/game/bot/bid-strategy.test.ts` | strong/weak hand, forced bid, bid ceiling |
| `test/game/bot/trump-strategy (via play-strategy)` | trump selection via BotEngine.trump |
| `test/game/bot/play-strategy.test.ts` | card selection, suit following, Joker avoidance |
| `test/game/bot/card-tracker.test.ts` | remaining cards, highest detection, void inference |
| `test/game/bot/bot-engine.test.ts` | buildBotContext from GameDocument |
| `test/auth/jwt.test.ts` | sign/verify, tamper rejection |
| `test/matchmaking/matcher.test.ts` | ELO bracket, match finding, seat assignment |
| `test/game/game-room.test.ts` | **PLACEHOLDER** — all `it.todo()` |

### Testing Conventions
- Helper: `makePlayCtx(overrides)` / `makeCtx(overrides)` to build BotContext with defaults
- Use `toContain`, `toMatch(/^H/)` for card assertions
- Test edge cases: forced bid, single legal card, Joker-only hand, kout scenarios

## Infrastructure

- **Wrangler**: `wrangler.toml` — worker name `bahraini-kout`, DOs: GameRoom + MatchmakingLobby (SQLite-backed), D1 binding `DB` (kout-db)
- **D1 tables**: `users`, `games`, `matchmaking_queue`, `room_codes`
- **Secrets**: `JWT_SECRET` (set via `wrangler secret put`)
- **Compatibility**: `nodejs_compat` flag enabled

## Known Issues

1. **GameRoom E2E tests stubbed** — `test/game/game-room.test.ts` has all `it.todo()`. Individual validators/scorer/bot tested, but the DO orchestration is not.
2. **No cross-language parity tests** — Dart/TS logic sync is manual-only (`OFFLINE_VS_ONLINE_GAPS.md`). No shared test vectors.

## API Routes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/anonymous` | No | Create anonymous user, get JWT |
| POST | `/api/matchmaking/join` | JWT | Join matchmaking queue |
| POST | `/api/matchmaking/leave` | JWT | Leave queue |
| POST | `/api/rooms/create` | JWT | Create private room (6-char code) |
| POST | `/api/rooms/join` | JWT | Join room by code |
| POST | `/api/rooms/start` | JWT | Host starts room game |
| GET | `/api/rooms/:code/status` | JWT | Room status + seats |
| GET | `/ws/game/:gameId?token=` | JWT (query) | WebSocket upgrade to GameRoom DO |
| GET | `/ws/matchmaking?token=` | JWT (query) | WebSocket upgrade to MatchmakingLobby |
| GET | `/health` | No | Health check |

## WebSocket Messages (GameRoom)

### Client → Server
```json
{"action": "placeBid", "data": {"bidAmount": 6}}
{"action": "placeBid", "data": {"bidAmount": 0}}
{"action": "selectTrump", "data": {"suit": "hearts"}}
{"action": "playCard", "data": {"card": "SA"}}
```

### Server → Client
```json
{"event": "gameState", "data": {phase, players, scores, tricks, bid, ...}}
{"event": "hand", "data": {"hand": ["SA", "HK", ...]}}
{"event": "error", "data": {"code": "...", "message": "..."}}
{"event": "reconnected", "data": {"gracePeriodRemaining": 90}}
{"event": "lobby_state", "data": {seats, roomCode, isHost}}
```
