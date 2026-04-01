# Plan: Opponent Card Fan UI Overhaul

**Date:** 2026-04-01
**Status:** Ready to execute
**Branch:** `feat/opponent-card-fan-ui`

## Objective

Upgrade the opponent card-back fan rendering from minimal placeholders to a polished, game-quality appearance matching commercial Kout apps (reference: Kout Kuwait screenshot). The current implementation uses tiny 27x38px flat rectangles with a single gold diamond. The target is large, clearly fanned cards with detailed card-back art and natural arc positioning.

---

## Reference Comparison

| Aspect | Current | Target |
|---|---|---|
| Card size | 38% of 70x100 = 27x38px | ~55% = 38x55px |
| Fan spread | 0.25 rad, 8px overlap — looks like a clump | 0.6 rad, 14px overlap — visible arc |
| Card back art | Flat green fill + tiny gold diamond | Full `CardPainter.paintBack()` pattern (star tessellation + gold inner border) |
| Arc curvature | `(t²) * 6` — imperceptible | `(t²) * 16` — clear bow |
| Shadow | 1px offset, blur 2 | 2px offset, blur 3 — more depth |
| Orientation | Cards shift horizontally only | Cards radiate from avatar toward table center |
| Border | 0.8px white stroke — invisible at scale | 1.2px white stroke — visible edge per card |
| Card count readability | Cards merge into blob | Individual card edges distinguishable |

---

## Files to Change

### Primary (implementation)
1. **`lib/game/components/opponent_hand_fan.dart`** — Main rewrite. All rendering changes happen here.
2. **`lib/game/kout_game.dart`** — Adjust fan offset vectors (lines 207-217) to accommodate larger fan size.

### Supporting (may need minor tweaks)
3. **`lib/game/managers/layout_manager.dart`** — Possibly adjust seat positions if larger fans overlap trick area. Evaluate after visual test.
4. **`lib/game/theme/kout_theme.dart`** — Add `opponentCardScale` constant if we want it configurable.

### Tests
5. **`test/game/opponent_hand_fan_test.dart`** — Update if constructor signature changes (e.g., new parameters).

---

## Implementation Steps

### Step 1: Update OpponentHandFan constants and constructor

**File:** `opponent_hand_fan.dart`

Change these constants:
```dart
// Before
static const double _miniWidth = KoutTheme.cardWidth * 0.38;   // 26.6
static const double _miniHeight = KoutTheme.cardHeight * 0.38; // 38
static const double _cardOverlap = 8.0;
static const double _maxFanAngle = 0.25;

// After
static const double _miniWidth = KoutTheme.cardWidth * 0.55;   // 38.5
static const double _miniHeight = KoutTheme.cardHeight * 0.55; // 55
static const double _cardOverlap = 14.0;
static const double _maxFanAngle = 0.55;
```

Update the component `size` in the constructor to accommodate the wider spread:
```dart
super(size: Vector2(_miniWidth + _cardOverlap * 10, _miniHeight + 30));
```

### Step 2: Improve card-back rendering in the render loop

**File:** `opponent_hand_fan.dart`, inside `render()`

Replace the current flat fill + diamond ornament with a scaled-down version of `CardPainter.paintBack()`. Two options:

**Option A (preferred):** Call `CardPainter.paintBack()` directly with scaled canvas:
```dart
canvas.save();
canvas.scale(_miniWidth / KoutTheme.cardWidth, _miniHeight / KoutTheme.cardHeight);
CardPainter.paintBack(canvas, scaledRect);
canvas.restore();
```

This reuses all the existing card-back art (geometric star pattern, gold inner border, white outer border) without duplication. The star tessellation from `GeometricPatterns.drawCardBackPattern()` already adapts to any rect size.

**Option B (fallback):** If `CardPainter.paintBack()` looks too busy at small scale, keep a simplified version but with:
- Gradient fill instead of flat color
- 2-3 concentric rounded rects for border depth
- Larger centered ornament (diamond → 8-point star)

### Step 3: Increase arc curvature and shadow depth

**File:** `opponent_hand_fan.dart`, inside `render()`

```dart
// Arc curvature: was (t * t) * 6, change to 16
dy = (t * t) * 16;  // for right/left
dy = -(t * t) * 16; // for above

// Shadow: increase offset and blur
final shadowRect = rect.shift(const Offset(1.5, 2.5));  // was (1, 1.5)
// blur: 3 instead of 2
..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
```

### Step 4: Improve card border visibility

**File:** `opponent_hand_fan.dart`, inside `render()`

```dart
// White stroke: was 0.8, change to 1.2
..strokeWidth = 1.2,
```

### Step 5: Adjust fan offsets in KoutGame

**File:** `kout_game.dart`, lines 207-217

The larger fan needs more clearance from the seat circle to avoid overlapping:
```dart
case 1: // left opponent
  dir = FanDirection.right;
  offset = Vector2(65, -15);   // was (50, -10)
case 2: // top (partner)
  dir = FanDirection.above;
  offset = Vector2(0, -60);    // was (0, -50)
case 3: // right opponent
  dir = FanDirection.left;
  offset = Vector2(-65, -15);  // was (-50, -10)
```

These values need visual tuning after the fan size change. The key constraint is: fans must not overlap the trick area center circle.

### Step 6: Update tests

**File:** `test/game/opponent_hand_fan_test.dart`

Current tests only check `cardCount` storage and `FanDirection` enum — these won't break from rendering changes. Add a test to verify the new size calculation:

```dart
test('OpponentHandFan component size accommodates full fan spread', () {
  final fan = OpponentHandFan(
    cardCount: 8,
    position: Vector2.zero(),
    fanDirection: FanDirection.right,
  );
  // size.x should fit 8 cards with overlap + card width
  expect(fan.size.x, greaterThan(100));
  expect(fan.size.y, greaterThan(50));
});
```

### Step 7: Visual verification

Run the game on macOS (`flutter run -d macos`) and verify:
- [ ] Cards are individually distinguishable at 8-card count
- [ ] Fan arc looks natural, not flat
- [ ] Card-back pattern is visible but not cluttered
- [ ] Fans don't overlap trick area or score display
- [ ] Fans update correctly as cards are played (count decreases, fan shrinks)
- [ ] Performance is acceptable (8 cards × 3 opponents = 24 mini card paints per frame)

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| `CardPainter.paintBack()` too detailed at 38x55px | Medium | Use Option B simplified version |
| Larger fans overlap trick area on small screens | Medium | Test at 800x600 minimum, adjust offsets |
| Performance regression from 24× geometric pattern draws | Low | Pattern is simple path ops, profile if needed |
| Fan looks wrong when card count drops to 1-2 | Low | Test edge cases visually |

---

## Out of Scope

- Player avatar/portrait rendering (separate task)
- Card count badge/number overlay on opponent (nice-to-have, separate PR)
- Opponent hand animations (deal-in, card play fly-out)
- 6-player layout adjustments
