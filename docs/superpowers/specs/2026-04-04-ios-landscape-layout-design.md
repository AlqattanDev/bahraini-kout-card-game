# iOS Landscape Layout Fix — Design Spec

**Date:** 2026-04-04
**Branch:** `feat/ui-fix-v2` (based on `1c692ce9`)
**Goal:** Fix the iPhone landscape layout without breaking macOS/iPad portrait layout.

## Problem

The current LayoutManager uses hardcoded pixel offsets from screen edges. On iPhone in landscape:
- Side player seats clip into Dynamic Island safe area (59pt left/right insets)
- Player avatar at bottom-right gets cut off by home indicator
- Hand cards at 1.4x scale are too large (~37% of screen height)
- No landscape-specific positioning logic exists

## Decisions

### Orientation
- **iPhone:** Lock to landscape via `SystemChrome.setPreferredOrientations`
- **iPad / macOS:** System default (user chooses)
- Detection: check `defaultTargetPlatform == TargetPlatform.iOS` and screen shortest side < 500 (phone vs tablet heuristic)

### Table Background
- **Landscape:** Remove `PerspectiveTableComponent`. Background is a radial green gradient with warm vignette — no trapezoid.
- **Portrait:** Keep existing trapezoid table unchanged.

### Avatars
- **Landscape:** No `PlayerSeatComponent` rendered. Players identified by name labels (text + team color dot) positioned near their card fans.
- **Portrait:** Keep existing avatar rendering unchanged.

### Layout Strategy
- Add `EdgeInsets safeArea` parameter to `LayoutManager`
- Compute `safeRect` = screen rect minus safe area insets
- Add `isLandscape = screenWidth > screenHeight` branch
- Landscape: percentage-based positioning within `safeRect`
- Portrait: existing logic unchanged (no modifications)

## Landscape Layout Spec

### Screen Zones

```
┌──────────────────────────────────────────────────┐
│safe│  bot_1 cards   bot_2 cards   bot_3 cards│safe│
│    │  (name+pass)   (name+crown)  (name+pass)│    │
│    │                                    [HUD] │    │
│    │                                   0/31 R1│    │
│    │               ┌────────┐          BID 5♥ │    │
│    │               │ TRICK  │                 │    │
│    │               │  AREA  │                 │    │
│    │               └────────┘                 │    │
│    │                                          │    │
│    │          ┌── your hand cards ──┐     You │    │
└──────────────────────────────────────────────────┘
```

### Component Positions (Landscape)

All positions relative to `safeRect` (screen minus insets).

| Component | X | Y |
|-----------|---|---|
| Left opponent (bot_1) | `safeRect.left + 16` | `safeRect.top + 16` |
| Partner (bot_2) | `safeRect.center.x` (centered) | `safeRect.top + 16` |
| Right opponent (bot_3) | `safeRect.right - 16` (right-aligned) | `safeRect.top + 16` |
| Trick center | `safeRect.center.x` | `safeRect.top + safeHeight * 0.48` |
| Hand center | `safeRect.center.x` | `safeRect.bottom - cardHeight/2 - 10` |
| "You" label | `safeRect.right - 16` | `safeRect.bottom - 20` |
| HUD | `safeRect.right - hudWidth - 8` | opponent fan bottom + 8 |

### Opponent Display (Landscape)

Each opponent is rendered as:
1. **Name label:** player name + team color dot (6pt circle, red for Team B, blue for Team A)
2. **Bid status:** "PASS" or "BID X" beside name in gold text
3. **Bidder indicator:** Crown character beside name
4. **Active turn:** Name label glows gold when it's that player's turn
5. **Face-down card fan:** Horizontal fan of 4-5 card backs below name label. Card backs use existing Diwaniya styling (dark wood to burgundy gradient, gold border).

Opponent fan card size: ~26x37pt (0.37x scale of base 70x100).

### Hand Cards (Landscape)

- **Scale:** `min(1.4, safeRect.height * 0.15 / 100)` — yields ~0.85x on iPhone landscape (~390pt height), unchanged 1.4x on macOS/iPad
- **Position:** Bottom-center of safeRect
- **Fan arc, spacing, sorting:** Same formulas as current LayoutManager, just using the dynamic scale
- **Card size at 0.85x:** ~60x85pt (comfortable on iPhone, ~22% of screen height)

### Trick Area (Landscape)

- Position: Dead center of safeRect (slightly above vertical center)
- Card offsets from center: Same 55pt cross pattern as current implementation
- Trick cards rendered at same scale as hand cards (dynamic)
- Subtle gold circle marker: 130pt diameter, 6% opacity

### HUD (Landscape)

- Position: Right side of safeRect, below opponent card fans
- Same content: score, bid, trick pips, timer
- Width: 110pt (slightly narrower than portrait's 160pt to fit)
- Background: `rgba(59,35,20,0.88)` with gold border

### Overlays (Landscape)

- Bid overlay and trump selector: Centered within `safeRect`, not full screen
- Scrim: Still covers full screen (looks right behind notch areas)
- Round result and game over overlays: Same treatment — centered in safeRect

## Safe Area Values (Reference)

| Device | Left | Right | Top | Bottom |
|--------|------|-------|-----|--------|
| iPhone 14 Pro+ (Dynamic Island) | 59pt | 59pt | 0pt | 21pt |
| iPhone X–14 (notch) | 44pt | 44pt | 0pt | 21pt |
| iPhone SE (no notch) | 0pt | 0pt | 0pt | 0pt |
| iPad | 0pt | 0pt | 0pt | 0pt |
| macOS | 0pt | 0pt | 0pt | 0pt |

## Files Changed

| File | Change |
|------|--------|
| `lib/game/managers/layout_manager.dart` | Add `EdgeInsets safeArea` param. Add `isLandscape` branch. Compute `safeRect`. All landscape positions relative to safeRect. Export `handCardScale` getter. |
| `lib/game/kout_game.dart` | Accept safeArea from Flutter widget. Pass to LayoutManager on resize. In landscape: hide `PerspectiveTableComponent`, hide `PlayerSeatComponent`s, show name labels for opponents. |
| `lib/app/screens/game_screen.dart` | Read `MediaQuery.of(context).padding`. Pass as safeArea to game widget. |
| `lib/game/components/hand_component.dart` | Replace hardcoded `handCardScale = 1.4` with `layout.handCardScale`. |
| `lib/game/components/player_seat.dart` | Add `visible` flag. Set to false in landscape. |
| `lib/main.dart` | Set `SystemChrome.setPreferredOrientations([landscape])` on iPhone, unrestricted elsewhere. |
| `lib/game/overlays/*.dart` | Use SafeArea-aware centering for overlay content. |
| `lib/game/components/table_background.dart` | Landscape: render radial gradient only, skip trapezoid vertices. |

## What Does NOT Change

- All portrait layout math (macOS, iPad)
- Card sorting and playability logic
- Animation system (deal, play, collect)
- Theme colors, fonts, textures
- Game logic and state management
- Trick area relative offsets (55pt cross) — just recentered
- HUD content — same data, repositioned
- Sound effects
- Opponent hand fan rendering logic (just repositioned and rescaled)
