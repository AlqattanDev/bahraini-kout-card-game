# Card Presentation Enhancement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade card rendering from procedural text-on-rectangles to visually rich, high-contrast cards with drop shadows, proper face card decoration, bold corner indices, dramatic joker, and natural table placement — matching or exceeding the reference Kout app's card presentation.

**Architecture:** Enhance the existing procedural `CardPainter` with high-contrast colors, larger typography, drop shadows, face card accents, and a custom joker starburst. Add opponent card-back fans as a new component. No sprite sheets needed for this phase — all procedural improvements.

**Tech Stack:** Dart/Flutter, Flame 1.17, Canvas API, `dart:ui` for shadow painting

**Task ordering:** Tasks MUST be completed in order: 1 → 2 → 3 → 4 → 5 → 6 → 7. Task 2+ depend on constants from Task 1. Task 4 depends on `showShadow` from Task 2. Task 6 depends on `cardCounts` from Task 5.

**Prerequisites verified:**
- `IBMPlexMono` font is registered in `pubspec.yaml` (lines 70-74) with Regular + Bold weights — safe to use in card rendering.
- `GeometricPatterns.drawCardBackPattern(canvas, rect)` exists in `geometric_patterns.dart` line 93 and accepts a `Rect` — card back rendering is compatible.
- `KoutTheme.cardBorder` is only used in `card_painter.dart` paintFace (line 85) — changing it from green to dark gray won't break any other component. The highlight border in `card_component.dart` uses `KoutTheme.accent`, not `cardBorder`.

**4-player mode only:** This plan targets 4-player mode. Opponent fan directions and seat positions will need extension for 6-player mode.

**Reference comparison (from analysis of competing Kout app):**

| Attribute | Reference App | Our Current | Gap |
|-----------|--------------|-------------|-----|
| Face card art | Full illustrated portraits | Text "K"/"Q"/"J" + Unicode suit | High |
| Corner indices | ~16pt bold, high contrast | 11pt serif, low contrast | High |
| Card background | Pure white, thin dark border | Ivory `#FFFFF0`, green border `#738C5A` | Medium |
| Drop shadows | All cards have shadows | No shadows except during animation flight | High |
| Joker design | Black starburst, dramatic | Purple star "★" + "JO" text | Medium |
| Trick card rotation | Random slight angles, natural | Fixed per-seat angles only | Medium |
| Opponent hand display | Fanned card backs behind avatar | Hardcoded "8 cards" text | High |
| Inter-card depth | Shadows between overlapping hand cards | Flat, no depth | Medium |

---

## File Structure

```
lib/
├── app/models/
│   └── client_game_state.dart     # MODIFY: add cardCounts field (Map<int, int>)
├── offline/
│   └── local_game_controller.dart # MODIFY: populate cardCounts in _toClientState
├── game/
│   ├── theme/
│   │   ├── kout_theme.dart        # MODIFY: add card color/size constants
│   │   └── card_painter.dart      # MODIFY: rewrite paintFace, add paintJoker
│   ├── components/
│   │   ├── card_component.dart    # MODIFY: add showShadow param + shadow rendering
│   │   ├── trick_area.dart        # MODIFY: add random rotation jitter + showShadow
│   │   ├── hand_component.dart    # MODIFY: enable showShadow + z-ordering
│   │   ├── opponent_hand_fan.dart # CREATE: fanned card-back display for opponents
│   │   └── player_seat.dart       # (no changes — fan is a separate component)
│   └── kout_game.dart             # MODIFY: create/update OpponentHandFan instances
test/
└── game/
    ├── kout_theme_test.dart       # CREATE
    ├── card_shadow_test.dart      # CREATE
    ├── card_painter_test.dart     # CREATE
    └── opponent_hand_fan_test.dart # CREATE
```

---

### Task 1: Card Color & Typography Constants

**Files:**
- Modify: `lib/game/theme/kout_theme.dart`
- Create: `test/game/kout_theme_test.dart`

