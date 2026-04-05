# Landscape Avatar-Based Layout

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the lightweight text-label landscape UI with full avatar-based player representation matching the reference — blue tile background, 3D perspective table, circular avatars with team rings, card fans beside each player.

**Architecture:** The portrait-mode components (PlayerSeat, OpponentHandFan, PerspectiveTable) already render everything needed. The fix is to stop hiding them in landscape and adapt their positions. LayoutManager gets landscape table vertices. ComponentLifecycleManager keeps all components mounted regardless of orientation. OpponentNameLabel is no longer created in landscape since PlayerSeat handles player identity.

**Tech Stack:** Flutter/Flame (Dart), custom Canvas rendering. No new files or dependencies.

---

## Issue-to-Task Map

| Gap vs Reference | Root Cause | Task |
|---|---|---|
| Green felt background in landscape | `table_background.dart` switches to radial gradient for landscape | Task 2 |
| No 3D table surface in landscape | `PerspectiveTableComponent` hidden via `_toggleVisibility` | Task 3 |
| No avatars/rings in landscape | `PlayerSeatComponent` hidden in landscape, replaced by text labels | Task 3 |
| No card fans in landscape | `OpponentHandFan` hidden in landscape | Task 3 |
| Text-only player labels | `OpponentNameLabel` used instead of `PlayerSeat` | Task 3 |
| Floating owner dots on trick cards | `_OwnerDotComponent` added — redundant when table provides spatial context | Task 4 |
| HUD green-tinted bg clashes with blue tiles | `hudBgLandscape` is green-tinted (0xDD1A2E1F) | Task 2 |
| Table surface gray-green | `tableSurfaceCenter/Edge` have green tint | Task 2 |

---

## File Structure

Files modified (no new files created):

```
lib/game/
├── managers/
│   ├── layout_manager.dart                 — Task 1: landscape table vertices, seat positions
│   └── component_lifecycle_manager.dart    — Task 3: always-visible seats/fans, drop labels
├── components/
│   ├── table_background.dart               — Task 2: tiles in landscape
│   └── trick_area.dart                     — Task 4: remove owner dots
├── theme/
│   └── diwaniya_colors.dart                — Task 2: neutral table surface, blue HUD palette
└── kout_game.dart                          — Task 3: always mount table
test/game/
└── hand_spacing_test.dart                  — Task 6: update landscape expectations
```

---

### Task 1: Landscape Table Vertices and Seat Positions

**Why:** LayoutManager has portrait-only table geometry. Landscape seat positions (designed for text labels) are too close to edges for 96x120 PlayerSeat components. Needs landscape table shape and avatar-compatible positions.

**Files:**
- Modify: `lib/game/managers/layout_manager.dart`

- [ ] **Step 1: Make `tableVertices` orientation-aware**

Replace the `tableVertices` getter (lines 151-160) with a dispatch that keeps portrait unchanged and adds landscape:

```dart
List<Offset> get tableVertices =>
    isLandscape ? _landscapeTableVertices : _portraitTableVertices;

List<Offset> get _portraitTableVertices {
  final topHalf = width * _tableTopWidthRatio / 2;
  final botHalf = width * _tableBottomWidthRatio / 2;
  final cx = width / 2;
  return [
    Offset(cx - topHalf, _tableTopY),
    Offset(cx + topHalf, _tableTopY),
    Offset(cx - botHalf, _tableBottomY),
    Offset(cx + botHalf, _tableBottomY),
  ];
}

List<Offset> get _landscapeTableVertices {
  final playTop = safeRect.top + safeRect.height * 0.20;
  final playBot = safeRect.bottom - safeRect.height * 0.32;
  final cx = safeRect.center.dx;
  final topHalf = safeRect.width * 0.22;
  final botHalf = safeRect.width * 0.30;
  return [
    Offset(cx - topHalf, playTop),
    Offset(cx + topHalf, playTop),
    Offset(cx - botHalf, playBot),
    Offset(cx + botHalf, playBot),
  ];
}
```

- [ ] **Step 2: Replace landscape seat positions for avatars**

Replace the four landscape seat getters (lines 101-131). Positions give PlayerSeat (96x120, center-anchored) room at screen edges:

