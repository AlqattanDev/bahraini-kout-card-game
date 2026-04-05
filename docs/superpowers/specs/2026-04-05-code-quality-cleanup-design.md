# Code Quality Cleanup — Consistency, Quality, Reusability, Duplication & Logic

**Date:** 2026-04-05
**Approach:** Vertical slices (file-by-file), comprehensive cleanup across all dimensions

## Overview

A systematic pass through the entire codebase to fix logic bugs, eliminate duplication, name magic numbers, unify component interfaces, and decompose the KoutGame god class. Organized into 6 file-group phases executed sequentially.

---

## Phase 1: Shared Logic Files

**Files:** `lib/shared/logic/bid_validator.dart`, `play_validator.dart`, `trick_resolver.dart`, `scorer.dart`, `lib/shared/models/bid.dart`, `enums.dart`, `lib/app/models/client_game_state.dart`

### 1.1 Kout first-trick rule — single source of truth

The Kout "must lead trump on first trick" rule is checked three different ways:
- `hand_component.dart` uses `state.trickWinners.isEmpty` (proxy, not equivalent to first trick)
- `play_strategy.dart` uses `isFirstTrick` boolean
- `play_validator.dart` uses `isFirstTrick` boolean

**Fix:** Make `PlayValidator.validatePlay()` the only authority. Both UI (`hand_component.dart`) and bot (`play_strategy.dart`) call through it to determine playable cards.

### 1.2 trick_resolver.dart — assert to throw

Replace `assert(plays.length == 4)` with `throw ArgumentError('Trick must have exactly 4 plays, got ${plays.length}')` so validation works in release builds.

### 1.3 bid_validator.dart — structured error types

Replace string error codes (`'already-passed'`, `'bid-not-higher'`) with a `BidValidationError` enum. Structured, testable, easier to map to UI messages.

### 1.4 scorer.dart — rename poisonTeam

Rename `poisonTeam` parameter to `jokerHolderTeam` in `calculatePoisonJokerResult()`. No logic change, just clarity — the parameter is the losing team, not the team being "poisoned."

### 1.5 bid.dart — nextAbove helper

Add `static BidAmount? nextAbove(BidAmount? current)` to eliminate duplicated "find next valid bid" loops in `bid_strategy.dart`.

### 1.6 client_game_state.dart — fix fragile type coercion

Fix `?? 0 as num` precedence issue in `fromMap` score parsing. Add defensive parsing that handles `int`, `num`, and `String` inputs.

---

## Phase 2: KoutGame + LayoutManager

**Files:** `lib/game/kout_game.dart`, `lib/game/managers/layout_manager.dart`

### 2.1 LayoutManager — name all magic numbers

Extract ~15 hardcoded values into named constants:

| Current | Constant name |
|---------|--------------|
| `55.0` | `_portraitTrickOffset` |
| `80` | `_portraitHandBottomOffset` |
| `120` | `_portraitPartnerTopOffset` |
| `70.0` | `_tableTopY` |
| `130.0` | `_tableBottomYOffset` |
| `32.0` | `_portraitArcBow` |
| `0.33 / 100` | Document the card scale calculation |

### 2.2 Extract ComponentLifecycleManager

Owns creation, mounting, unmounting, and disposal of all visual components (`_seats`, `_opponentFans`, `_opponentLabels`, `_hand`, `_trickArea`, `_ambientDecoration`, `_perspectiveTable`).

The duplicated landscape toggle pattern (repeated 6x in `_updateLandscapeVisibility()`) becomes a single `_toggleVisibility(Component, bool)` helper.

### 2.3 Extract OverlayController

Owns the overlay visibility state machine currently in `_updateOverlays()`. Decides which overlays to show/hide based on `GamePhase` transitions. KoutGame delegates on each state update.

### 2.4 Extract TurnTimerManager

Owns `_turnElapsed`, `_hudTickAccum`, timer display logic. Currently interleaved in `update()` and `_onStateUpdate()`.

### 2.5 KoutGame becomes thin coordinator

Holds references to the three extracted managers plus existing `AnimationManager`, `SoundManager`, `LayoutManager`. `_onStateUpdate()` becomes ~10 lines dispatching to each manager. Target: ~200-250 lines down from 752.

### 2.6 Remove dead tracking variables

Audit `_prevTrickPlayCount`, `_prevPhase`, `previousScoreA/B` etc. Move still-needed ones into the appropriate manager, delete the rest.

---

## Phase 3: Components

**Files:** All files in `lib/game/components/`

### 3.1 Unify updateState() signatures

All components receive `ClientGameState` directly. Components that currently take named parameters (`player_seat.dart`, `unified_hud.dart`, `opponent_name_label.dart`) extract what they need internally.

### 3.2 Extract CardFanPainter utility

Shared by `opponent_hand_fan.dart` and `opponent_name_label.dart`. Signature: `CardFanPainter.paint(canvas, {cardCount, fanAngle, arcBow, scaleX, scaleY})`. Each caller passes its own parameters.

### 3.3 Extract BidLabelPainter utility

Shared by `player_seat.dart` and `opponent_name_label.dart`. Signature: `BidLabelPainter.paint(canvas, {bidAction, center, offset, showCrown})`.

### 3.4 Fix Kout first-trick rule in hand_component.dart

