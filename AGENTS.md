# AGENTS.md

Bahraini trick-taking card game (Kout). Flutter/Flame client + Cloudflare Workers backend.

## Build & Test

```bash
flutter pub get
flutter test
flutter analyze
dart format --set-exit-if-changed .
```

## Architecture

```
lib/app/screens/       — Flutter screens (home, lobby, matchmaking, game)
lib/app/services/      — Auth, GameService, Matchmaking, Presence
lib/game/components/   — Flame components (cards, hand, trick area, HUD, seats)
lib/game/overlays/     — Game overlays (bid, trump, results, game over)
lib/game/managers/     — Layout, Animation, Sound managers
lib/game/theme/        — KoutTheme, CardPainter, GeometricPatterns, Textures
lib/shared/models/     — Card, Deck, Bid, Trick, GameState, enums
lib/shared/logic/      — BidValidator, PlayValidator, TrickResolver, Scorer
lib/offline/           — LocalGameController, bot strategies
workers/src/           — Cloudflare Workers (Hono, Durable Objects, D1)
```

## Theme — Diwaniya Aesthetic

All UI must use these colors (defined in `lib/game/theme/kout_theme.dart`):

- **Table/Background:** dark wood `#3B2314`
- **Primary (cards/panels):** muted green `#425944`
- **Accent (gold):** `#C9A84C` — use for highlights, active states, borders
- **Secondary (burgundy):** `#5C1A1B` — errors, loss states
- **Text:** cream `#F5ECD7` / blue-grey `#BACDD9`
- **Card back:** deep green `#2D3B2E`

Fonts: IBM Plex Mono (Latin), Noto Kufi Arabic (Arabic).

**Never use Material defaults** (Colors.red, Colors.grey, Colors.blue, etc.). Always use `KoutTheme.*` or `DiwaniyaColors.*` constants.

## Game Rules (non-obvious)

- 32-card deck: S/H/C have 8 ranks, Diamonds has 7 (no 7-of-diamonds), plus 1 Joker
- 4 players, 2 teams: seats 0,2 = Team A, seats 1,3 = Team B
- Counter-clockwise play: `nextSeat(i) = (i - 1 + 4) % 4`
- Card encoding: suit letter + rank. "SA" = Ace of Spades, "JO" = Joker
- Bids: 5 (Bab), 6, 7, 8 (Kout). One CCW orbit per player (bid or pass once); Kout ends bidding immediately.

## Conventions

- Type hints always, const constructors, sealed classes for unions
- One class per file unless tightly coupled
- Follow existing naming conventions
- Keep changes focused — one concern per commit
- Do NOT add Firebase imports — this project uses Cloudflare Workers
- Do NOT create `.jules/` metadata files
