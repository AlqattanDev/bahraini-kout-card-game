# CLAUDE.md — Bahraini Kout Card Game

## Project Overview

A Bahraini trick-taking card game ("Kout") built with Flutter/Flame (client) and Cloudflare Workers (backend). The game supports offline play vs bots and online multiplayer via WebSockets + Durable Objects.

**Owner:** Ali (ali@exidiful.com)
**Stack:** Dart/Flutter + Flame (client), TypeScript + Hono + Cloudflare Workers (backend)
**Last updated:** 2026-03-24

---

## Game Rules (Bahraini Kout)

### Deck
- **4 Players:** 32 cards. Spades/Hearts/Clubs have 8 cards each (A,K,Q,J,10,9,8,7). Diamonds has 7 cards (A,K,Q,J,10,9,8 — no 7). Plus 1 Joker (Khallou). Each player gets 8 cards.
- **6 Players:** 48 cards. Each suit has more cards (down to 3). Diamonds has 11 cards (no 3). Plus 1 Joker. Each player gets 8 cards.
- Currently only 4-player mode is implemented.

### Teams
- 4 players in 2 teams. Seats 0,2 = Team A. Seats 1,3 = Team B.
- Seating is counter-clockwise: `nextSeat(i) = (i - 1 + 4) % 4`, so 0→3→2→1.

### Bidding
- Dealer is randomized at game start. After each round, the losing team (fewer points) deals. If the dealer is already on the losing team, they stay. If the losing team flipped, dealer rotates one step counter-clockwise via `nextSeat()`, landing on the new losing team. If scores are tied, dealer stays.
- Bids: 5 (Bab), 6, 7, 8 (Kout). Each bid must be higher than the current highest.
- Bidding starts with seat after dealer, goes counter-clockwise (right to left).
- A player can bid or pass. Once you pass, you're out.
- **Forced bid:** If 3 players pass and no one has bid, the last remaining player MUST bid (at least 5/Bab). They cannot pass.
- If 3 players pass but someone already bid, the last player CAN still pass (the existing bidder wins).
- Kout (bid 8) ends bidding immediately — no further bids allowed.
- Each player's bid/pass action is tracked in `bidHistory` and displayed on their seat during bidding.
- **No malzoom/reshuffle.** The forced-bid rule replaces the old reshuffle mechanic entirely.

### Trump Selection
- The winning bidder selects a trump suit.

### Trick Play
- Seat after bidder leads the first trick.
- Players must follow the led suit if they can. The Joker is exempt — it can be played at any time regardless of what suits the player holds.
- The Joker (Khallou) **can be led**, but doing so triggers an immediate round loss for the leading player's team (+10 penalty to opponent, same as poison joker).
- Trick winner: Joker > highest trump > highest of led suit.

### Poison Joker
- If a player's last remaining card is the Joker, their team **automatically loses the round** (+10 penalty to opponent). The Joker is never actually played.
- Leading the Joker also triggers the same +10 penalty (Joker lead = voluntary poison).

### Scoring (Tug-of-War to 31)
- **Single shared score** starting at 0. Points won by one team first deduct from the opponent's score, then the remainder goes to the winning team. Only one team ever has a non-zero score (the leading team).
- The score is displayed as a positive number, colored to indicate the leading team (gold for Team A, brown for Team B, neutral when tied at 0).
- Bid 5 (Bab): win = 5 points, lose = 10 points to opponent
- Bid 6: win = 6 points, lose = 12 points to opponent
- Bid 7: win = 7 points, lose = 14 points to opponent
- Bid 8 (Kout): **instant win** — winning team's score is set to 31 regardless of current position. Losing kout = opponent instantly gets 31.
- Bidding team wins the round if they take ≥ bid value tricks.
- First team to reach 31 points wins the game.

---

## Architecture