Replace `state.trickWinners.isEmpty` proxy with call to `PlayValidator` (single source of truth from Phase 1).

### 3.5 Consolidate suit color in unified_hud.dart

Replace hardcoded `0xFFCC3333` with `KoutTheme.suitCardColor()`.

### 3.6 Name component magic numbers

| File | Value | Constant |
|------|-------|----------|
| `hand_component.dart` | `1.4` | `_handCardScale` |
| `unified_hud.dart` | `4.5`, `13.0`, `12.0` | `_pipRadius`, `_pipSpacing`, `_hudPadding` |
| `opponent_hand_fan.dart` | `14.0`, `0.55`, `16.0` | `_fanOverlap`, `_maxFanAngle`, `_arcBow` |
| `trick_area.dart` | `0.06` | `_nudgeFactor` |
| `player_seat.dart` | `18.0`, `12.0` | `_crownWidth`, `_crownHeight` |

### 3.7 Audit score_display.dart and trick_tracker.dart

If fully replaced by `unified_hud.dart`, delete. If still used, document which path.

---

## Phase 4: Overlays + Theme

**Files:** All files in `lib/game/overlays/`, `lib/game/theme/`

### 4.1 Centralize overlay spacing in OverlayStyles

- `EdgeInsets.symmetric(horizontal: 28, vertical: 24)` (3x) -> `OverlayStyles.panelPadding`
- `SizedBox(height: 20)` (2x) -> `OverlayStyles.sectionGap`
- Standardize or semantically name outlier values

### 4.2 Fix hardcoded suit colors in bid_announcement_overlay.dart

Replace inline colors with `KoutTheme.suitCardColor()`.

### 4.3 Consolidate button styling

`bid_overlay.dart` pass button should use `OverlayStyles.secondaryButton()` or a new `OverlayStyles.textButton()`.

### 4.4 Extract AnimatedOverlayMixin

Shared animation controller lifecycle for `overlay_animation_wrapper.dart`, `game_over_overlay.dart`, `round_result_overlay.dart`. Provides entry animation setup (controller, curves, dispose). Each overlay composes and customizes.

### 4.5 Theme file fixes

- `card_painter.dart`: Replace `DiwaniyaColors.pureWhite` with `KoutTheme` accessor
- `text_renderer.dart`: Replace hardcoded `'IBMPlexMono'` with `KoutTheme.monoFontFamily`
- `geometric_patterns.dart`: Name opacity multipliers (`_fillOpacity`, `_strokeOpacity`)
- `kout_theme.dart`: Add `monoFontFamily` and `arabicFontFamily` string constants

---

## Phase 5: Offline Engine + Bot

**Files:** `lib/offline/local_game_controller.dart`, `bot_player_controller.dart`, `human_player_controller.dart`, `full_game_state.dart`, `lib/offline/bot/bid_strategy.dart`, `play_strategy.dart`, `trump_strategy.dart`

### 5.1 Fix missing isForcedBid propagation

Add `isForced` field to `PlayContext`. Pass from `LocalGameController` when constructing `PlayContext` after bidding. `BotPlayerController` extracts and passes to `GameContext.fromClientState()` so play strategy's forced-bid survival mode triggers.

### 5.2 Validate bid history conversion

Guard `indexOf` returning `-1` in `_convertBidHistory()`. Throw `StateError` on unknown player UID.

### 5.3 Assert hand size after dealing

In `LocalGameController._deal()`, validate all hands have exactly 8 cards.

### 5.4 Use BidAmount.nextAbove in bid_strategy.dart

Replace two duplicated `for` loops with the helper from Phase 1.

### 5.5 Refactor _playTricks()

Break 62-line method into:
- `_playSingleTrick(trickNumber, tracker)`
- `_resolveTrick(plays, tracker)`
- `_checkEarlyTermination()`

### 5.6 Document FullGameState mutability contract

Add comment block explaining intentional mutability for offline engine performance, and that `_toClientState()` creates defensive copies.

---

## Phase 6: Screens

**Files:** `lib/app/screens/home_screen.dart`, `offline_lobby_screen.dart`, `matchmaking_screen.dart`, `game_screen.dart`

### 6.1 Consolidate button styles

Add `KoutTheme.primaryButtonStyle` and `KoutTheme.secondaryButtonStyle`. Both `home_screen.dart` and `offline_lobby_screen.dart` use these.

### 6.2 Fix offline_lobby_screen theme usage

Replace manual `TextStyle` construction with `KoutTheme.bodyStyle` (add to KoutTheme if missing).

### 6.3 Deduplicate geometric overlay painter

Replace local `_GeometricOverlayPainter` in `offline_lobby_screen.dart` with shared `GeometricPatterns` call.

### 6.4 No changes to game_screen.dart or matchmaking_screen.dart

Thin wrappers, fine as-is.

---

## Testing Strategy

Each phase must pass `flutter test` and `flutter analyze` before proceeding to the next. Phases that change game logic (1, 5) require running existing tests plus adding targeted tests for the specific fixes (Kout rule, poison joker naming, bid validation errors).

## Out of Scope

- New features or gameplay changes
- Online/WebSocket layer changes
- Worker (TypeScript) changes
- 6-player mode
- Sound/animation additions