**Context:** Current `kout_theme.dart` has `cardFace = Color(0xFFFFFFF0)` (ivory), `cardBorder = Color(0xFF738C5A)` (green/gold), and no font size constants for card rendering. The `cardBorder` constant is used in `card_painter.dart` line 85 (`paintFace` outer border) and in `card_component.dart` line 73 (highlight overlay — but that uses `KoutTheme.accent`, not `cardBorder`). Safe to change `cardBorder` without breaking highlight.

- [ ] **Step 1: Write failing test**

```dart
// test/game/kout_theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/game/theme/kout_theme.dart';

void main() {
  group('card presentation constants', () {
    test('card face is pure white', () {
      expect(KoutTheme.cardFace.value, 0xFFFFFFFF);
    });

    test('card border is dark gray', () {
      expect(KoutTheme.cardBorder.value, 0xFF2A2A2A);
    });

    test('card corner rank size exists and is 16', () {
      expect(KoutTheme.cardCornerRankSize, 16.0);
    });

    test('card corner suit size exists and is 14', () {
      expect(KoutTheme.cardCornerSuitSize, 14.0);
    });

    test('card center suit size exists and is 32', () {
      expect(KoutTheme.cardCenterSuitSize, 32.0);
    });

    test('card shadow constants exist', () {
      expect(KoutTheme.cardShadowBlur, 4.0);
      expect(KoutTheme.cardShadowOffsetX, 2.0);
      expect(KoutTheme.cardShadowOffsetY, 3.0);
      expect(KoutTheme.cardShadowColor.alpha, greaterThan(0));
    });

    test('joker color exists', () {
      expect(KoutTheme.jokerColor.value, 0xFF1A1A1A);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/kout_theme_test.dart`
Expected: FAIL — new constants don't exist, `cardFace` and `cardBorder` have old values

- [ ] **Step 3: Update kout_theme.dart**

In `lib/game/theme/kout_theme.dart`, change existing constants and add new ones:

```dart
// CHANGE these existing values:
static const Color cardFace = Color(0xFFFFFFFF);    // was 0xFFFFFFF0 (ivory)
static const Color cardBorder = Color(0xFF2A2A2A);  // was 0xFF738C5A (green/gold)

// ADD these new constants after the existing card constants:
static const Color jokerColor = Color(0xFF1A1A1A);

// Card typography (was hardcoded 11/10/28 in card_painter.dart)
static const double cardCornerRankSize = 16.0;
static const double cardCornerSuitSize = 14.0;
static const double cardCenterSuitSize = 32.0;

// Drop shadow
static const double cardShadowBlur = 4.0;
static const double cardShadowOffsetX = 2.0;
static const double cardShadowOffsetY = 3.0;
static const Color cardShadowColor = Color(0x66000000); // 40% black
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/game/kout_theme_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/game/theme/kout_theme.dart test/game/kout_theme_test.dart
git commit -m "feat(theme): update card color/typography constants for high-contrast rendering"
```

---

### Task 2: Drop Shadow Support in CardComponent

**Files:**
- Modify: `lib/game/components/card_component.dart`
- Create: `test/game/card_shadow_test.dart`

**Context:** Current `card_component.dart` has no shadow rendering. The `render()` method (line 41) draws the card rect directly. Shadow must be drawn BEFORE the card face/back so it appears behind the card, not on top. The shadow offset `(2, 3)` ensures it's visible below and to the right.

- [ ] **Step 1: Write failing test**

```dart
// test/game/card_shadow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/game/components/card_component.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/enums.dart';

void main() {
  test('CardComponent has showShadow property defaulting to true', () {
    final card = CardComponent(
      card: GameCard(suit: Suit.spades, rank: Rank.ace),
      isFaceUp: true,
    );
    expect(card.showShadow, true);
  });

  test('CardComponent showShadow can be set to false', () {
    final card = CardComponent(
      card: GameCard(suit: Suit.spades, rank: Rank.ace),
      isFaceUp: true,
      showShadow: false,
    );
    expect(card.showShadow, false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/card_shadow_test.dart`
Expected: FAIL — `showShadow` parameter doesn't exist

- [ ] **Step 3: Add shadow to CardComponent**