```
lib/                          # Flutter/Dart client
├── main.dart                 # Entry point → KoutApp
├── app/                      # Flutter app shell
│   ├── app.dart              # MaterialApp with routes: /, /matchmaking, /game, /offline-lobby
│   ├── config.dart           # AppConfig (WORKER_URL via --dart-define, defaults to localhost:8787)
│   ├── models/
│   │   ├── client_game_state.dart  # Client-side game state (with fromMap for Worker JSON)
│   │   ├── game_mode.dart          # Sealed class: OnlineGameMode | OfflineGameMode
│   │   ├── player.dart
│   │   └── seat_config.dart        # SeatConfig(seatIndex, uid, displayName, isBot)
│   ├── screens/
│   │   ├── home_screen.dart        # Main menu: Play Online / Play Offline
│   │   ├── matchmaking_screen.dart # Online queue UI
│   │   ├── game_screen.dart        # Hosts KoutGame (Flame) with overlay builders
│   │   └── offline_lobby_screen.dart # Seat selection before offline game
│   └── services/
│       ├── auth_service.dart       # Anonymous JWT auth via Worker endpoint
│       ├── game_service.dart       # WebSocket game client (implements GameInputSink)
│       ├── matchmaking_service.dart # HTTP+WS matchmaking client
│       └── presence_service.dart   # No-op (presence is via WS connection)
├── game/                     # Flame rendering engine
│   ├── kout_game.dart        # Main FlameGame — listens to stateStream, manages components + overlays
│   ├── components/
│   │   ├── card_component.dart     # Single card renderer with tap support
│   │   ├── hand_component.dart     # Fan of cards at bottom (sorts by trump, highlights playable)
│   │   ├── trick_area.dart         # 4 card slots in center for current trick
│   │   ├── player_seat.dart        # Name + card count + active indicator per seat
│   │   ├── score_display.dart      # Team A vs Team B scores at top
│   │   ├── table_background.dart   # Wood grain table texture
│   │   └── ambient_decoration.dart # Tea glass silhouettes + geometric patterns
│   ├── managers/
│   │   ├── layout_manager.dart     # Calculates positions for all elements based on screen size
│   │   └── animation_manager.dart  # Card play arc, trick collection, deal, poison joker shake, gold particles
│   ├── overlays/
│   │   ├── bid_overlay.dart        # Bid selection UI (5/6/7/8/Pass)
│   │   ├── trump_selector.dart     # Trump suit picker
│   │   ├── round_result_overlay.dart # Round outcome display
│   │   └── game_over_overlay.dart  # Final result + return to menu
│   └── theme/
│       ├── kout_theme.dart         # Colors, fonts (IBM Plex Mono, Noto Kufi Arabic), card dimensions
│       ├── card_painter.dart       # Canvas-based card face/back rendering
│       ├── geometric_patterns.dart # Islamic geometric pattern overlays
│       └── textures.dart           # Procedural wood/felt textures
├── offline/                  # Offline game engine (no network)
│   ├── local_game_controller.dart  # Full game loop: deal→bid→trump→play→score. Streams ClientGameState.
│   ├── full_game_state.dart        # Server-side-equivalent mutable state (hands, scores, trick plays, etc.)
│   ├── player_controller.dart      # Abstract PlayerController + sealed GameAction/ActionContext types
│   ├── human_player_controller.dart # Completer-based input from UI (implements GameInputSink)
│   ├── bot_player_controller.dart  # Routes to bid/trump/play strategies
│   ├── game_input_sink.dart        # Interface: playCard, placeBid, pass, selectTrump
│   └── bot/
│       ├── hand_evaluator.dart     # Scores hand strength (expected winners) based on rank, suit length, voids
│       ├── bid_strategy.dart       # Maps hand strength → bid amount, decides bid vs pass
│       ├── trump_strategy.dart     # Picks trump from strongest suit (count * 2 + rank strength)
│       └── play_strategy.dart      # Lead/follow strategy: suit length, partner awareness, trump management
└── shared/                   # Shared game logic (used by both offline and could be shared with server)
    ├── constants.dart              # Suit/rank encoding maps (S/H/C/D, A/K/Q/J/10/9/8/7)
    ├── models/
    │   ├── enums.dart              # Suit(spades,hearts,clubs,diamonds), Rank(ace..seven with int values)
    │   ├── card.dart               # GameCard(suit, rank, isJoker) with encode/decode ("SA"=Ace of Spades, "JO"=Joker)
    │   ├── deck.dart               # Deck.fourPlayer() → 32 cards (diamonds missing 7), deal(4) shuffles+splits
    │   ├── bid.dart                # BidAmount enum: bab(5/5/10), six(6/6/12), seven(7/7/14), kout(8/31/31)
    │   ├── trick.dart              # TrickPlay(playerIndex, card), Trick(leadPlayerIndex, plays, ledSuit)
    │   └── game_state.dart         # GamePhase enum, Team enum with .opponent, teamForSeat(), nextSeat()
    └── logic/
        ├── bid_validator.dart      # validateBid, validatePass, checkBiddingComplete, isLastBidder
        ├── play_validator.dart     # validatePlay (follow suit rule, can't lead joker), detectPoisonJoker
        ├── trick_resolver.dart     # resolve(trick, trumpSuit) → winner seat (joker > trump > led suit)
        └── scorer.dart             # calculateRoundResult, calculatePoisonJokerResult, applyScore, checkGameOver

workers/                      # Cloudflare Workers backend (TypeScript)
├── wrangler.toml             # Config: GameRoom DO, MatchmakingLobby DO, D1 "kout-db", JWT_SECRET var
├── src/
│   ├── index.ts              # Hono router: /auth/anonymous, /api/matchmaking/join|leave, /ws/game/:id, /ws/matchmaking
│   ├── env.ts                # Env type (DB, GAME_ROOM, MATCHMAKING_LOBBY, JWT_SECRET)
│   ├── auth/jwt.ts           # signToken, verifyToken (HMAC-SHA256)
│   ├── game/
│   │   ├── types.ts          # Game types/interfaces
│   │   ├── card.ts           # Card encoding (mirrors Dart)
│   │   ├── deck.ts           # Deck creation + deal
│   │   ├── bid-validator.ts  # Mirrors shared/logic/bid_validator.dart
│   │   ├── play-validator.ts # Mirrors shared/logic/play_validator.dart
│   │   ├── trick-resolver.ts # Mirrors shared/logic/trick_resolver.dart
│   │   ├── scorer.ts         # Mirrors shared/logic/scorer.dart
│   │   └── game-room.ts      # GameRoom Durable Object: WS handler, game state, actions, alarm disconnect
│   ├── matchmaking/
│   │   ├── queue.ts          # D1 queue operations (join, leave, get, remove, recordGame)
│   │   ├── matcher.ts        # ELO bracket matching (findBestMatch, assignSeats)
│   │   ├── elo.ts            # ELO rating utilities
│   │   └── lobby.ts          # MatchmakingLobby DO: WS notifications for match found
│   └── presence/
│       └── disconnect.ts     # Disconnect handling
└── test/                     # Vitest tests
    ├── auth/jwt.test.ts
    ├── game/
    │   ├── card.test.ts
    │   ├── bid-validator.test.ts
    │   ├── scorer.test.ts
    │   ├── trick-resolver.test.ts
    │   └── game-room.test.ts
    └── matchmaking/matcher.test.ts

test/                         # Flutter/Dart tests
├── shared/
│   ├── models/ (bid_test, card_test, deck_test)
│   ├── logic/ (bid_validator_test, play_validator_test, scorer_test, trick_resolver_test)
│   └── integration/round_simulation_test.dart
├── offline/
│   ├── local_game_controller_test.dart
│   ├── stream_integration_test.dart
│   └── bot/ (bid_strategy_test, hand_evaluator_test, play_strategy_test, trump_strategy_test)
├── game/kout_game_test.dart
├── app/models/client_game_state_test.dart
└── integration/client_server_sync_test.dart
```

