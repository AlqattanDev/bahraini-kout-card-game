# CLAUDE.md — koutbh

Bahraini trick-taking card game. Flutter/Flame client + Cloudflare Workers backend (Hono, Durable Objects, D1).

Package name: `koutbh`. Last updated: 2026-04-01.

## Game Rules

These are non-obvious domain rules that can't be derived from reading code alone.

**Deck (4-player):** 32 cards. S/H/C have 8 each (A,K,Q,J,10,9,8,7). Diamonds has 7 (no 7-of-diamonds). Plus 1 Joker (Khallou). 8 cards per player. 6-player mode not yet implemented.

**Teams:** Seats 0,2 = Team A. Seats 1,3 = Team B. Counter-clockwise seating: `nextSeat(i) = (i - 1 + 4) % 4` → 0→3→2→1.

**Dealer rotation:** Random at start. After each round, losing team deals. Dealer stays if already on losing team, otherwise rotates one step CCW to land on losing team. Tied = dealer stays.

**Bidding:** Bids 5 (Bab), 6, 7, 8 (Kout). Must exceed current highest. **Single CCW orbit:** each player bids or passes once (no second lap). Starts with seat after dealer, goes CCW. Pass = permanently out. Kout ends bidding immediately. **Forced bid:** if 3 pass with no bid, last player MUST bid Bab. If someone already bid, last player CAN pass. No malzoom/reshuffle.

**Trump:** Winning bidder picks trump suit.

**Trick play:** Seat after bidder leads first trick. Must follow led suit if able. Joker exempt (playable anytime). Winner: Joker > highest trump > highest of led suit.

**Joker rules:** Leading the Joker = instant round loss (+10 penalty to opponent). Poison Joker: if player's last card is Joker, team auto-loses (+10 penalty). Both use same scoring path.

**Scoring (tug-of-war to 31):** Single shared score at 0. Points first deduct from opponent, remainder goes to winner. Only one team ever has non-zero score. Bid 5: win +5, lose +10. Bid 6: win +6, lose +12. Bid 7: win +7, lose +14. Bid 8 (Kout): win = score set to 31 (instant win), lose = opponent set to 31. Bidding team wins round if tricks taken >= bid value.

## Architecture

```
Flutter UI (lib/app/)          ← screens, services, models
  ↓
Flame Engine (lib/game/)       ← components, managers, overlays, theme
  ↓
Game Logic (lib/shared/)       ← models, logic (pure Dart, no Flame imports)
  ↓
Offline Engine (lib/offline/)  ← LocalGameController, bot strategies, HumanPlayerController
Online Services (lib/app/services/) ← GameService (WS), AuthService (JWT), Matchmaking
  ↓ WebSocket
Cloudflare Workers (workers/src/) ← Hono, GameRoom DO, matchmaking, D1
```

**File map:**
- `lib/shared/models/` — Card, Deck, Bid, Trick, GameState, enums
- `lib/shared/logic/` — BidValidator, PlayValidator, TrickResolver, Scorer
- `lib/shared/constants.dart` + `constants/timing.dart` — game timing, card ranks
- `lib/offline/` — LocalGameController, HumanPlayerController, BotPlayerController
- `lib/offline/bot/` — HandEvaluator, BidStrategy, TrumpStrategy, PlayStrategy
- `lib/game/components/` — CardComponent, HandComponent, OpponentHandFan, PlayerSeat, TrickArea, ScoreDisplay
- `lib/game/managers/` — LayoutManager, AnimationManager, SoundManager
- `lib/game/overlays/` — BidOverlay, TrumpSelector, RoundResultOverlay, GameOverOverlay
- `lib/game/theme/` — KoutTheme, CardPainter, GeometricPatterns, Textures
- `lib/app/screens/` — HomeScreen, OfflineLobbyScreen, MatchmakingScreen, GameScreen
- `lib/app/services/` — AuthService, GameService, MatchmakingService, PresenceService
- `workers/src/game/` — game-room.ts, bid-validator.ts, play-validator.ts, trick-resolver.ts, scorer.ts
- `workers/src/matchmaking/` — lobby.ts, matcher.ts, queue.ts, elo.ts

## Key Abstractions

- **`GameInputSink`** — interface for both `HumanPlayerController` (offline, Completer-based) and `GameService` (online, WebSocket). Flame engine is agnostic to online/offline.
- **`ClientGameState`** — single stream interface for both `LocalGameController` (offline) and `GameService` (online).
- **Sealed classes:** `GameAction` = BidAction|PassAction|TrumpAction|PlayCardAction. `ActionContext` = BidContext|TrumpContext|PlayContext.
- **Dual implementation:** Game logic in both Dart (`shared/logic/`) and TypeScript (`workers/src/game/`). Must stay in sync.

## Conventions

- **Card encoding:** suit letter + rank. "SA" = Ace of Spades, "D10" = 10 of Diamonds, "JO" = Joker.
- **Dart:** Type hints always, const constructors, sealed classes for unions. No Firebase anywhere.
- **TypeScript:** Strict mode, Hono routing, Vitest tests.
- **Theme:** Diwaniya aesthetic — dark wood (#3B2314), burgundy (#5C1A1B), gold (#C9A84C), cream (#F5ECD7). IBM Plex Mono (Latin), Noto Kufi Arabic (Arabic).

## Build & Run

```bash
# Flutter (project root)
flutter pub get
flutter run                                                    # offline works out of the box
flutter run --dart-define=WORKER_URL=http://localhost:8787      # with local backend
flutter test && flutter analyze

# Workers (workers/ directory)
npm install
npm run dev                                                     # local :8787
npx vitest
npx wrangler deploy
npx wrangler secret put JWT_SECRET                              # prod secret
npx wrangler d1 execute kout-db --file=migrations/001_init.sql  # DB migrations
```

## Known Issues

1. **Disconnect alarm bug** — `game-room.ts` alarm handler has early `return` after first forfeit, skipping remaining players. Remove the early return.
2. **ELO never updates** — `users.elo_rating` in D1 is read but never written after games. Need to call ELO calc from GameRoom on GAME_OVER.
3. **Online services incomplete** — Reconnection untested, no mid-game state recovery, no error display in UI, no matchmaking queue timeout.
4. **WORKER_URL for prod** — `config.dart` defaults to localhost. Prod build needs `--dart-define=WORKER_URL=https://...workers.dev`. Also `wrangler.toml` JWT_SECRET is placeholder.

## Priorities

1. Polish offline mode (UI/UX, sounds, 6-player, bot difficulty)
2. Fix backend blocking issues
3. Online multiplayer E2E testing
4. Platform builds (iOS, Android, macOS, web)