In `lib/game/components/card_component.dart`:

1. Add field and constructor parameter:

```dart
bool showShadow; // Add after isDimmed field (line 16)
```

In constructor parameters (after `this.isDimmed = false,`):
```dart
this.showShadow = true,
```

2. Replace the `render` method (lines 41-52) with:

```dart
@override
void render(Canvas canvas) {
  final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
  final rrect = RRect.fromRectAndRadius(
    rect,
    const Radius.circular(KoutTheme.cardBorderRadius),
  );

  // Drop shadow — drawn FIRST so it's behind the card
  if (showShadow) {
    final shadowRect = rrect.shift(
      Offset(KoutTheme.cardShadowOffsetX, KoutTheme.cardShadowOffsetY),
    );
    final shadowPaint = Paint()
      ..color = KoutTheme.cardShadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, KoutTheme.cardShadowBlur);
    canvas.drawRRect(shadowRect, shadowPaint);
  }

  if (isFaceUp && card != null) {
    _renderFaceUp(canvas, rect, rrect);
  } else {
    CardPainter.paintBack(canvas, rect);
  }
}
```

Note: The shadow works here because both `CardPainter.paintFace()` and `CardPainter.paintBack()` fill the card rect with opaque paint, fully covering the shadow underneath. The shadow is only visible where it extends beyond the card edges (offset by 2px right, 3px down). This is correct behavior — don't "fix" it if face-down cards seem to not show shadows, they do show at the edges.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/game/card_shadow_test.dart`
Expected: PASS

- [ ] **Step 5: Run full test suite to verify no regressions**

Run: `flutter test`
Expected: PASS — existing `CardComponent` usages don't pass `showShadow` so they get the default `true`

- [ ] **Step 6: Commit**

```bash
git add lib/game/components/card_component.dart test/game/card_shadow_test.dart
git commit -m "feat(cards): add drop shadow rendering to CardComponent"
```

---

### Task 3: Rewrite CardPainter for High-Contrast Faces + Custom Joker

**Files:**
- Modify: `lib/game/theme/card_painter.dart`
- Modify: `lib/game/components/card_component.dart` (joker render path)
- Create: `test/game/card_painter_test.dart`

**Context:** Current `card_painter.dart` uses:
- Hardcoded `11` for rank font size (line 88), `10` for suit (line 91), `28` for center (line 109)
- Font family `'serif'` (line 132)
- No face card decoration — K/Q/J look identical to pip cards
- Joker rendered via `paintFace(canvas, rect, 'JO', '★', Color(0xFF800080))` in `card_component.dart` line 60

`GeometricPatterns.drawCardBackPattern(canvas, rect)` at line 36 exists and accepts a `Rect` — no changes needed for card back.

- [ ] **Step 1: Write failing test**

```dart
// test/game/card_painter_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/game/theme/card_painter.dart';
import 'package:bahraini_kout/game/theme/kout_theme.dart';

void main() {
  test('paintFace renders without error for pip card', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintFace(canvas, rect, '7', '♠', const Color(0xFF111111));
    recorder.endRecording();
  });

  test('paintFace renders without error for face card', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintFace(canvas, rect, 'K', '♠', const Color(0xFF111111));
    recorder.endRecording();
  });

  test('paintJoker static method exists and renders without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintJoker(canvas, rect);
    recorder.endRecording();
  });

  test('paintBack still renders without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintBack(canvas, rect);
    recorder.endRecording();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/card_painter_test.dart`
Expected: FAIL — `paintJoker` doesn't exist

- [ ] **Step 3: Rewrite card_painter.dart**