---

## Current Status (as of 2026-03-24)

### WORKING — Offline Mode (End-to-End)
The offline single-player mode is fully functional:
- `LocalGameController` runs the complete game loop: deal → bid → trump → play tricks → score → rotate dealer → repeat until 31.
- Human player at seat 0, 3 bot opponents with AI strategies.
- `HumanPlayerController` uses `Completer<GameAction>` — UI taps resolve the future.
- Flame engine renders everything: card fan, trick area, seat indicators, score display, overlays for bidding/trump/results.
- Card play animations with drop shadows, gold particle trick-win celebrations, poison joker shake.
- All game rules implemented: follow suit, can't lead joker, poison joker auto-loss, malzoom reshuffle/forced bid, kout instant win/loss.

### WORKING — Cloudflare Workers Backend (Scaffolded)
- All game logic ported to TypeScript (mirrors Dart shared/ logic exactly).
- GameRoom Durable Object handles game state, WebSocket messaging, bid/trump/play actions.
- MatchmakingLobby DO for queue WS notifications.
- D1 database for matchmaking queue, user records, game history.
- JWT anonymous auth.
- Hono router wires everything together.
- Tests exist for game logic, auth, and matchmaking.

### WORKING — Flutter Online Services (Basic)
- `AuthService`: anonymous sign-in via POST /auth/anonymous, caches JWT + UID in SharedPreferences.
- `GameService`: WebSocket client to GameRoom DO, parses gameState/hand/error events, implements `GameInputSink`.
- `MatchmakingService`: HTTP join/leave queue + WS listen for match notification.
- `ClientGameState.fromMap()` handles both Worker (UPPER_SNAKE) and legacy (camelCase) JSON formats.

---

## Known Blocking Issues

These were identified in a pre-implementation review (see BLOCKING_ISSUES.md for full details):