```dart
/// Partner: top-center, above table
Vector2 get _landscapePartnerSeat => Vector2(
      safeRect.center.dx,
      safeRect.top + safeRect.height * 0.14,
    );

/// Left opponent: left side, mid-height
Vector2 get _landscapeLeftSeat => Vector2(
      safeRect.left + safeRect.width * 0.09,
      safeRect.top + safeRect.height * 0.44,
    );

/// Right opponent: right side, mid-height (further from edge than mySeat to avoid HUD overlap)
Vector2 get _landscapeRightSeat => Vector2(
      safeRect.right - safeRect.width * 0.12,
      safeRect.top + safeRect.height * 0.44,
    );

/// Human player: bottom-right, to the right of hand cards
Vector2 get _landscapeMySeat => Vector2(
      safeRect.right - safeRect.width * 0.07,
      safeRect.bottom - safeRect.height * 0.18,
    );
```

- [ ] **Step 3: Use table centroid for landscape trick center**

Replace `_landscapeTrickCenter` (lines 133-139) — trick cards should land on the table surface:

```dart
Vector2 get _landscapeTrickCenter {
  final tc = tableCenter;
  return Vector2(tc.dx, tc.dy);
}
```

- [ ] **Step 4: Remove unused zone constants**

Remove `_topZoneHeight`, `_handZoneHeight`, `_sideZoneWidth` (lines 20-22) — no longer referenced after seat position changes. Keep `_handBleedRatio` (still used by `_landscapeHandCenter`).

- [ ] **Step 5: Commit**

```bash
git add lib/game/managers/layout_manager.dart
git commit -m "feat: landscape table vertices and avatar-sized seat positions"
```

---

### Task 2: Blue Tile Background + Color Palette

**Why:** Reference uses blue tile texture everywhere. Our landscape uses green felt. Table surface should be neutral gray, not gray-green. HUD bg should match blue tiles.

**Files:**
- Modify: `lib/game/components/table_background.dart`
- Modify: `lib/game/theme/diwaniya_colors.dart`

- [ ] **Step 1: Use tile texture in both orientations**

Replace `table_background.dart` render method (lines 18-36). Tiles everywhere, lighter vignette in landscape:

```dart
@override
void render(Canvas canvas) {
  final rect = Rect.fromLTWH(0, 0, size.x, size.y);
  TextureGenerator.drawTileTexture(canvas, rect);
  TextureGenerator.drawVignette(canvas, rect,
      intensity: isLandscape ? 0.35 : 0.5);
}
```

Remove the `import '../theme/diwaniya_colors.dart';` line (no longer needed — tile colors come from TextureGenerator).

- [ ] **Step 2: Update table surface colors to neutral gray**

In `diwaniya_colors.dart`, replace lines 12-13:

```dart
// Table surface (3D perspective trapezoid)
static const Color tableSurfaceCenter = Color(0xFF5A5A5A);  // neutral gray
static const Color tableSurfaceEdge = Color(0xFF3A3A3A);    // dark gray
```

- [ ] **Step 3: Update HUD landscape palette to match blue tiles**

In `diwaniya_colors.dart`, replace lines 39-40:

```dart
// HUD landscape — translucent dark that blends with blue tiles
static const Color hudBgLandscape = Color(0xDD1A2535);     // dark blue-tinted
static const Color hudBorderLandscape = Color(0xFF3A5A6E); // matching tile blue
```

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/table_background.dart lib/game/theme/diwaniya_colors.dart
git commit -m "feat: blue tiles in landscape, neutral gray table, blue HUD palette"
```

---

### Task 3: Always-Visible Seats, Fans, and Table

**Why:** The core change. Stop hiding PlayerSeat, OpponentHandFan, and PerspectiveTable in landscape. Remove OpponentNameLabel creation since seats handle player identity. Update fan positions on orientation change.

**Files:**
- Modify: `lib/game/managers/component_lifecycle_manager.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Simplify `updateLandscapeVisibility` — only toggle ambient decoration**

Replace lines 34-55:

```dart
bool updateLandscapeVisibility(bool landscape) {
  if (landscape == _isLandscape) return false;
  _isLandscape = landscape;

  // Only ambient decoration is portrait-only
  _toggleVisibility(ambientDecoration, showInPortrait: true);

  // Update table background
  final tableBg =
      game.children.whereType<TableBackgroundComponent>().firstOrNull;
  if (tableBg != null) {
    tableBg.isLandscape = landscape;
  }

  return true;
}
```