Replace the entire content of `lib/game/theme/card_painter.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'geometric_patterns.dart';
import 'kout_theme.dart';

/// High-contrast card rendering with bold corner indices and custom joker.
///
/// Changes from original:
/// - Font: IBMPlexMono (monospace, consistent widths) instead of serif
/// - Corner rank: 16pt (was 11pt), corner suit: 14pt (was 10pt)
/// - Center suit: 32pt (was 28pt)
/// - Card face: pure white (was ivory), border: dark gray (was green/gold)
/// - Face cards (K/Q/J): decorative inner frame accent
/// - Joker: black starburst with "JOKER" / "خلو" text
class CardPainter {
  // ---------------------------------------------------------------------------
  // Card back — unchanged
  // ---------------------------------------------------------------------------

  static void paintBack(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    final outerBorderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, outerBorderPaint);

    final bgPaint = Paint()..color = KoutTheme.cardBack;
    canvas.drawRRect(rrect, bgPaint);

    GeometricPatterns.drawCardBackPattern(canvas, rect);

    final innerRect = Rect.fromLTRB(
      rect.left + 4, rect.top + 4, rect.right - 4, rect.bottom - 4,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(KoutTheme.cardBorderRadius - 1),
    );
    final goldBorderPaint = Paint()
      ..color = KoutTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(innerRRect, goldBorderPaint);
  }

  // ---------------------------------------------------------------------------
  // Card face — high-contrast rewrite
  // ---------------------------------------------------------------------------

  static void paintFace(
    Canvas canvas,
    Rect rect,
    String rankStr,
    String suitSymbol,
    Color suitColor,
  ) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    // Pure white face fill
    canvas.drawRRect(rrect, Paint()..color = KoutTheme.cardFace);

    // Thin dark border (was thick green/gold)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = KoutTheme.cardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Top-left corner: rank (large, bold)
    _drawCardText(
      canvas, rankStr, suitColor,
      Offset(rect.left + 6, rect.top + 5),
      KoutTheme.cardCornerRankSize,
      align: TextAlign.left, width: 30,
    );
    // Top-left corner: suit below rank
    _drawCardText(
      canvas, suitSymbol, suitColor,
      Offset(rect.left + 6, rect.top + 5 + KoutTheme.cardCornerRankSize),
      KoutTheme.cardCornerSuitSize,
      align: TextAlign.left, width: 30,
    );

    // Bottom-right corner (rotated 180°)
    canvas.save();
    canvas.translate(rect.right, rect.bottom);
    canvas.rotate(math.pi);
    _drawCardText(
      canvas, rankStr, suitColor,
      const Offset(6, 5),
      KoutTheme.cardCornerRankSize,
      align: TextAlign.left, width: 30,
    );
    _drawCardText(
      canvas, suitSymbol, suitColor,
      Offset(6, 5 + KoutTheme.cardCornerRankSize),
      KoutTheme.cardCornerSuitSize,
      align: TextAlign.left, width: 30,
    );
    canvas.restore();

    // Large center suit symbol
    _drawCardText(
      canvas, suitSymbol, suitColor,
      Offset(rect.left + rect.width / 2, rect.top + rect.height / 2 - 4),
      KoutTheme.cardCenterSuitSize,
      align: TextAlign.center, width: rect.width,
    );

    // Face card accent frame (K, Q, J only)
    if (rankStr == 'K' || rankStr == 'Q' || rankStr == 'J') {
      _drawFaceCardAccent(canvas, rect, suitColor);
    }
  }

  /// Decorative inner frame on face cards to distinguish from pip cards.
  static void _drawFaceCardAccent(Canvas canvas, Rect rect, Color suitColor) {
    final innerRect = Rect.fromLTRB(
      rect.left + 14, rect.top + 30, rect.right - 14, rect.bottom - 30,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..color = suitColor.withOpacity(0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..color = suitColor.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  // Joker — dramatic starburst design
  // ---------------------------------------------------------------------------

  static void paintJoker(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    // White face
    canvas.drawRRect(rrect, Paint()..color = KoutTheme.cardFace);

    // Dark border (slightly thicker for joker emphasis)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = KoutTheme.jokerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final cx = rect.left + rect.width / 2;
    final cy = rect.top + rect.height / 2;

    // 12-point starburst shape (absolute px — sized for 70x100 card)
    // Note: OpponentHandFan renders mini card backs without faces, so
    // the joker starburst won't appear in mini fans — that's fine.
    final starPath = Path();
    const points = 12;
    const outerRadius = 22.0;
    const innerRadius = 11.0;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    // Black fill
    canvas.drawPath(starPath, Paint()..color = KoutTheme.jokerColor);

    // White inner circle for contrast
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()..color = KoutTheme.cardFace,
    );

    // "JOKER" text above starburst
    _drawCardText(
      canvas, 'JOKER', KoutTheme.jokerColor,
      Offset(cx, rect.top + 10),
      8,
      align: TextAlign.center, width: rect.width,
    );

    // "خلو" text below starburst (Khallou)
    _drawCardText(
      canvas, 'خلو', KoutTheme.jokerColor,
      Offset(cx, rect.bottom - 22),
      10,
      align: TextAlign.center, width: rect.width,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static void _drawCardText(
    Canvas canvas,
    String text,
    Color color,
    Offset offset,
    double fontSize, {
    required TextAlign align,
    required double width,
  }) {
    final builder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: align,
        fontSize: fontSize,
        fontFamily: 'IBMPlexMono',
      ),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: width));

    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx = offset.dx - paragraph.maxIntrinsicWidth / 2;
    }
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
  }
}
```