### 1. Disconnect Alarm Bug — TRIVIAL FIX
**File:** `workers/src/game/game-room.ts` alarm handler
**Problem:** Early `return` after first player forfeit skips remaining players in the same alarm cycle.
**Fix:** Remove the early return so the loop continues checking all disconnected players.

### 2. Android/iOS Firebase Cleanup — DOCS ONLY
**Problem:** Plan says "check and clean up" but doesn't specify exact files/lines for removing Firebase remnants.
**What to check:**
- `android/build.gradle.kts` — remove `com.google.gms.google-services` plugin
- `android/app/build.gradle.kts` — remove `com.google.gms.google-services` plugin apply
- Delete `android/app/google-services.json` if still present
- `ios/Podfile` — ensure no Firebase pod references remain
- Run `cd ios && pod install` to clean up

### 3. WORKER_URL Build Config — CRITICAL FOR DEPLOY
**File:** `lib/app/config.dart`
**Problem:** `WORKER_URL` defaults to `http://localhost:8787`. No documentation for injecting prod URL.
**Fix needed:** Document build commands:
```bash
# Dev
flutter run --dart-define=WORKER_URL=http://localhost:8787
# Prod
flutter build apk --release --dart-define=WORKER_URL=https://bahraini-kout.<account>.workers.dev
```
Also: `wrangler.toml` has `JWT_SECRET = "replace-with-actual-secret"` — must use `wrangler secret put JWT_SECRET` for prod.

### 4. ELO Never Updated After Games
**Problem:** `users.elo_rating` is created in D1 schema and read during matchmaking, but never updated after a game completes. ELO is permanently 1000.
**Fix:** Add ELO delta calculation in `workers/src/matchmaking/elo.ts` and call it from GameRoom when game reaches GAME_OVER phase.

### 5. GameRoom DO Code Quality
**Problem:** The GameRoom DO was implemented as one large task. Review for:
- Proper error handling on all action handlers
- Edge cases in disconnect/reconnect flow
- State persistence via Durable Object storage

### 6. Flutter Online Services — Incomplete
**Problem areas in `GameService`:**
- Reconnection logic exists (exponential backoff, max 5 attempts) but untested
- No handling for mid-game state recovery after reconnect
- Error stream exists but UI doesn't display errors to user
**Problem areas in `MatchmakingService`:**
- No handling for "already in queue" server error
- No timeout on queue wait

---

## What Should Be Worked On Next

### Priority 1: Polish Offline Mode (Ship-Ready)
The offline mode is the closest to being shippable. Focus areas:
1. **UI/UX polish** — The home screen and lobby are bare-bones. Need Diwaniya aesthetic (dark wood, gold accents, Islamic geometric patterns). The theme system (`KoutTheme`) already has the color palette and fonts.
2. **Round result overlay** — Show trick breakdown, which team won, score delta, running total.
3. **Game over screen** — Show final scores, winner celebration, "Play Again" button.
4. **Sound effects** — `AnimationManager` has audio hook methods (`onCardPlay`, `onDealStart`, etc.) that are no-ops. Add card slap, shuffle, and win sounds.
5. **6-player mode** — `Deck` only has `fourPlayer()`. Need `sixPlayer()` factory and UI support for 6 seats.
6. **Bot difficulty levels** — Current bot is one difficulty. Could add easy/medium/hard by adjusting `HandEvaluator` thresholds.

### Priority 2: Fix Backend Blocking Issues
1. Fix disconnect alarm early-return bug (1-line change)
2. Implement ELO update endpoint
3. Clean up any remaining Firebase references in native configs

### Priority 3: Online Multiplayer Testing
1. Deploy Workers to Cloudflare (`wrangler deploy`)
2. Set proper JWT_SECRET (`wrangler secret put JWT_SECRET`)
3. Build Flutter with prod WORKER_URL
4. End-to-end test: auth → matchmaking → game → scoring
5. Test disconnect/reconnect flow
6. Test concurrent games

### Priority 4: Platform Builds
1. iOS build and test on simulator/device
2. Android build and test
3. macOS build (already has network entitlement)
4. Consider web build (WebSocket support)

---

## Build & Run Commands

```bash
# Flutter (from project root)
flutter pub get
flutter run                                         # Debug (offline works, online needs local Workers)
flutter run --dart-define=WORKER_URL=http://localhost:8787  # Explicit local backend
flutter test                                        # Run all Dart tests
flutter analyze                                     # Lint

# Workers backend (from workers/ directory)
npm install
npm run dev                                         # Local dev server on :8787 (needs wrangler)
npx vitest                                          # Run TypeScript tests
npx wrangler deploy                                 # Deploy to Cloudflare
npx wrangler secret put JWT_SECRET                  # Set production secret
npx wrangler d1 execute kout-db --file=migrations/001_init.sql  # Run DB migrations
```

