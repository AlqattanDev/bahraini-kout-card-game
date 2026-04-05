# Landscape UI Fixes — Design Spec

**Goal:** Fix 10 UI/UX issues identified in iPhone landscape mode and match reference production app layout.

**Architecture:** Modify LayoutManager landscape positions, fix stale layout references, adjust card fan parameters, compact overlays, update OpponentNameLabel for side placement.

**Tech Stack:** Flutter/Flame (Dart), no new dependencies.

---

## 1. Fix Stale Layout Reference (Root Cause Bug)

`HandComponent` and `TrickAreaComponent` store `final LayoutManager layout` at construction time. When `updateSafeArea` or `onGameResize` creates a new LayoutManager, these components still read from the old one — causing cards to render at portrait scale (1.4x) instead of landscape (0.6x).

**Fix:** Change `layout` from `final` to a mutable field in `HandComponent` and `TrickAreaComponent`. Add an `updateLayout(LayoutManager)` method to each. Call it from `KoutGame.updateSafeArea()` and `KoutGame.onGameResize()`.

**Files:** `lib/game/components/hand_component.dart`, `lib/game/components/trick_area.dart`, `lib/game/kout_game.dart`

---

## 2. Reposition Opponents to Sides

Move opponents from all-at-top to match reference app spatial layout:

```
┌──────────────────────────────────────────────────┐
│notch│                                     [HUD] │
│     │              [partner]               score │
│     │               label                        │
│     │                                            │
│     │ [left]    ┌────────────────┐     [right]   │
│     │ opponent  │  trick area    │    opponent   │
│     │           └────────────────┘               │
│     │                                            │
│     │          ═══card fan═══          [You]     │
└──────────────────────────────────────────────────┘
```

Update `LayoutManager` landscape getters:

- **Partner**: `(safeRect.centerX, safeRect.top + 25)` — top center
- **Left opponent**: `(safeRect.left + 80, safeRect.centerY)` — left side, vertically centered
- **Right opponent**: `(safeRect.right - 80, safeRect.centerY)` — right side, vertically centered
- **Trick center**: `(safeRect.centerX, safeRect.centerY - 15)` — true center
- **Trick tracker**: `(trickCenter.x, trickCenter.y + 60)` — below trick area (tighter in landscape)
- **Player seat (mySeat)**: `(safeRect.right - 50, safeRect.bottom - 25)` — bottom right

All positions use safeRect so they automatically dodge the notch on either side.

**Files:** `lib/game/managers/layout_manager.dart`, `test/game/hand_spacing_test.dart`

---

## 3. Card Fan — Bottom Edge, Tighter Spacing

Cards should extend past the bottom screen edge with no gap, matching the reference app.

Update `LayoutManager`:

- **handCenter Y**: `screenHeight + 15` — pushes fan center below screen so bottom ~30% of cards is off-screen
- **handCardScale**: `(safeRect.height * 0.22 / 100).clamp(0.75, 1.4)` — targets ~0.82 on iPhone 15 Pro instead of 0.6. Cards readable but smaller than portrait.
- **Card spacing**: Reduce landscape clamp from `[32, 52]` to `[24, 40]` — tighter overlap
- **Arc bow**: Keep at 20 (subtle curve)

**Files:** `lib/game/managers/layout_manager.dart`

---

## 4. Compact Overlays for Landscape

Overlays (bid, trump, round result) take too much vertical space in landscape.

In `OverlayAnimationWrapper.build()`, detect landscape via `MediaQuery.orientation` and wrap the child in a `Transform.scale(scale: 0.75)` when landscape. This uniformly shrinks all overlays without modifying each overlay individually.

**Files:** `lib/game/overlays/overlay_animation_wrapper.dart`

---

## 5. Opponent Labels for Side Placement

Current `OpponentNameLabel` is designed for top placement (anchor: topCenter, vertical layout). For side-placed opponents, add a `placement` parameter:

- `OpponentLabelPlacement.top` (partner) — anchor topCenter, name above fan (current behavior)
- `OpponentLabelPlacement.left` — anchor centerRight, compact layout (name + small fan side by side or stacked)
- `OpponentLabelPlacement.right` — anchor centerLeft, mirror of left

The `_updateLandscapeLabels` method in KoutGame determines placement based on relativeSeat:
- relativeSeat 1 (left) → `placement: left`
- relativeSeat 2 (partner) → `placement: top`
- relativeSeat 3 (right) → `placement: right`

**Files:** `lib/game/components/opponent_name_label.dart`, `lib/game/kout_game.dart`

---

## 6. Player "You" Label

Add a minimal label at bottom-right showing the player's name and team color dot. Rendered as a simple Flame `TextComponent` or lightweight custom component in KoutGame, only in landscape mode. No card fan needed (player sees their own hand).

Managed alongside opponent labels in `_updateLandscapeLabels` — created when landscape, removed when portrait.

**Files:** `lib/game/kout_game.dart`

---

## 7. HUD Positioning (Cleanup)

With opponents moved to sides, the HUD at top-right no longer conflicts. Keep current `updateLayout` logic but ensure it's called correctly when layout changes (fixed by the stale layout fix in section 1). Remove the per-frame HUD repositioning from `_updateScoreDisplay` and move it to `updateSafeArea`/`onGameResize` instead.

**Files:** `lib/game/kout_game.dart`, `lib/game/components/unified_hud.dart`

---

## Landscape Test Updates

Update `test/game/hand_spacing_test.dart`:
- Fix landscape position expectations for new side-based layout
- Add test: handCenter Y is below screen height (cards extend past edge)
- Add test: left/right seats are vertically centered in safeRect
- Add test: partner is at top center of safeRect
- Verify portrait tests still pass unchanged

**Files:** `test/game/hand_spacing_test.dart`