- [ ] **Step 4: Update CardComponent joker render path**

In `lib/game/components/card_component.dart`, replace lines 58-61 in `_renderFaceUp`:

Old:
```dart
if (c.isJoker) {
  CardPainter.paintFace(canvas, rect, 'JO', '★', const Color(0xFF800080));
  return;
}
```

New:
```dart
if (c.isJoker) {
  CardPainter.paintJoker(canvas, rect);
  return;
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/game/card_painter_test.dart && flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/game/theme/card_painter.dart lib/game/components/card_component.dart test/game/card_painter_test.dart
git commit -m "feat(cards): rewrite CardPainter — bold indices, face card accents, dramatic joker starburst"
```

---

### Task 4: Random Rotation for Trick Area Cards

**Files:**
- Modify: `lib/game/components/trick_area.dart`

**Context:** Current `trick_area.dart` has a `_seatAngle(int)` method (line 87) returning fixed angles per seat. Cards in the trick area are created at lines 74-81 using `CardComponent(...)`. The `showShadow` parameter from Task 2 should be enabled here.

- [ ] **Step 1: Add random jitter to trick_area.dart**

In `lib/game/components/trick_area.dart`:

1. Add import at top:
```dart
import 'dart:math';
```

2. Add field after `_trickCards` list (line 15):
```dart
final Random _random = Random();
```

3. Rename `_seatAngle` to `_seatBaseAngle` (line 87) — keep same values.

4. In `updateState`, replace the angle line (line 70):

Old:
```dart
final angle = _seatAngle(relativeSeat);
```

New:
```dart
// Base angle per seat + random jitter ±0.08 rad (≈ ±4.6°) for natural toss feel
final angle = _seatBaseAngle(relativeSeat) +
    (_random.nextDouble() - 0.5) * 0.16;
```

5. In the CardComponent constructor call (line 74), add `showShadow`:

Old:
```dart
final cardComp = CardComponent(
  card: play.card,
  isFaceUp: true,
  isHighlighted: false,
  position: pos,
  angle: angle,
)..priority = i;
```

New:
```dart
final cardComp = CardComponent(
  card: play.card,
  isFaceUp: true,
  isHighlighted: false,
  showShadow: true,
  position: pos,
  angle: angle,
)..priority = i;
```

6. Rename the method (line 87):

