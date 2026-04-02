# HUD Redesign — Unified Info Panel

**Date:** 2026-04-02
**Status:** Approved

## Problem

The game screen has 6 independent HUD elements scattered across the board: R1/T0 pill (top-left), score box with trick pips (top-right), PASS/BID speech bubbles floating above every player, a sound toggle icon overlapping the score area, and card count badges under each opponent's hand fan. This creates visual clutter and splits related information across unrelated locations.

## Design

### 1. Unified HUD Panel (replaces ScoreHudComponent + GameHudComponent)

A single `UnifiedHudComponent` extending `PositionComponent`, positioned top-right, ~160px wide, vertically stacking:

**Row 1 — Score + Round:**
- Tug-of-war score in large text (e.g. `0`) with `/ 31` suffix at reduced opacity.
- Round number (`R1`) right-aligned, small, subdued.

**Divider**

**Row 2 — Bid + Trump:**
- Current winning bid value (e.g. `BID 5`) + trump suit symbol.
- Entire row colored in the bidding team's color: `KoutTheme.teamAColor` (blue `#4A90D9`) for Team A, `KoutTheme.teamBColor` (red `#D94A4A`) for Team B.
- **Phase visibility:** Hidden during `bidding` phase. During `trumpSelection`, show `BID X` only (no suit symbol yet). From `playing` onward, show `BID X` + trump suit symbol.

**Row 3 — Trick Pips:**
- Two rows of filled/unfilled circles, same logic as current ScoreHudComponent.
- Top row = bidder's team, bottom row = opponent.
- Visible only during `playing` and `roundScoring` phases.

**Divider**

**Row 4 — Game Timer:**
- Elapsed time since first deal, format `MM:SS`.
- Small clock text + time in subdued cream (`DiwaniyaColors.cream` at 0.65 opacity).
- Runs continuously from game start to game over. Never resets, never pauses.

**Styling:** Same dark semi-transparent background (`DiwaniyaColors.scoreHudBg`), rounded corners (12px), border (`DiwaniyaColors.scoreHudBorder`, 1.5px stroke) as current ScoreHudComponent.

**Dynamic height:** The panel's height adjusts based on which rows are visible. During bidding only rows 1 + 4 show. After trump selection, rows 2 + 3 appear. Use `_computeHeight()` based on current phase.

**Initialization:** Create with placeholder values (score=0, round=1, bid=null, trump=null). Populate on first `ClientGameState`. Render empty rows gracefully (skip bid/pip sections if bid is null).

### 2. Bidder Avatar Glow Ring

When a player wins the bid (phase transitions past `bidding`), their `PlayerSeatComponent` avatar gets a persistent glow ring in their team color.

**Lifecycle:**
- **Appears:** When `state.bidderUid` is set AND phase is `trumpSelection`, `playing`, or `roundScoring`.
- **Clears:** When phase transitions to `bidding` (new round starts).
- **On reconnect:** `_updateSeats()` re-derives `isBidder` from `state.bidderUid` + current phase, so glow is always correct after reconnect.

**Rendering:**
- Static outer ring (NOT pulsing) — stroke at `avatar radius + 6px`, stroke width 3px, team color at 0.5 opacity.
- Renders BEHIND the existing active-turn pulsing ring (`_GlowPulseComponent`). So when a player is both the bidder AND the active player, both are visible: static team-color ring behind, pulsing green ring in front.

**Implementation in PlayerSeatComponent:**
- Add `bool isBidder = false` and `Color? bidderGlowColor` fields.
- In `render()`, if `isBidder`, draw the outer ring before the active-turn ring.

**Orchestration in KoutGame:**
- Add `_updateBidderGlow(ClientGameState state)` called from `_onStateUpdate()` after `_updateSeats()`.
- Loop over seats: set `isBidder = true` + team color on the seat whose UID matches `state.bidderUid`, if phase is not `bidding`. Clear all others.

### 3. Action Badges (kept, unchanged)

`ActionBadgeComponent` stays as-is. Bid/pass speech bubbles still appear above player seats during bidding with 2.5s auto-dismiss. Card play badges still appear during tricks with 1.8s auto-dismiss. No changes.

### 4. Removals

**GameHudComponent (top-left R1/T0 pill):** Delete file. Round number absorbed into unified HUD Row 1.

**Sound toggle IconButton:** Remove from `game_screen.dart` Stack (lines 225-241). Will return later in a settings overlay. SoundManager internals untouched.

**Card count badge on OpponentHandFan:** Remove badge rendering at lines 136-144 of `opponent_hand_fan.dart`. The fan itself and all its layout constants remain unchanged. `cardCount` field and `updateCardCount()` method stay (used for rendering the correct number of card backs). The `displayCount` clamping at line 73 stays — still needed for rendering the fan.

## Files Changed

| File | Change |
|------|--------|
| `lib/game/components/score_hud.dart` | Delete file (replaced by UnifiedHudComponent) |
| `lib/game/components/game_hud.dart` | Delete file (absorbed into UnifiedHudComponent) |
| `lib/game/components/unified_hud.dart` | **New file** — single panel with score, round, bid, trump, pips, timer |
| `lib/game/components/opponent_hand_fan.dart` | Remove card count badge rendering (lines 136-144) |
| `lib/game/components/player_seat.dart` | Add `isBidder` + `bidderGlowColor` fields, render static outer glow ring |
| `lib/game/kout_game.dart` | Replace `_scoreHud`/`_gameHud` with `_unifiedHud`. Add `Stopwatch`. Add `_updateBidderGlow()`. |
| `lib/app/screens/game_screen.dart` | Remove sound toggle `Positioned` widget (lines 225-241) |

## Timer Implementation

- `Stopwatch _gameTimer` field in `KoutGame`. Lazy-started on first `ClientGameState` received: `_gameTimer ??= Stopwatch()..start();`
- `UnifiedHudComponent` has an `updateTimer(Duration elapsed)` method.
- `KoutGame._onStateUpdate()` passes `_gameTimer.elapsed` to the HUD each frame.
- Timer runs continuously. No pause on disconnect, round scoring, or any phase — it's a simple "how long have we been playing" counter.
- Format: `MM:SS`. If somehow >59:59, clamp display to `59:59`.

## What's NOT Changing

- Action badges (bid/pass/card play speech bubbles) — kept as-is.
- Trick area, hand component, table, ambient decorations — untouched.
- Overlay system (bid overlay, trump selector, round result, game over) — untouched.
- Sound manager internals — untouched (just removing the UI toggle).
- OpponentHandFan layout, fan arc, card-back rendering — all unchanged.