- [ ] **Step 2: Always mount seats and fans in `initSeats`**

Replace lines 58-113. Remove `if (!_isLandscape)` guards — always `game.add(...)`:

```dart
void initSeats(ClientGameState state, LayoutManager layout) {
  if (seats.isNotEmpty) return;

  for (int i = 0; i < 4; i++) {
    final pos = layout.seatPosition(i, state.mySeatIndex);
    final seat = PlayerSeatComponent(
      seatIndex: i,
      playerName: shortUid(state.playerUids[i]),
      cardCount: 0,
      isActive: false,
      team: teamForSeat(i),
      avatarSeed: i,
      position: pos,
    );
    seats.add(seat);
    game.add(seat);
  }

  ambientDecoration = AmbientDecorationComponent(
    seatPositions: [
      for (int i = 0; i < 4; i++) layout.seatPosition(i, state.mySeatIndex),
    ],
  );
  if (!_isLandscape) game.add(ambientDecoration!);

  for (int i = 0; i < 4; i++) {
    if (i == state.mySeatIndex) continue;
    final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
    final seatPos = layout.seatPosition(i, state.mySeatIndex);

    final double rotation;
    final Vector2 offset;
    switch (relativeSeat) {
      case 1:
        rotation = math.pi / 2;
        offset = _fanOffset(1);
      case 2:
        rotation = math.pi;
        offset = _fanOffset(2);
      case 3:
        rotation = -math.pi / 2;
        offset = _fanOffset(3);
      default:
        continue;
    }

    final fan = OpponentHandFan(
      cardCount: 8,
      position: seatPos + offset,
      baseRotation: rotation,
    );
    opponentFans[i] = fan;
    game.add(fan);
  }
}
```

- [ ] **Step 3: Add `_fanOffset` helper and update fan positions in `updateSeats`**

Add after `updateSeats`:

```dart
Vector2 _fanOffset(int relativeSeat) {
  const offset = 70.0;
  return switch (relativeSeat) {
    1 => Vector2(offset, -10),
    2 => Vector2(0, offset),
    3 => Vector2(-offset, -10),
    _ => Vector2.zero(),
  };
}
```

In `updateSeats`, after the existing fan card count update (line 135), add fan repositioning:

```dart
if (opponentFans.containsKey(i)) {
  opponentFans[i]!.updateCardCount(state.cardCounts[i] ?? 8);
  final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
  final seatPos = layout.seatPosition(i, state.mySeatIndex);
  opponentFans[i]!.position = seatPos + _fanOffset(relativeSeat);
}
```

- [ ] **Step 4: Simplify `updateLandscapeLabels` to only clean up**

Replace lines 141-203 — labels are no longer created, method just cleans up stragglers:

```dart
void updateLandscapeLabels(ClientGameState state, LayoutManager layout) {
  // Seats handle identity in all orientations — clean up any leftover labels
  for (final label in opponentLabels.values) {
    if (label.isMounted) label.removeFromParent();
  }
  opponentLabels.clear();
  if (playerLabel != null) {
    if (playerLabel!.isMounted) playerLabel!.removeFromParent();
    playerLabel = null;
  }
}
```

- [ ] **Step 5: Always mount perspective table in `kout_game.dart`**

In `onLoad()` (line 104-105), remove the landscape guard:

```dart
_lifecycle.perspectiveTable = PerspectiveTableComponent(layout: layout);
add(_lifecycle.perspectiveTable!);
```

- [ ] **Step 6: Commit**

```bash
git add lib/game/managers/component_lifecycle_manager.dart lib/game/kout_game.dart
git commit -m "feat: show seats, fans, table in all orientations"
```

---

### Task 4: Remove Trick Area Owner Dots

**Why:** The perspective table provides spatial context — cards are positioned by seat direction. Owner dots are redundant visual noise.

**Files:**
- Modify: `lib/game/components/trick_area.dart`

- [ ] **Step 1: Remove owner dot logic**

Remove `_ownerLabels` field (line 28), its cleanup in `updateState` (lines 58-62, 104-111), `_ownerDotPosition` method (lines 128-136), and the entire `_OwnerDotComponent` class (lines 142-158).

Remove now-unused imports:
```dart
// Remove these two imports:
import '../../shared/models/game_state.dart' show Team, teamForSeat;
import '../theme/kout_theme.dart';
```