Old: `double _seatAngle(int relativeSeat) {`
New: `double _seatBaseAngle(int relativeSeat) {`

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/trick_area.dart
git commit -m "feat(cards): add random rotation jitter + drop shadows to trick area cards"
```

---

### Task 5: Add cardCounts to ClientGameState + Opponent Hand Fan Component

**Files:**
- Modify: `lib/app/models/client_game_state.dart` — add `cardCounts` field
- Modify: `lib/offline/local_game_controller.dart` — populate `cardCounts`
- Create: `lib/game/components/opponent_hand_fan.dart`
- Modify: `lib/game/kout_game.dart` — create + update fans
- Create: `test/game/opponent_hand_fan_test.dart`

**Context:** Current `ClientGameState` has no way to know how many cards opponents hold. In `kout_game.dart` line 226, opponent card count is hardcoded `8`. The `_toClientState` method in `local_game_controller.dart` (line 384) has access to `full.hands` which is a `Map<int, List<GameCard>>` — we can derive counts from it.

- [ ] **Step 1: Add cardCounts to ClientGameState**

In `lib/app/models/client_game_state.dart`:

1. Add field after `trickWinners` (line 42):
```dart
final Map<int, int> cardCounts; // seat index → card count
```

2. Add to constructor (after `this.trickWinners = const []`):
```dart
this.cardCounts = const {},
```

3. In `fromMap` factory, add before the return (line 170):
```dart
// Card counts: Worker may send these; offline controller always does
final rawCardCounts = gameData['cardCounts'] as Map<String, dynamic>?;
final cardCounts = rawCardCounts != null
    ? rawCardCounts.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()))
    : <int, int>{};
```

4. Add to the return statement:
```dart
cardCounts: cardCounts,
```

- [ ] **Step 2: Populate cardCounts in LocalGameController**

In `lib/offline/local_game_controller.dart`, in the `_toClientState` method (line 384), add before the return:

```dart
// Build card counts for ALL seats (not just human) — fan display needs this.
// Seats with empty hands get 0, not omitted, so fans show correct count.
final cardCounts = <int, int>{};
for (int seat = 0; seat < full.players.length; seat++) {
  cardCounts[seat] = (full.hands[seat] ?? []).length;
}
```

Add `cardCounts: cardCounts,` to the `ClientGameState` constructor call.

- [ ] **Step 3: Write failing test for OpponentHandFan**

```dart
// test/game/opponent_hand_fan_test.dart
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/game/components/opponent_hand_fan.dart';