---

## Key Design Decisions

1. **Offline-first architecture** — The game loop in `LocalGameController` is entirely self-contained. It doesn't depend on any network layer. The same `ClientGameState` stream interface is used for both offline (from `LocalGameController`) and online (from `GameService` WebSocket).

2. **`GameInputSink` abstraction** — Both `HumanPlayerController` (offline) and `GameService` (online) implement this interface. `KoutGame` (Flame) doesn't know or care whether it's offline or online.

3. **Sealed classes for game actions** — `GameAction` is `BidAction | PassAction | TrumpAction | PlayCardAction`. `ActionContext` is `BidContext | TrumpContext | PlayContext`. Bot and human controllers both return `Future<GameAction>`.

4. **Durable Objects for game rooms** — Each game room is a single-threaded DO instance. No transaction conflicts. WebSocket hibernation for connection management. 90-second disconnect alarm for forfeit.

5. **Shared logic, dual implementation** — Game rules (bid validation, play validation, trick resolution, scoring) are implemented in both Dart (`shared/logic/`) and TypeScript (`workers/src/game/`). They must stay in sync.

6. **Counter-clockwise seating** — `nextSeat(i) = (i - 1 + 4) % 4` gives order 0→3→2→1. This matches traditional Bahraini card game seating.

---

## Code Style & Conventions

- **Dart:** Type hints always. Prefer `const` constructors. Use sealed classes for unions. No Firebase dependencies anywhere.
- **TypeScript:** Strict mode. Hono for routing. Vitest for testing.
- **Card encoding:** 2-char string. First char = suit (S/H/C/D), rest = rank (A/K/Q/J/10/9/8/7). Joker = "JO".
- **Team indexing:** Even seats (0,2) = Team A. Odd seats (1,3) = Team B. `teamForSeat(i) = i.isEven ? Team.a : Team.b`.
- **Theme:** Diwaniya aesthetic. Dark wood (#3B2314), burgundy (#5C1A1B), gold accent (#C9A84C), cream text (#F5ECD7). IBM Plex Mono for Latin, Noto Kufi Arabic for Arabic text.
- **No Firebase:** Firebase was fully removed. All references should be to Cloudflare Workers, D1, Durable Objects.

---

## Git History (Recent)

```
d3bad7a feat: add offline single-player mode with bot AI
64f4aef chore: add .worktrees/ to .gitignore
2c844c6 Merge branch 'feat/cloudflare-workers-migration'
91c176b chore: final cleanup — remove old Firebase E2E tests, update D1 database ID
6bf8df5 Add offline single-player mode design spec
b54c47e fix: add network client entitlement for macOS sandbox
96143a1 fix: remove GoogleService-Info.plist from Xcode projects
f171446 fix: remove GoogleService-Info.plist references from Xcode projects
5e6a468 feat: update screens to use new Cloudflare Workers-backed services
0daf7d0 chore: remove all Firebase files and dependencies
e3f8993 feat: rewrite Flutter services from Firebase to HTTP+WebSocket
4a55fb1 feat: wire up Hono router with auth, matchmaking, and WebSocket game endpoints
761a08d feat: add MatchmakingLobby Durable Object for queue notifications
a7e2e09 feat: implement GameRoom Durable Object
cb68472 feat: add D1 matchmaking queue + ELO bracket matcher
ae54f95 feat: add JWT-based anonymous auth
63cf998 feat: port game logic from Firebase Cloud Functions to Workers
51ae873 chore: add .gitignore for workers, remove node_modules from tracking
3f9d695 feat: scaffold Cloudflare Workers project with Hono, DO bindings, D1
59a5bb7 docs: add Firebase to Cloudflare Workers migration plan
```

---

## Related Docs

- `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md` — Full game design spec
- `docs/superpowers/plans/2026-03-23-firebase-to-cloudflare-migration.md` — Migration plan (79KB)
- `BLOCKING_ISSUES.md` — 6 blocking issues with code fixes
- `MIGRATION_REVIEW.md` — Comprehensive technical review
- `REVIEW_SUMMARY.md` — Executive summary of review
- `REVIEW_INDEX.md` — Navigation guide for review docs
- `implementation.txt` / `p2c.txt` — Original implementation notes