The resulting `updateState` method:

```dart
void updateState(ClientGameState state) {
  for (final c in _trickCards) {
    c.removeFromParent();
  }
  _trickCards.clear();

  final activeUids = state.currentTrickPlays.map((p) => p.playerUid).toSet();
  _cachedJitter.removeWhere((uid, _) => !activeUids.contains(uid));

  for (int i = 0; i < state.currentTrickPlays.length; i++) {
    final play = state.currentTrickPlays[i];
    final absoluteSeat = state.playerUids.indexOf(play.playerUid);
    if (absoluteSeat < 0) continue;

    final relativeSeat = layout.toRelativeSeat(absoluteSeat, mySeatIndex);
    final basePos = layout.trickCardPosition(relativeSeat);
    final center = layout.trickCenter;
    final nudge = i * _nudgeFactor;
    final pos = basePos + (center - basePos) * nudge;

    final jitter = _cachedJitter.putIfAbsent(
      play.playerUid,
      () => (_random.nextDouble() - 0.5) * 0.10,
    );
    final angle = _seatBaseAngle(relativeSeat) + jitter;

    final trickScale = layout.trickCardScale;
    final cardComp = CardComponent(
      card: play.card,
      isFaceUp: true,
      isHighlighted: false,
      showShadow: true,
      restScale: trickScale,
      position: pos,
      angle: angle,
    )
      ..scale = Vector2.all(trickScale)
      ..priority = 10 + i;

    _trickCards.add(cardComp);
    add(cardComp);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/game/components/trick_area.dart
git commit -m "refactor: remove owner dots — table surface provides spatial context"
```

---

### Task 5: HUD Cleanup

**Why:** The `_isLandscape` field in `unified_hud.dart` was used to switch between green/blue HUD bg. Since `diwaniya_colors.dart` palette is now blue-tinted for landscape (Task 2), the field still works correctly. Verify no changes needed — the HUD already positions at top-left in landscape (correct, since top-right would overlap with right opponent seat).

**Files:**
- Verify: `lib/game/components/unified_hud.dart`

- [ ] **Step 1: Verify HUD renders correctly with blue palette**

No code changes needed — the HUD reads `DiwaniyaColors.hudBgLandscape` and `DiwaniyaColors.hudBorderLandscape` which were updated in Task 2. Top-left landscape positioning is correct (avoids right seat overlap).

---

### Task 6: Update Tests and Verify

**Why:** Layout constant changes affect test expectations in `hand_spacing_test.dart`.

**Files:**
- Modify: `test/game/hand_spacing_test.dart`

- [ ] **Step 1: Update landscape seat position tests**

Replace the three seat position tests (lines 94-115) with expectations matching the new proportional positions:

```dart
test('left seat is on left side at mid-height', () {
  final ls = landscapeLayout.leftSeat;
  expect(ls.x, closeTo(landscapeLayout.safeRect.left + landscapeLayout.safeRect.width * 0.09, 1));
  expect(ls.y, closeTo(landscapeLayout.safeRect.top + landscapeLayout.safeRect.height * 0.44, 1));
});

test('right seat is on right side at mid-height', () {
  final rs = landscapeLayout.rightSeat;
  expect(rs.x, closeTo(landscapeLayout.safeRect.right - landscapeLayout.safeRect.width * 0.12, 1));
  expect(rs.y, closeTo(landscapeLayout.safeRect.top + landscapeLayout.safeRect.height * 0.44, 1));
});

test('partner seat is at top center', () {
  final ps = landscapeLayout.partnerSeat;
  expect(ps.x, closeTo(landscapeLayout.safeRect.center.dx, 1));
  expect(ps.y, closeTo(landscapeLayout.safeRect.top + landscapeLayout.safeRect.height * 0.14, 1));
});
```

- [ ] **Step 2: Run the test file**

```bash
flutter test test/game/hand_spacing_test.dart
```

Expected: All 20 tests pass.

- [ ] **Step 3: Run full test suite + analyze**

```bash
flutter test
flutter analyze
```

Expected: All tests pass (359+), no analysis issues.

- [ ] **Step 4: Commit**

```bash
git add test/game/hand_spacing_test.dart
git commit -m "test: update landscape seat expectations for avatar layout"
```