void main() {
  test('OpponentHandFan stores initial card count', () {
    final fan = OpponentHandFan(
      cardCount: 6,
      position: Vector2.zero(),
      fanDirection: FanDirection.right,
    );
    expect(fan.cardCount, 6);
  });

  test('OpponentHandFan updates card count', () {
    final fan = OpponentHandFan(
      cardCount: 8,
      position: Vector2.zero(),
      fanDirection: FanDirection.above,
    );
    fan.updateCardCount(3);
    expect(fan.cardCount, 3);
  });

  test('all FanDirection values exist', () {
    expect(FanDirection.values.length, 3);
    expect(FanDirection.left, isNotNull);
    expect(FanDirection.right, isNotNull);
    expect(FanDirection.above, isNotNull);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/game/opponent_hand_fan_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 5: Create OpponentHandFan component**

Create `lib/game/components/opponent_hand_fan.dart`:

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/kout_theme.dart';

/// Direction the fan spreads from the player seat.
enum FanDirection { left, right, above }

/// Renders miniature face-down card backs near an opponent seat,
/// visually indicating how many cards they hold.
class OpponentHandFan extends PositionComponent {
  int cardCount;
  final FanDirection fanDirection;

  /// Miniature card dimensions (38% of full card size).
  static const double _miniWidth = KoutTheme.cardWidth * 0.38;
  static const double _miniHeight = KoutTheme.cardHeight * 0.38;
  static const double _cardOverlap = 8.0;
  static const double _maxFanAngle = 0.25; // radians total spread

  OpponentHandFan({
    required this.cardCount,
    required super.position,
    required this.fanDirection,
    super.anchor = Anchor.center,
  }) : super(size: Vector2(_miniWidth + _cardOverlap * 8, _miniHeight + 20));

  void updateCardCount(int count) {
    cardCount = count;
  }

  @override
  void render(Canvas canvas) {
    if (cardCount <= 0) return;

    final displayCount = cardCount.clamp(1, 8);

    for (int i = 0; i < displayCount; i++) {
      canvas.save();

      // Fan angle per card
      final t = displayCount == 1
          ? 0.0
          : (i / (displayCount - 1)) - 0.5;
      final angle = t * _maxFanAngle;

      // Offset per card based on direction
      double dx, dy;
      switch (fanDirection) {
        case FanDirection.right:
          dx = i * _cardOverlap;
          dy = (t * t) * 6;
        case FanDirection.left:
          dx = -i * _cardOverlap;
          dy = (t * t) * 6;
        case FanDirection.above:
          dx = i * _cardOverlap - (displayCount - 1) * _cardOverlap / 2;
          dy = -(t * t) * 6;
      }

      canvas.translate(size.x / 2 + dx, size.y / 2 + dy);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: _miniWidth,
        height: _miniHeight,
      );

      // Mini shadow
      final shadowRect = rect.shift(const Offset(1, 1.5));
      final shadowRRect = RRect.fromRectAndRadius(
        shadowRect,
        Radius.circular(KoutTheme.cardBorderRadius * 0.4),
      );
      canvas.drawRRect(
        shadowRRect,
        Paint()
          ..color = const Color(0x44000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Mini card back
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(KoutTheme.cardBorderRadius * 0.4),
      );
      canvas.drawRRect(rrect, Paint()..color = KoutTheme.cardBack);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Simple gold diamond ornament in center
      final diamondSize = _miniWidth * 0.25;
      final diamondPath = Path()
        ..moveTo(0, -diamondSize)
        ..lineTo(diamondSize * 0.6, 0)
        ..lineTo(0, diamondSize)
        ..lineTo(-diamondSize * 0.6, 0)
        ..close();
      canvas.drawPath(
        diamondPath,
        Paint()..color = KoutTheme.accent.withOpacity(0.5),
      );

      canvas.restore();
    }
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/game/opponent_hand_fan_test.dart`
Expected: PASS

- [ ] **Step 7: Wire OpponentHandFan into KoutGame**

In `lib/game/kout_game.dart`:

1. Add import at top:
```dart
import 'components/opponent_hand_fan.dart';
```

2. Add field after `_seats` list (line 36):
```dart
final List<OpponentHandFan> _opponentFans = [];
```

3. In `_updateSeats`, after the seat creation loop (after line 196 `add(_ambientDecoration!);`), add opponent fan creation. This code runs inside the `if (_seats.isEmpty)` block so it only executes once on first state:

```dart
// Create opponent card-back fans for non-player seats
for (int i = 0; i < 4; i++) {
  if (i == state.mySeatIndex) continue;
  final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
  final seatPos = layout.seatPosition(i, state.mySeatIndex);

  final FanDirection dir;
  final Vector2 offset;
  switch (relativeSeat) {
    case 1: // left opponent
      dir = FanDirection.right;
      offset = Vector2(50, -10);
    case 2: // top (partner)
      dir = FanDirection.above;
      offset = Vector2(0, -50);
    case 3: // right opponent
      dir = FanDirection.left;
      offset = Vector2(-50, -10);
    default:
      continue;
  }

  final fan = OpponentHandFan(
    cardCount: 8,
    position: seatPos + offset,
    fanDirection: dir,
  );
  _opponentFans.add(fan);
  add(fan);
}
```

4. In the existing seat update loop (around line 225), after `_seats[i].updateState(...)`, update fan card counts:

```dart
// Update opponent fan card counts
if (i != state.mySeatIndex) {
  final count = state.cardCounts[i] ?? 8;
  // Find the fan for this seat
  final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
  final fanIndex = _opponentFans.indexWhere((f) {
    // Fans were added in order: relative seats 1, 2, 3
    return true; // We'll use a map instead — see refined approach below
  });
}
```

**Refined approach:** Change `_opponentFans` from a list to a map keyed by absolute seat index for direct lookup:

Replace field:
```dart
final Map<int, OpponentHandFan> _opponentFans = {};
```

Replace creation code to use:
```dart
_opponentFans[i] = fan;
```

Replace update code to use:
```dart
if (i != state.mySeatIndex && _opponentFans.containsKey(i)) {
  _opponentFans[i]!.updateCardCount(state.cardCounts[i] ?? 8);
}
```

- [ ] **Step 8: Run full test suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/app/models/client_game_state.dart lib/offline/local_game_controller.dart lib/game/components/opponent_hand_fan.dart lib/game/kout_game.dart test/game/opponent_hand_fan_test.dart
git commit -m "feat(cards): add opponent card-back fan + cardCounts to ClientGameState"
```

---

### Task 6: Inter-Card Shadows in Hand Fan

**Files:**
- Modify: `lib/game/components/hand_component.dart`

**Context:** Current `hand_component.dart` creates `CardComponent` instances at line 62 without `showShadow` or `priority`. Cards are added via `add(cardComp)` at line 74. All cards default to priority 0, so z-order is undefined — Flame renders them in add-order which happens to be left-to-right.

- [ ] **Step 1: Add showShadow and priority to hand cards**

In `lib/game/components/hand_component.dart`, modify the `CardComponent` creation block (around line 62):

Old (lines 62-71):
```dart
final cardComp = CardComponent(
  card: gameCard,
  isFaceUp: true,
  isHighlighted: highlight,
  isDimmed: isWaitingForOthers || (hasPlayableCards && !highlight),
  restScale: handCardScale,
  position: posData.position,
  angle: posData.angle,
  onTap: (c) => onCardTap(c.encode()),
)..scale = Vector2.all(handCardScale);
```

New:
```dart
final cardComp = CardComponent(
  card: gameCard,
  isFaceUp: true,
  isHighlighted: highlight,
  isDimmed: isWaitingForOthers || (hasPlayableCards && !highlight),
  showShadow: true,
  restScale: handCardScale,
  position: posData.position,
  angle: posData.angle,
  onTap: (c) => onCardTap(c.encode()),
)
  ..scale = Vector2.all(handCardScale)
  ..priority = i; // Flame renders lower priority first → card 0 behind card 1, etc.
                  // This means rightmost cards render ON TOP, making shadows between
                  // overlapping cards visible. Do NOT reverse this.
```

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/hand_component.dart
git commit -m "feat(cards): enable drop shadows and z-ordering in hand fan"
```

---

### Task 7: Visual Verification & Integration Test

**Files:**
- All modified files from Tasks 1-6

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All PASS

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors (warnings acceptable)

- [ ] **Step 3: Build and visual spot-check**

Run: `flutter run -d macos`

Visual checklist:
- [ ] Cards are pure white with thin dark gray border
- [ ] Corner rank text is large (~16pt), bold, clearly readable at hand scale
- [ ] Corner suit symbol directly below rank, colored red or black
- [ ] Face cards (K, Q, J) have subtle tinted inner frame
- [ ] Joker has black 12-point starburst with "JOKER" / "خلو" text
- [ ] All cards cast drop shadows (visible below-right of each card)
- [ ] Hand cards show depth between overlapping cards (shadows visible)
- [ ] Trick area cards have slight random rotation (not perfectly axis-aligned)
- [ ] Opponent seats show mini fanned card backs
- [ ] Opponent fan card count decreases as tricks are played
- [ ] Card backs still show Islamic geometric pattern
- [ ] Highlighted cards still glow gold on playable
- [ ] Dimmed cards still show dark overlay on unplayable
- [ ] Card lift + scale on tap/hover still works
- [ ] Card play animation still works (hand → trick area)
- [ ] Trick win flash still works

- [ ] **Step 4: Fix any visual issues found**

```bash
git add -u
git commit -m "fix(cards): visual polish from integration testing"
```

---

## Future Enhancements (Not in Scope)

Noted for follow-up plans:

1. **Sprite-based face card art** — Commission or source illustrated K/Q/J/Joker portraits for a sprite sheet. Replace procedural face card accents with real artwork.
2. **3D perspective table** — Replace flat radial gradient with angled surface + depth.
3. **Character avatars** — Replace circle+text seats with illustrated Gulf/Bahraini characters.
4. **Bid speech bubbles** — Replace inline bid text with floating bubbles near avatars.
5. **Animated card dealing** — Cards fly from deck position to each player's hand.
6. **Card art for number cards** — Standard pip layouts (e.g., 7 of spades shows 7 spade pips arranged traditionally).
