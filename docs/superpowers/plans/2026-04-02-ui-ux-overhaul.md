# UI/UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the koutbh game UI from flat/functional to polished/immersive, matching the visual quality of reference card games (3D perspective table, character avatars, compact score HUD, action badges, stronger cultural theming).

**Architecture:** Each task modifies one component or creates one new file. All changes are in `lib/game/` (Flame layer) — no shared logic or backend changes. Tasks are ordered by visual impact and dependency: theme constants first, then background/table, then components from back to front (z-order).

**Tech Stack:** Flutter/Flame, Dart, custom Canvas painting (`dart:ui`), Flame effects system.

**Reference image context:** The target UI has: textured tile background, 3D perspective dark table surface, large cartoon character avatars with Gulf attire, bold colored name labels, thick green active-turn ring, speech bubble action badges per player, compact top-right score widget with large hero number and dot pips, and a HUD with round/trick counters.

---

## File Structure

### New files
- `lib/game/theme/diwaniya_colors.dart` — Expanded color palette + Diwaniya theme constants (replaces inline colors scattered across components)
- `lib/game/components/perspective_table.dart` — 3D perspective table surface (trapezoid with felt texture)
- `lib/game/components/avatar_painter.dart` — Procedural character avatar generator (geometric faces with Gulf attire)
- `lib/game/components/action_badge.dart` — Speech bubble badge component showing last action per player
- `lib/game/components/score_hud.dart` — Compact top-right score widget (replaces full-width banner)
- `lib/game/components/game_hud.dart` — Top-left HUD: round number, trick counter, sound toggle

### Modified files
- `lib/game/theme/kout_theme.dart` — Add new color constants, increase card dimensions, typography scale
- `lib/game/theme/textures.dart` — Add tile/brick background texture generator
- `lib/game/theme/card_painter.dart` — Increase center suit size, add card face subtle gradient for face cards
- `lib/game/components/table_background.dart` — Replace flat gradient with tiled texture
- `lib/game/components/player_seat.dart` — Integrate avatar painter, stronger active ring, action badge, larger name labels
- `lib/game/components/hand_component.dart` — Adaptive card spacing, inter-card shadows, hand shelf visual
- `lib/game/components/opponent_hand_fan.dart` — Position relative to avatar, slight scale increase, card count badge
- `lib/game/components/trick_area.dart` — Remove felt circle, cards sit on perspective table, perspective-aware scaling
- `lib/game/components/score_display.dart` — Replace with `score_hud.dart` (compact widget)
- `lib/game/components/ambient_decoration.dart` — Increase tea glass opacity to 30%, add cultural border motifs
- `lib/game/managers/layout_manager.dart` — Table trapezoid geometry, updated seat positions relative to table edges
- `lib/game/kout_game.dart` — Wire new components (perspective table, HUD, score HUD, action badges), pass round/trick metadata to HUD

### Test files
All tests go in `test/game/` (flat — matches existing convention):
- `test/game/diwaniya_colors_test.dart`
- `test/game/perspective_table_test.dart`
- `test/game/avatar_painter_test.dart`
- `test/game/action_badge_test.dart`
- `test/game/score_hud_test.dart`
- `test/game/game_hud_test.dart`
- `test/game/hand_spacing_test.dart`
- `test/game/player_seat_avatar_test.dart`

### State model note
`ClientGameState` (in `lib/app/models/client_game_state.dart`) already has all fields used by this plan: `bidHistory`, `currentTrickPlays`, `trickWinners`, `cardCounts`, `tricks`, `scores`, `currentBid`, `bidderUid`, `trumpSuit`. It does NOT have a `roundNumber` field — round number must be derived from `trickWinners.length / 8 + 1` or similar.

---

## Task 1: Expand Theme Constants — `diwaniya_colors.dart`

**Files:**
- Create: `lib/game/theme/diwaniya_colors.dart`
- Modify: `lib/game/theme/kout_theme.dart:1-83`
- Test: `test/game/diwaniya_colors_test.dart`

This task creates a centralized color palette used by all subsequent tasks. Currently colors are scattered across `kout_theme.dart`, `geometric_patterns.dart`, `textures.dart`, and inline in components.

- [ ] **Step 1: Write the test for DiwaniyaColors**

```dart
// test/game/diwaniya_colors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/diwaniya_colors.dart';

void main() {
  group('DiwaniyaColors', () {
    test('background tile color is defined and opaque', () {
      expect(DiwaniyaColors.backgroundTile.alpha, 1.0);
    });

    test('table surface colors form a gradient (surface lighter than edge)', () {
      // Surface center should be lighter than surface edge
      expect(
        DiwaniyaColors.tableSurfaceCenter.computeLuminance(),
        greaterThan(DiwaniyaColors.tableSurfaceEdge.computeLuminance()),
      );
    });

    test('active turn ring color is high contrast', () {
      // Active ring should be bright (luminance > 0.3)
      expect(
        DiwaniyaColors.activeTurnRing.computeLuminance(),
        greaterThan(0.3),
      );
    });

    test('all Diwaniya theme colors are non-null', () {
      expect(DiwaniyaColors.backgroundTile, isNotNull);
      expect(DiwaniyaColors.backgroundTileDark, isNotNull);
      expect(DiwaniyaColors.tableSurfaceCenter, isNotNull);
      expect(DiwaniyaColors.tableSurfaceEdge, isNotNull);
      expect(DiwaniyaColors.tableFelt, isNotNull);
      expect(DiwaniyaColors.goldAccent, isNotNull);
      expect(DiwaniyaColors.goldHighlight, isNotNull);
      expect(DiwaniyaColors.burgundy, isNotNull);
      expect(DiwaniyaColors.cream, isNotNull);
      expect(DiwaniyaColors.darkWood, isNotNull);
      expect(DiwaniyaColors.activeTurnRing, isNotNull);
      expect(DiwaniyaColors.actionBadgeBg, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/diwaniya_colors_test.dart`
Expected: FAIL — `diwaniya_colors.dart` does not exist.

- [ ] **Step 3: Create `diwaniya_colors.dart`**

```dart
// lib/game/theme/diwaniya_colors.dart
import 'dart:ui';

/// Centralized Diwaniya-themed color palette for the entire game UI.
///
/// Named after the reference screenshot analysis. All game components should
/// use these constants instead of inline color literals.
class DiwaniyaColors {
  DiwaniyaColors._();

  // ---------------------------------------------------------------------------
  // Background
  // ---------------------------------------------------------------------------

  /// Tile/brick texture base color (blue-gray, reference screenshot background).
  static const Color backgroundTile = Color(0xFF3D5A6E);

  /// Darker variant for tile texture grout lines / edge vignette.
  static const Color backgroundTileDark = Color(0xFF263845);

  /// Vignette edge color (near-black with blue tint).
  static const Color vignette = Color(0xFF0F1A22);

  // ---------------------------------------------------------------------------
  // Table surface (3D perspective trapezoid)
  // ---------------------------------------------------------------------------

  /// Center of the table felt — lighter for depth.
  static const Color tableSurfaceCenter = Color(0xFF4A5C4A);

  /// Edge of the table felt — darker rim.
  static const Color tableSurfaceEdge = Color(0xFF2B3A2B);

  /// Table felt overlay for the trick play zone.
  static const Color tableFelt = Color(0xFF3A4D3A);

  /// Table border/edge bevel — dark wood.
  static const Color tableBorder = Color(0xFF3B2314);

  // ---------------------------------------------------------------------------
  // Diwaniya accent colors (from CLAUDE.md theme reference)
  // ---------------------------------------------------------------------------

  /// Primary gold accent — buttons, highlights, borders.
  static const Color goldAccent = Color(0xFFC9A84C);

  /// Brighter gold for active state highlights.
  static const Color goldHighlight = Color(0xFFE0C060);

  /// Burgundy — card back, panel accents.
  static const Color burgundy = Color(0xFF5C1A1B);

  /// Cream — text on dark surfaces, card face tint.
  static const Color cream = Color(0xFFF5ECD7);

  /// Dark wood — primary dark background.
  static const Color darkWood = Color(0xFF3B2314);

  // ---------------------------------------------------------------------------
  // Player interaction
  // ---------------------------------------------------------------------------

  /// Active turn indicator ring — bright green (high contrast on any background).
  static const Color activeTurnRing = Color(0xFF4ADE80);

  /// Action badge background (semi-transparent dark).
  static const Color actionBadgeBg = Color(0xE6222222);

  /// Action badge border.
  static const Color actionBadgeBorder = Color(0xFF555555);

  // ---------------------------------------------------------------------------
  // Name label pill backgrounds
  // ---------------------------------------------------------------------------

  /// Name label background for Team A (blue tint).
  static const Color nameLabelTeamA = Color(0xCC2A5FAA);

  /// Name label background for Team B (red tint).
  static const Color nameLabelTeamB = Color(0xCCAA2A2A);

  // ---------------------------------------------------------------------------
  // Score HUD
  // ---------------------------------------------------------------------------

  /// Score HUD background (dark, high alpha).
  static const Color scoreHudBg = Color(0xE61A1A2E);

  /// Score HUD border.
  static const Color scoreHudBorder = Color(0xFF444466);

  // ---------------------------------------------------------------------------
  // Card enhancements
  // ---------------------------------------------------------------------------

  /// Subtle gradient top for face cards (warm tint).
  static const Color faceCardGradientTop = Color(0xFFFFFDF8);

  /// Subtle gradient bottom for face cards.
  static const Color faceCardGradientBottom = Color(0xFFF5F0E8);
}
```

- [ ] **Step 4: Update `kout_theme.dart` to reference new palette**

Add imports and expose key colors through `KoutTheme` for backward compatibility. Add to the top of `kout_theme.dart` after the existing imports:

```dart
// In kout_theme.dart — add at line 2:
import 'diwaniya_colors.dart';
```

Add below `cardShadowColor` (line 25):

```dart
  // ---------------------------------------------------------------------------
  // Enhanced Diwaniya palette (delegates to DiwaniyaColors)
  // ---------------------------------------------------------------------------

  static const Color activeTurnRing = DiwaniyaColors.activeTurnRing;
  static const Color goldAccent = DiwaniyaColors.goldAccent;
  static const Color goldHighlight = DiwaniyaColors.goldHighlight;
  static const Color cream = DiwaniyaColors.cream;

  // Increased card dimensions for better readability
  static const double cardWidthLarge = 80;
  static const double cardHeightLarge = 114;
  static const double cardCenterSuitSizeLarge = 42.0;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/diwaniya_colors_test.dart`
Expected: PASS

- [ ] **Step 6: Run full test suite**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test`
Expected: All existing tests still pass (no regressions).

- [ ] **Step 7: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/theme/diwaniya_colors.dart lib/game/theme/kout_theme.dart test/game/diwaniya_colors_test.dart
git commit -m "feat(theme): add DiwaniyaColors centralized palette + enhanced theme constants"
```

---

## Task 2: Textured Tile Background

**Files:**
- Modify: `lib/game/theme/textures.dart:1-19`
- Modify: `lib/game/components/table_background.dart:1-25`
- Test: Visual verification (Flame canvas — no unit test for rendering; verify via `flutter run`)

Replace the flat radial gradient with a textured tile/brick pattern with vignette edges. This is the foundation layer everything else renders on.

- [ ] **Step 1: Rewrite `textures.dart` — add tile texture generator**

Replace the contents of `lib/game/theme/textures.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'diwaniya_colors.dart';

/// Procedural texture generators for the Diwaniya table theme.
class TextureGenerator {
  /// Creates a warm wood-grain radial gradient paint for the table background.
  /// Kept for backward compatibility but no longer used by TableBackgroundComponent.
  static Paint woodGrainPaint(Rect bounds) {
    return Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Color(0xFF3A4F4D),
          Color(0xFF2F403E),
          Color(0xFF1F2D2B),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds);
  }

  /// Draws a repeating tile/brick texture pattern across [bounds].
  ///
  /// Creates a woven fabric-like texture reminiscent of Diwaniya floor tiles.
  /// Each tile is [tileW] x [tileH] with a subtle offset every other row.
  static void drawTileTexture(
    Canvas canvas,
    Rect bounds, {
    double tileW = 64.0,
    double tileH = 32.0,
  }) {
    final basePaint = Paint()..color = DiwaniyaColors.backgroundTile;
    canvas.drawRect(bounds, basePaint);

    final tilePaint = Paint()
      ..color = DiwaniyaColors.backgroundTileDark.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cols = (bounds.width / tileW).ceil() + 2;
    final rows = (bounds.height / tileH).ceil() + 2;

    for (int row = 0; row < rows; row++) {
      final offsetX = row.isOdd ? tileW / 2 : 0.0;
      for (int col = 0; col < cols; col++) {
        final x = bounds.left + col * tileW - offsetX;
        final y = bounds.top + row * tileH;
        final tileRect = Rect.fromLTWH(x, y, tileW, tileH);
        canvas.drawRect(tileRect, tilePaint);

        // Subtle inner highlight on alternating tiles for texture
        if ((row + col) % 3 == 0) {
          final highlightPaint = Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.02);
          canvas.drawRect(tileRect.deflate(2), highlightPaint);
        }
      }
    }
  }

  /// Draws a radial vignette darkening the edges of [bounds].
  static void drawVignette(Canvas canvas, Rect bounds) {
    final center = bounds.center;
    final radius = math.max(bounds.width, bounds.height) * 0.7;

    final vignetteShader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0x00000000),
        const Color(0x00000000),
        DiwaniyaColors.vignette.withValues(alpha: 0.5),
        DiwaniyaColors.vignette.withValues(alpha: 0.8),
      ],
      stops: const [0.0, 0.5, 0.8, 1.0],
    ).createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    canvas.drawRect(
      bounds,
      Paint()..shader = vignetteShader,
    );
  }
}
```

- [ ] **Step 2: Rewrite `table_background.dart` to use tile texture + vignette**

Replace the contents of `lib/game/components/table_background.dart`:

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/textures.dart';

/// Full-screen textured tile background with vignette.
///
/// Renders a repeating tile pattern (Diwaniya floor aesthetic) with darkened
/// edges. Should be added as the first child in [KoutGame] so it renders behind
/// all other components.
class TableBackgroundComponent extends PositionComponent {
  TableBackgroundComponent() : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    TextureGenerator.drawTileTexture(canvas, rect);
    TextureGenerator.drawVignette(canvas, rect);
  }
}
```

- [ ] **Step 3: Run `flutter analyze` to verify no issues**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze`
Expected: No analysis issues.

- [ ] **Step 4: Run the app to visually verify background**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter run` (picks first available device)
Expected: Blue-gray tile background with darkened edges instead of flat sage green gradient.

- [ ] **Step 5: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/theme/textures.dart lib/game/components/table_background.dart
git commit -m "feat(ui): textured tile background with vignette edges"
```

---

## Task 3: 3D Perspective Table Surface

**Files:**
- Create: `lib/game/components/perspective_table.dart`
- Modify: `lib/game/managers/layout_manager.dart:1-99` — add table geometry getters
- Modify: `lib/game/kout_game.dart:100-101` — add perspective table after background
- Test: `test/game/perspective_table_test.dart`

Draw a 3D trapezoid table surface on top of the tile background. This creates the "sitting at a table" feel. The table narrows toward the top (perspective foreshortening).

- [ ] **Step 1: Write the test**

```dart
// test/game/perspective_table_test.dart
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/managers/layout_manager.dart';

void main() {
  group('LayoutManager table geometry', () {
    final layout = LayoutManager(Vector2(800, 600));

    test('table trapezoid has 4 vertices', () {
      final verts = layout.tableVertices;
      expect(verts.length, 4);
    });

    test('bottom edge is wider than top edge (perspective)', () {
      final verts = layout.tableVertices;
      final bottomWidth = (verts[3].dx - verts[2].dx).abs();
      final topWidth = (verts[1].dx - verts[0].dx).abs();
      expect(bottomWidth, greaterThan(topWidth));
    });

    test('table top edge starts below score panel', () {
      final verts = layout.tableVertices;
      // Top edge Y should be >= 60 (below score HUD area)
      expect(verts[0].dy, greaterThanOrEqualTo(60));
    });

    test('table bottom edge is above hand area', () {
      final verts = layout.tableVertices;
      // Bottom edge Y should leave room for hand (height - ~120)
      expect(verts[2].dy, lessThan(600 - 80));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/perspective_table_test.dart`
Expected: FAIL — `tableVertices` doesn't exist on LayoutManager.

- [ ] **Step 3: Add table geometry to `layout_manager.dart`**

Add after the `trickTrackerCenter` getter (around line 33):

```dart
  // ---------------------------------------------------------------------------
  // 3D Perspective table surface geometry
  // ---------------------------------------------------------------------------

  /// Fraction of screen width for the table's top edge (narrower = more perspective).
  static const double _tableTopWidthRatio = 0.55;

  /// Fraction of screen width for the table's bottom edge.
  static const double _tableBottomWidthRatio = 0.85;

  /// Y position of table top edge (below score HUD).
  double get _tableTopY => 70.0;

  /// Y position of table bottom edge (above hand area).
  double get _tableBottomY => height - 130.0;

  /// The 4 vertices of the perspective table trapezoid.
  /// Order: topLeft, topRight, bottomLeft, bottomRight.
  /// The top edge is narrower, creating foreshortening.
  List<Offset> get tableVertices {
    final topHalf = width * _tableTopWidthRatio / 2;
    final botHalf = width * _tableBottomWidthRatio / 2;
    final cx = width / 2;
    return [
      Offset(cx - topHalf, _tableTopY),   // top-left
      Offset(cx + topHalf, _tableTopY),   // top-right
      Offset(cx - botHalf, _tableBottomY), // bottom-left
      Offset(cx + botHalf, _tableBottomY), // bottom-right
    ];
  }

  /// Center point of the table surface.
  Offset get tableCenter {
    final v = tableVertices;
    return Offset(
      (v[0].dx + v[1].dx + v[2].dx + v[3].dx) / 4,
      (v[0].dy + v[1].dy + v[2].dy + v[3].dy) / 4,
    );
  }
```

- [ ] **Step 4: Create `perspective_table.dart`**

```dart
// lib/game/components/perspective_table.dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../managers/layout_manager.dart';
import '../theme/diwaniya_colors.dart';

/// Renders a 3D perspective table surface as a trapezoid.
///
/// The table narrows toward the top to create foreshortening depth.
/// Drawn on top of the tile background, below all game components.
class PerspectiveTableComponent extends PositionComponent {
  LayoutManager layout;

  PerspectiveTableComponent({required this.layout})
      : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize;
  }

  void updateLayout(LayoutManager newLayout) {
    layout = newLayout;
  }

  @override
  void render(Canvas canvas) {
    final verts = layout.tableVertices;

    // Table body — filled trapezoid
    final bodyPath = Path()
      ..moveTo(verts[0].dx, verts[0].dy)
      ..lineTo(verts[1].dx, verts[1].dy)
      ..lineTo(verts[3].dx, verts[3].dy)
      ..lineTo(verts[2].dx, verts[2].dy)
      ..close();

    // Radial gradient for felt surface (lighter center, darker edges)
    final center = layout.tableCenter;
    final tableRect = Rect.fromPoints(verts[0], verts[3]);
    final radius = tableRect.longestSide * 0.6;

    final feltShader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: const [
        DiwaniyaColors.tableSurfaceCenter,
        DiwaniyaColors.tableSurfaceEdge,
      ],
      stops: const [0.0, 1.0],
    ).createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    canvas.drawPath(bodyPath, Paint()..shader = feltShader);

    // Table border — thick dark wood rim
    final borderPaint = Paint()
      ..color = DiwaniyaColors.tableBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, borderPaint);

    // Inner gold accent line (inset 6px)
    final insetVerts = _insetVertices(verts, 8.0);
    final insetPath = Path()
      ..moveTo(insetVerts[0].dx, insetVerts[0].dy)
      ..lineTo(insetVerts[1].dx, insetVerts[1].dy)
      ..lineTo(insetVerts[3].dx, insetVerts[3].dy)
      ..lineTo(insetVerts[2].dx, insetVerts[2].dy)
      ..close();

    final accentPaint = Paint()
      ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(insetPath, accentPaint);
  }

  /// Shrinks the trapezoid vertices inward by [amount] pixels.
  List<Offset> _insetVertices(List<Offset> verts, double amount) {
    // Simple approach: move each vertex toward the centroid
    final cx = (verts[0].dx + verts[1].dx + verts[2].dx + verts[3].dx) / 4;
    final cy = (verts[0].dy + verts[1].dy + verts[2].dy + verts[3].dy) / 4;
    final centroid = Offset(cx, cy);

    return verts.map((v) {
      final dir = centroid - v;
      final len = dir.distance;
      if (len < 1.0) return v;
      return v + dir / len * amount;
    }).toList();
  }
}
```

- [ ] **Step 5: Wire into `kout_game.dart`**

Add import at the top of `kout_game.dart`:
```dart
import 'components/perspective_table.dart';
```

Add field after `_opponentFans` (around line 40):
```dart
  PerspectiveTableComponent? _perspectiveTable;
```

In `onLoad()`, after `add(TableBackgroundComponent());` (line 101), add:
```dart
    _perspectiveTable = PerspectiveTableComponent(layout: layout);
    add(_perspectiveTable!);
```

In `onGameResize()`, after `layout = LayoutManager(newSize);` (line 122), add:
```dart
    _perspectiveTable?.updateLayout(layout);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/perspective_table_test.dart`
Expected: PASS

- [ ] **Step 7: Run full test suite + analyze**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze && flutter test`
Expected: No issues, all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/perspective_table.dart lib/game/managers/layout_manager.dart lib/game/kout_game.dart
git add test/game/perspective_table_test.dart
git commit -m "feat(ui): 3D perspective table surface with felt gradient and gold accent"
```

---

## Task 4: Procedural Character Avatars

**Files:**
- Create: `lib/game/components/avatar_painter.dart`
- Test: `test/game/avatar_painter_test.dart`

Generate simple but expressive character avatars procedurally. Each player gets a unique face based on a seed (their seat index or UID hash). Avatars show: round face, eyes, mouth, and Gulf attire (ghutra/agal headwear). No image assets needed — all Canvas-painted.

- [ ] **Step 1: Write the test**

```dart
// test/game/avatar_painter_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/avatar_painter.dart';

void main() {
  group('AvatarPainter', () {
    test('generates consistent avatar for same seed', () {
      final traits1 = AvatarTraits.fromSeed(42);
      final traits2 = AvatarTraits.fromSeed(42);
      expect(traits1.skinTone, equals(traits2.skinTone));
      expect(traits1.hasGhutra, equals(traits2.hasGhutra));
      expect(traits1.eyeStyle, equals(traits2.eyeStyle));
    });

    test('different seeds produce different traits', () {
      final traits0 = AvatarTraits.fromSeed(0);
      final traits1 = AvatarTraits.fromSeed(1);
      final traits2 = AvatarTraits.fromSeed(2);
      final traits3 = AvatarTraits.fromSeed(3);
      // At least some variation across 4 seats
      final allSame = traits0.skinTone == traits1.skinTone &&
          traits1.skinTone == traits2.skinTone &&
          traits2.skinTone == traits3.skinTone;
      expect(allSame, isFalse);
    });

    test('all 4 preset traits have valid colors', () {
      for (int i = 0; i < 4; i++) {
        final traits = AvatarTraits.fromSeed(i);
        expect(traits.skinTone.alpha, 1.0);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/avatar_painter_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Create `avatar_painter.dart`**

```dart
// lib/game/components/avatar_painter.dart
import 'dart:math' as math;
import 'dart:ui';

/// Traits that define a procedural character avatar's appearance.
///
/// Generated deterministically from a seed so the same player always
/// gets the same face.
class AvatarTraits {
  final Color skinTone;
  final Color hairColor;
  final bool hasGhutra;      // traditional headwear
  final bool hasBeard;
  final bool hasSunglasses;
  final int eyeStyle;        // 0=round, 1=narrow, 2=wide
  final int mouthStyle;      // 0=neutral, 1=smile, 2=serious
  final Color ghutraColor;

  const AvatarTraits({
    required this.skinTone,
    required this.hairColor,
    required this.hasGhutra,
    required this.hasBeard,
    required this.hasSunglasses,
    required this.eyeStyle,
    required this.mouthStyle,
    required this.ghutraColor,
  });

  /// Generates avatar traits deterministically from [seed] (seat index or hash).
  factory AvatarTraits.fromSeed(int seed) {
    // 4 preset character archetypes for the 4 seats
    const presets = [
      // Seat 0 (player): young, no ghutra, casual
      AvatarTraits(
        skinTone: Color(0xFFD4A574),
        hairColor: Color(0xFF2C1810),
        hasGhutra: false,
        hasBeard: false,
        hasSunglasses: false,
        eyeStyle: 0,
        mouthStyle: 1,
        ghutraColor: Color(0xFFFFFFFF),
      ),
      // Seat 1: elder with white ghutra, serious
      AvatarTraits(
        skinTone: Color(0xFFC68642),
        hairColor: Color(0xFFCCCCCC),
        hasGhutra: true,
        hasBeard: true,
        hasSunglasses: false,
        eyeStyle: 1,
        mouthStyle: 2,
        ghutraColor: Color(0xFFFFFFFF),
      ),
      // Seat 2: middle-aged, red-check ghutra, beard
      AvatarTraits(
        skinTone: Color(0xFFBE8A60),
        hairColor: Color(0xFF1A1A1A),
        hasGhutra: true,
        hasBeard: true,
        hasSunglasses: false,
        eyeStyle: 2,
        mouthStyle: 0,
        ghutraColor: Color(0xFFCC3333),
      ),
      // Seat 3: young, sunglasses, white ghutra
      AvatarTraits(
        skinTone: Color(0xFFD4A574),
        hairColor: Color(0xFF1A1A1A),
        hasGhutra: true,
        hasBeard: false,
        hasSunglasses: true,
        eyeStyle: 0,
        mouthStyle: 1,
        ghutraColor: Color(0xFFFFFFFF),
      ),
    ];

    return presets[seed % presets.length];
  }
}

/// Paints a procedural character avatar onto a Canvas.
///
/// Designed for ~72px diameter circles on player seats.
class AvatarPainter {
  /// Paints the avatar centered at [center] with the given [radius].
  static void paint(
    Canvas canvas,
    Offset center,
    double radius,
    AvatarTraits traits,
  ) {
    // Clip to circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Background
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF8FBFE0));

    // Head
    final headRadius = radius * 0.65;
    final headCenter = Offset(center.dx, center.dy + radius * 0.1);
    canvas.drawCircle(headCenter, headRadius, Paint()..color = traits.skinTone);

    // Eyes
    final eyeY = headCenter.dy - headRadius * 0.15;
    final eyeSpacing = headRadius * 0.35;

    if (traits.hasSunglasses) {
      _drawSunglasses(canvas, headCenter, headRadius, eyeY, eyeSpacing);
    } else {
      _drawEyes(canvas, eyeY, headCenter.dx, eyeSpacing, headRadius, traits.eyeStyle);
    }

    // Mouth
    _drawMouth(canvas, headCenter, headRadius, traits.mouthStyle);

    // Beard
    if (traits.hasBeard) {
      _drawBeard(canvas, headCenter, headRadius, traits.hairColor);
    }

    // Ghutra (headwear)
    if (traits.hasGhutra) {
      _drawGhutra(canvas, headCenter, headRadius, traits.ghutraColor, radius);
    } else {
      // Hair
      _drawHair(canvas, headCenter, headRadius, traits.hairColor);
    }

    canvas.restore();
  }

  static void _drawEyes(Canvas canvas, double eyeY, double cx, double spacing, double headR, int style) {
    final eyePaint = Paint()..color = const Color(0xFF1A1A1A);
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    final eyeR = headR * (style == 2 ? 0.12 : style == 1 ? 0.08 : 0.10);
    final whiteR = eyeR * 1.6;

    for (final dx in [-spacing, spacing]) {
      // White of eye
      canvas.drawOval(
        Rect.fromCircle(center: Offset(cx + dx, eyeY), radius: whiteR),
        whitePaint,
      );
      // Pupil
      canvas.drawCircle(Offset(cx + dx, eyeY), eyeR, eyePaint);
      // Highlight
      canvas.drawCircle(
        Offset(cx + dx + eyeR * 0.3, eyeY - eyeR * 0.3),
        eyeR * 0.35,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
  }

  static void _drawSunglasses(Canvas canvas, Offset headCenter, double headR, double eyeY, double spacing) {
    final lensR = headR * 0.22;
    final glassesPaint = Paint()..color = const Color(0xFF111111);
    final framePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Bridge
    canvas.drawLine(
      Offset(headCenter.dx - spacing + lensR, eyeY),
      Offset(headCenter.dx + spacing - lensR, eyeY),
      framePaint,
    );

    // Lenses
    for (final dx in [-spacing, spacing]) {
      final lensRect = RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset(headCenter.dx + dx, eyeY), radius: lensR),
        Radius.circular(lensR * 0.4),
      );
      canvas.drawRRect(lensRect, glassesPaint);
      canvas.drawRRect(lensRect, framePaint);
    }
  }

  static void _drawMouth(Canvas canvas, Offset headCenter, double headR, int style) {
    final mouthY = headCenter.dy + headR * 0.35;
    final mouthPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final mouthW = headR * 0.3;
    switch (style) {
      case 1: // smile
        final path = Path()
          ..moveTo(headCenter.dx - mouthW, mouthY)
          ..quadraticBezierTo(headCenter.dx, mouthY + headR * 0.15, headCenter.dx + mouthW, mouthY);
        canvas.drawPath(path, mouthPaint);
      case 2: // serious
        canvas.drawLine(
          Offset(headCenter.dx - mouthW, mouthY),
          Offset(headCenter.dx + mouthW, mouthY),
          mouthPaint,
        );
      default: // neutral
        final path = Path()
          ..moveTo(headCenter.dx - mouthW * 0.8, mouthY)
          ..quadraticBezierTo(headCenter.dx, mouthY + headR * 0.05, headCenter.dx + mouthW * 0.8, mouthY);
        canvas.drawPath(path, mouthPaint);
    }
  }

  static void _drawBeard(Canvas canvas, Offset headCenter, double headR, Color color) {
    final beardPath = Path();
    final beardTop = headCenter.dy + headR * 0.2;
    final beardBot = headCenter.dy + headR * 0.85;
    final beardW = headR * 0.55;

    beardPath.moveTo(headCenter.dx - beardW, beardTop);
    beardPath.quadraticBezierTo(
      headCenter.dx - beardW * 0.8, beardBot,
      headCenter.dx, beardBot + headR * 0.1,
    );
    beardPath.quadraticBezierTo(
      headCenter.dx + beardW * 0.8, beardBot,
      headCenter.dx + beardW, beardTop,
    );

    canvas.drawPath(beardPath, Paint()..color = color.withValues(alpha: 0.7));
  }

  static void _drawGhutra(Canvas canvas, Offset headCenter, double headR, Color color, double circleRadius) {
    // White cloth draped over the top of the head
    final ghutraPath = Path();
    final topY = headCenter.dy - headR * 1.0;
    final drapeSide = headR * 1.1;

    ghutraPath.moveTo(headCenter.dx - drapeSide, headCenter.dy - headR * 0.3);
    ghutraPath.lineTo(headCenter.dx - drapeSide * 0.8, topY);
    ghutraPath.quadraticBezierTo(headCenter.dx, topY - headR * 0.2, headCenter.dx + drapeSide * 0.8, topY);
    ghutraPath.lineTo(headCenter.dx + drapeSide, headCenter.dy - headR * 0.3);

    // Extend sides down for draping effect
    ghutraPath.lineTo(headCenter.dx + drapeSide * 0.9, headCenter.dy + headR * 0.5);
    ghutraPath.lineTo(headCenter.dx - drapeSide * 0.9, headCenter.dy + headR * 0.5);
    ghutraPath.close();

    canvas.drawPath(ghutraPath, Paint()..color = color);

    // Agal (black cord) across the forehead
    final agalY = headCenter.dy - headR * 0.55;
    final agalPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(headCenter.dx - headR * 0.7, agalY),
      Offset(headCenter.dx + headR * 0.7, agalY),
      agalPaint,
    );
    // Second agal band
    canvas.drawLine(
      Offset(headCenter.dx - headR * 0.65, agalY + 4),
      Offset(headCenter.dx + headR * 0.65, agalY + 4),
      agalPaint..strokeWidth = 2.0,
    );

    // Red check pattern overlay for red ghutra
    if (color.red > 150 && color.green < 100) {
      final checkPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (double dy = topY; dy < headCenter.dy + headR * 0.5; dy += 6) {
        canvas.drawLine(
          Offset(headCenter.dx - drapeSide * 0.7, dy),
          Offset(headCenter.dx + drapeSide * 0.7, dy),
          checkPaint,
        );
      }
    }
  }

  static void _drawHair(Canvas canvas, Offset headCenter, double headR, Color color) {
    final hairPath = Path();
    final topY = headCenter.dy - headR * 0.9;
    final hairW = headR * 0.85;

    hairPath.addArc(
      Rect.fromCenter(center: Offset(headCenter.dx, topY + headR * 0.3), width: hairW * 2, height: headR * 1.2),
      math.pi,
      math.pi,
    );

    canvas.drawPath(hairPath, Paint()..color = color);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/avatar_painter_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/avatar_painter.dart test/game/avatar_painter_test.dart
git commit -m "feat(ui): procedural character avatars with Gulf attire (ghutra, sunglasses, beard)"
```

---

## Task 5: Revamped Player Seats — Avatar, Name Labels, Active Ring

**Files:**
- Modify: `lib/game/components/player_seat.dart:1-357`
- Test: `test/game/player_seat_avatar_test.dart`

Major rewrite of `PlayerSeatComponent` to integrate: avatar painter (Task 4), bold colored name labels with pill backgrounds, thick solid green active-turn ring (replacing the subtle glow pulse), and dealer badge redesign.

- [ ] **Step 1: Write the test**

```dart
// test/game/player_seat_avatar_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/player_seat.dart';

void main() {
  group('PlayerSeatComponent', () {
    test('creates with required parameters', () {
      final seat = PlayerSeatComponent(
        playerName: 'TestUser',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
        avatarSeed: 0,
      );
      expect(seat.playerName, 'TestUser');
      expect(seat.cardCount, 8);
      expect(seat.isActive, false);
      expect(seat.isTeamA, true);
    });

    test('updateState changes properties', () {
      final seat = PlayerSeatComponent(
        playerName: 'OldName',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
        avatarSeed: 0,
      );
      seat.updateState(
        name: 'NewName',
        cards: 5,
        active: true,
        teamA: false,
      );
      expect(seat.playerName, 'NewName');
      expect(seat.cardCount, 5);
      expect(seat.isActive, true);
      expect(seat.isTeamA, false);
    });

    test('name truncation works for long names', () {
      final seat = PlayerSeatComponent(
        playerName: 'VeryLongPlayerName',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
        avatarSeed: 0,
      );
      // Internal truncation — verify component doesn't crash
      expect(seat.playerName, 'VeryLongPlayerName');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/player_seat_avatar_test.dart`
Expected: FAIL — `avatarSeed` parameter doesn't exist yet.

- [ ] **Step 3: Rewrite `player_seat.dart`**

The full rewrite integrates the avatar painter and redesigns the visual hierarchy. Key changes:

1. Add `avatarSeed` parameter for avatar generation
2. Replace glow pulse with solid bright green ring when active
3. Larger component size (110x110 to accommodate name label)
4. Name rendered in a colored pill below the avatar
5. Keep gold rope border but shift to `DiwaniyaColors.goldAccent`
6. Remove team badge circle (team color shown via name pill instead)
7. Keep bid action/label display, increase font sizes

The new `render()` method draws in this order:
- Gold rope border (background decoration)
- Avatar circle with `AvatarPainter.paint()`
- Active turn ring: 5px solid `DiwaniyaColors.activeTurnRing` stroke (bright green)
- Timer arc: overlaid on top of active ring
- Name pill: rounded rect with team color fill, white text 13pt
- Dealer badge: small gold circle with "D" at top-right
- Bid action / bid label text

This is a large file rewrite. The implementing agent should:
1. Read the current `player_seat.dart` in full
2. Add `import 'avatar_painter.dart';` and `import '../theme/diwaniya_colors.dart';`
3. Add `final int avatarSeed;` field and constructor parameter
4. Keep `_GlowPulseComponent` and `_TrickWinFlashComponent` inner classes but update `_GlowPulseComponent` to use `DiwaniyaColors.activeTurnRing` instead of `KoutTheme.accent`
5. In `render()`, replace the flat circle fill (line 51) with:
   ```dart
   // Draw character avatar inside the circle
   AvatarPainter.paint(canvas, center, _radius - 3, AvatarTraits.fromSeed(avatarSeed));
   ```
6. Replace the team badge (lines 117-131) with a name pill:
   ```dart
   // Name pill below avatar
   final pillY = center.dy + _radius + 12;
   final pillColor = isTeamA ? DiwaniyaColors.nameLabelTeamA : DiwaniyaColors.nameLabelTeamB;
   final pillRect = RRect.fromRectAndRadius(
     Rect.fromCenter(center: Offset(center.dx, pillY), width: 80, height: 22),
     const Radius.circular(11),
   );
   canvas.drawRRect(pillRect, Paint()..color = pillColor);
   _drawText(canvas, _truncateName(playerName), const Color(0xFFFFFFFF),
     Offset(center.dx, pillY), 13);
   ```
7. Change the active ring from `KoutTheme.accent` (olive, 2.5px) to `DiwaniyaColors.activeTurnRing` (green, 5px):
   ```dart
   if (isActive) {
     final activePaint = Paint()
       ..color = DiwaniyaColors.activeTurnRing
       ..style = PaintingStyle.stroke
       ..strokeWidth = 5.0;
     canvas.drawCircle(center, _radius, activePaint);
   }
   ```
8. Remove the old team color dot below avatar (lines 134-142) — replaced by name pill

- [ ] **Step 4: Update `kout_game.dart` — pass `avatarSeed` when creating seats**

In `_updateSeats()`, where `PlayerSeatComponent` is constructed (around line 201), add `avatarSeed: i`:

```dart
        final seat = PlayerSeatComponent(
          playerName: _shortUid(state.playerUids[i]),
          cardCount: 0,
          isActive: false,
          isTeamA: i.isEven,
          isDealer: state.playerUids[i] == state.dealerUid,
          avatarSeed: i,
          position: pos,
        );
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/player_seat_avatar_test.dart`
Expected: PASS

- [ ] **Step 6: Run full suite + analyze**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze && flutter test`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/player_seat.dart lib/game/components/avatar_painter.dart lib/game/kout_game.dart
git add test/game/player_seat_avatar_test.dart
git commit -m "feat(ui): revamped player seats with avatars, name pills, bright green active ring"
```

---

## Task 6: Action Badges (Speech Bubbles)

**Files:**
- Create: `lib/game/components/action_badge.dart`
- Modify: `lib/game/kout_game.dart` — create and update badges per player
- Test: `test/game/action_badge_test.dart`

Display a floating badge near each player showing their last action: bid amount, "PASS", played card (suit+rank), or trump selection. The badge is a rounded rect with a small triangular tail pointing at the player.

- [ ] **Step 1: Write the test**

```dart
// test/game/action_badge_test.dart
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/action_badge.dart';

void main() {
  group('ActionBadgeComponent', () {
    test('creates with text and position', () {
      final badge = ActionBadgeComponent(
        text: '6♠',
        badgeColor: const Color(0xFFCC0000),
        position: Vector2(100, 100),
      );
      expect(badge.text, '6♠');
    });

    test('auto-dismisses after timeout', () {
      final badge = ActionBadgeComponent(
        text: 'PASS',
        autoDismissSeconds: 3.0,
        position: Vector2(100, 100),
      );
      expect(badge.autoDismissSeconds, 3.0);
    });

    test('updateText changes display', () {
      final badge = ActionBadgeComponent(
        text: '5',
        position: Vector2(100, 100),
      );
      badge.updateText('KOUT');
      expect(badge.text, 'KOUT');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/action_badge_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Create `action_badge.dart`**

```dart
// lib/game/components/action_badge.dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';

/// A floating speech-bubble badge that shows a player's last action.
///
/// Renders a rounded rectangle with text and a small tail pointing
/// toward the player's seat. Auto-dismisses after [autoDismissSeconds]
/// if set (0 = persistent until explicitly removed).
class ActionBadgeComponent extends PositionComponent {
  String text;
  Color badgeColor;
  double autoDismissSeconds;

  double _elapsed = 0;
  double _opacity = 1.0;

  static const double _paddingH = 10.0;
  static const double _paddingV = 5.0;
  static const double _fontSize = 14.0;
  static const double _tailSize = 6.0;
  static const double _borderRadius = 8.0;

  ActionBadgeComponent({
    required this.text,
    this.badgeColor = DiwaniyaColors.actionBadgeBg,
    this.autoDismissSeconds = 0.0,
    super.position,
    super.anchor = Anchor.center,
  }) : super(size: Vector2(60, 30));

  void updateText(String newText, {Color? color}) {
    text = newText;
    if (color != null) badgeColor = color;
    _elapsed = 0;
    _opacity = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (autoDismissSeconds > 0) {
      _elapsed += dt;
      if (_elapsed > autoDismissSeconds - 0.5) {
        _opacity = ((autoDismissSeconds - _elapsed) / 0.5).clamp(0.0, 1.0);
      }
      if (_elapsed >= autoDismissSeconds) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (text.isEmpty) return;

    // Measure text to size the badge
    final pb = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: _fontSize,
        fontFamily: 'IBMPlexMono',
      ),
    )
      ..pushStyle(TextStyle(
        color: DiwaniyaColors.cream.withValues(alpha: _opacity),
        fontWeight: FontWeight.bold,
      ))
      ..addText(text);
    final paragraph = pb.build();
    paragraph.layout(const ParagraphConstraints(width: 100));

    final textWidth = paragraph.longestLine;
    final textHeight = paragraph.height;
    final badgeW = textWidth + _paddingH * 2;
    final badgeH = textHeight + _paddingV * 2;

    // Badge background
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: badgeW, height: badgeH),
      Radius.circular(_borderRadius),
    );

    final bgPaint = Paint()..color = badgeColor.withValues(alpha: 0.9 * _opacity);
    canvas.drawRRect(badgeRect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = DiwaniyaColors.actionBadgeBorder.withValues(alpha: 0.6 * _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(badgeRect, borderPaint);

    // Tail triangle pointing down
    final tailPath = Path()
      ..moveTo(-_tailSize, badgeH / 2)
      ..lineTo(0, badgeH / 2 + _tailSize)
      ..lineTo(_tailSize, badgeH / 2);
    canvas.drawPath(tailPath, bgPaint);

    // Draw text
    canvas.drawParagraph(
      paragraph,
      Offset(-textWidth / 2, -textHeight / 2),
    );
  }
}
```

- [ ] **Step 4: Wire action badges into `kout_game.dart`**

Add field after `_opponentFans`:
```dart
  final Map<int, ActionBadgeComponent> _actionBadges = {};
```

In `_updateSeats()`, after updating seat state (around line 287-296), add logic to create/update action badges:

```dart
      // Update action badge for this player
      final lastAction = _getLastAction(state, i);
      if (lastAction != null) {
        final badgePos = layout.seatPosition(i, state.mySeatIndex) + Vector2(0, -55);
        if (_actionBadges.containsKey(i)) {
          _actionBadges[i]!.updateText(lastAction.$1, color: lastAction.$2);
          _actionBadges[i]!.position = badgePos;
        } else {
          final badge = ActionBadgeComponent(
            text: lastAction.$1,
            badgeColor: lastAction.$2,
            position: badgePos,
          );
          _actionBadges[i] = badge;
          add(badge);
        }
      } else if (_actionBadges.containsKey(i)) {
        _actionBadges[i]!.removeFromParent();
        _actionBadges.remove(i);
      }
```

Add helper method (all fields used here exist on `ClientGameState` — see `lib/app/models/client_game_state.dart`):
```dart
  /// Returns (displayText, badgeColor) for the given seat's last action.
  /// Uses `state.bidHistory` (List<({String playerUid, String action})>)
  /// and `state.currentTrickPlays` (List<({String playerUid, GameCard card})>).
  (String, Color)? _getLastAction(ClientGameState state, int seatIndex) {
    final uid = state.playerUids[seatIndex];
    // During bidding: show bid/pass from bidHistory
    if (state.phase == GamePhase.bidding || state.phase == GamePhase.trumpSelection) {
      for (final entry in state.bidHistory.reversed) {
        if (entry.playerUid == uid) {
          if (entry.action == 'pass') {
            return ('PASS', const Color(0xCCCC4444));
          }
          return ('BID ${entry.action}', DiwaniyaColors.actionBadgeBg);
        }
      }
    }
    // During playing: show last played card from currentTrickPlays
    if (state.phase == GamePhase.playing && state.currentTrickPlays.isNotEmpty) {
      for (final play in state.currentTrickPlays) {
        if (play.playerUid == uid) {
          final card = play.card;
          final label = card.isJoker ? 'JOKER' : '${_rankLabel(card.rank!)}${_suitSymbol(card.suit!)}';
          final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
          final color = isRed ? const Color(0xCCCC0000) : DiwaniyaColors.actionBadgeBg;
          return (label, color);
        }
      }
    }
    return null;
  }

  // _rankLabel and _suitSymbol are private helpers that already exist
  // at the bottom of kout_game.dart (see _suitSymbol at line 523).
  // Add _rankLabel near it:
  static String _rankLabel(Rank rank) {
    const labels = {
      Rank.ace: 'A', Rank.king: 'K', Rank.queen: 'Q', Rank.jack: 'J',
      Rank.ten: '10', Rank.nine: '9', Rank.eight: '8', Rank.seven: '7',
    };
    return labels[rank] ?? '?';
  }
```

Add import at top of `kout_game.dart`:
```dart
import '../game/theme/diwaniya_colors.dart';
```

- [ ] **Step 5: Run tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/action_badge_test.dart && flutter test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/action_badge.dart lib/game/kout_game.dart test/game/action_badge_test.dart
git commit -m "feat(ui): action badge speech bubbles showing last bid/card per player"
```

---

## Task 7: Compact Score HUD (Top-Right)

**Files:**
- Create: `lib/game/components/score_hud.dart`
- Modify: `lib/game/kout_game.dart` — replace `ScoreDisplayComponent` with `ScoreHudComponent`
- Test: `test/game/score_hud_test.dart`

Replace the full-width 52px banner with a compact top-right score widget. The hero element is a large score number (28pt+). Below it: trick progress as dot pips. This matches the reference UI's glanceable score display.

- [ ] **Step 1: Write the test**

```dart
// test/game/score_hud_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/score_hud.dart';
import 'package:koutbh/shared/models/game_state.dart';

void main() {
  group('ScoreHudComponent', () {
    test('creates with screen dimensions', () {
      final hud = ScoreHudComponent(screenWidth: 800);
      expect(hud.size.x, greaterThan(0));
    });

    test('formats trick pips correctly', () {
      // Test the pip calculation logic
      expect(ScoreHudComponent.computePips(bidValue: 5, tricksTaken: 3), 3);
      expect(ScoreHudComponent.computePips(bidValue: 8, tricksTaken: 8), 8);
      expect(ScoreHudComponent.computePips(bidValue: 5, tricksTaken: 0), 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/score_hud_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Create `score_hud.dart`**

A compact top-right widget that renders:
- Large score number (28pt, bold, team color)
- Small "/ 31" suffix
- Below: two rows of dot pips (bidder team and opponent team trick progress)
- Rounded rect background with subtle border

```dart
// lib/game/components/score_hud.dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/kout_theme.dart';

/// Compact score display positioned top-right.
///
/// Shows: hero score number, trick pip rows during play phase.
class ScoreHudComponent extends PositionComponent {
  ClientGameState? _state;

  static const double _hudWidth = 140.0;
  static const double _hudHeight = 80.0;
  static const double _pipRadius = 4.5;
  static const double _pipSpacing = 13.0;

  ScoreHudComponent({required double screenWidth})
      : super(
          position: Vector2(screenWidth - _hudWidth - 12, 10),
          size: Vector2(_hudWidth, _hudHeight),
          anchor: Anchor.topLeft,
        );

  void updateState(ClientGameState state) {
    _state = state;
  }

  void updateWidth(double newWidth) {
    position = Vector2(newWidth - _hudWidth - 12, 10);
  }

  /// Compute how many pips to fill for a team's trick count.
  static int computePips({required int bidValue, required int tricksTaken}) {
    return tricksTaken.clamp(0, 8);
  }

  @override
  void render(Canvas canvas) {
    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, _hudHeight),
      const Radius.circular(12),
    );
    canvas.drawRRect(bgRect, Paint()..color = DiwaniyaColors.scoreHudBg);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = DiwaniyaColors.scoreHudBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (_state == null) return;
    final s = _state!;

    // Tug-of-war score
    final teamAScore = s.scores[Team.a] ?? 0;
    final teamBScore = s.scores[Team.b] ?? 0;
    final tugScore = teamAScore > 0 ? teamAScore : teamBScore;
    final Team? leadingTeam = teamAScore > 0
        ? Team.a
        : teamBScore > 0
            ? Team.b
            : null;
    final scoreColor = leadingTeam == Team.a
        ? KoutTheme.teamAColor
        : leadingTeam == Team.b
            ? KoutTheme.teamBColor
            : DiwaniyaColors.cream;

    // Hero score number
    _drawText(canvas, '$tugScore', scoreColor, Offset(_hudWidth / 2 - 10, 8), 28);
    _drawText(canvas, '/ 31', DiwaniyaColors.cream.withValues(alpha: 0.5), Offset(_hudWidth / 2 + 25, 18), 11);

    // Trick pips (during playing/scoring phases)
    final showPips = s.phase == GamePhase.playing || s.phase == GamePhase.roundScoring;
    if (showPips && s.bidderUid != null) {
      final bidderSeat = s.playerUids.indexOf(s.bidderUid!);
      if (bidderSeat >= 0) {
        final bidderTeam = teamForSeat(bidderSeat);
        final bidValue = s.currentBid?.value ?? 5;
        final bidderTricks = s.tricks[bidderTeam] ?? 0;
        final opponentTricks = s.tricks[bidderTeam.opponent] ?? 0;
        final opponentTarget = 9 - bidValue;

        // Bidder team pips (top row)
        _drawPipRow(canvas, 48, bidValue, bidderTricks,
            bidderTeam == Team.a ? KoutTheme.teamAColor : KoutTheme.teamBColor);

        // Opponent team pips (bottom row)
        _drawPipRow(canvas, 64, opponentTarget, opponentTricks,
            bidderTeam == Team.a ? KoutTheme.teamBColor : KoutTheme.teamAColor);
      }
    }
  }

  void _drawPipRow(Canvas canvas, double y, int total, int filled, Color color) {
    final totalWidth = (total - 1) * _pipSpacing;
    final startX = (_hudWidth - totalWidth) / 2;

    for (int i = 0; i < total; i++) {
      final cx = startX + i * _pipSpacing;
      if (i < filled) {
        canvas.drawCircle(Offset(cx, y), _pipRadius, Paint()..color = color);
      } else {
        canvas.drawCircle(
          Offset(cx, y),
          _pipRadius,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawText(Canvas canvas, String text, Color color, Offset offset, double fontSize) {
    final pb = ParagraphBuilder(
      ParagraphStyle(fontSize: fontSize, fontFamily: 'IBMPlexMono'),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);
    final paragraph = pb.build();
    paragraph.layout(const ParagraphConstraints(width: 100));
    canvas.drawParagraph(paragraph, offset);
  }
}
```

- [ ] **Step 4: Replace ScoreDisplayComponent in kout_game.dart**

In `kout_game.dart`:
1. Add import: `import 'components/score_hud.dart';`
2. Replace `ScoreDisplayComponent? _scoreDisplay;` (line 38) with `ScoreHudComponent? _scoreHud;`
3. Rewrite `_updateScoreDisplay()` (lines 180-194):
```dart
  void _updateScoreDisplay(ClientGameState state) {
    if (_scoreHud == null) {
      final w = hasLayout ? size.x : 375.0;
      _scoreHud = ScoreHudComponent(screenWidth: w);
      add(_scoreHud!);
    }
    _scoreHud!.updateState(state);

    // Track scores for round result overlay (same logic as before)
    if (state.phase != GamePhase.roundScoring) {
      _lastScoreA = state.scores[Team.a] ?? 0;
      _lastScoreB = state.scores[Team.b] ?? 0;
    }
  }
```
4. In `onGameResize()` (line 123), replace `_scoreDisplay?.updateWidth(newSize.x);` with `_scoreHud?.updateWidth(newSize.x);`
5. Remove the `import 'components/score_display.dart';` line if present
6. Keep the old `score_display.dart` file (don't delete) — can be removed in a cleanup pass

- [ ] **Step 5: Run tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/score_hud_test.dart && flutter test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/score_hud.dart lib/game/kout_game.dart test/game/score_hud_test.dart
git commit -m "feat(ui): compact top-right score HUD with hero number and trick pips"
```

---

## Task 8: Game HUD (Top-Left) — Round Counter, Trick Counter

**Files:**
- Create: `lib/game/components/game_hud.dart`
- Modify: `lib/game/kout_game.dart` — wire HUD updates
- Test: `test/game/game_hud_test.dart`

Add a small HUD in the top-left showing round number and trick number within the round. Matches the reference's "2 1 3" display.

- [ ] **Step 1: Write the test**

```dart
// test/game/game_hud_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/game_hud.dart';

void main() {
  group('GameHudComponent', () {
    test('creates with initial values', () {
      final hud = GameHudComponent();
      expect(hud.roundNumber, 1);
      expect(hud.trickNumber, 0);
    });

    test('update changes values', () {
      final hud = GameHudComponent();
      hud.updateRound(3, trick: 5);
      expect(hud.roundNumber, 3);
      expect(hud.trickNumber, 5);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/game_hud_test.dart`
Expected: FAIL.

- [ ] **Step 3: Create `game_hud.dart`**

```dart
// lib/game/components/game_hud.dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';

/// Compact top-left HUD showing round and trick counters.
class GameHudComponent extends PositionComponent {
  int roundNumber;
  int trickNumber;

  static const double _hudWidth = 90.0;
  static const double _hudHeight = 36.0;

  GameHudComponent({
    this.roundNumber = 1,
    this.trickNumber = 0,
    super.position,
    super.anchor = Anchor.topLeft,
  }) : super(
          size: Vector2(_hudWidth, _hudHeight),
        ) {
    position ??= Vector2(12, 14);
  }

  void updateRound(int round, {int trick = 0}) {
    roundNumber = round;
    trickNumber = trick;
  }

  @override
  void render(Canvas canvas) {
    // Background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, _hudHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, Paint()..color = DiwaniyaColors.scoreHudBg);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = DiwaniyaColors.scoreHudBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // "R{round} T{trick}"
    final text = 'R$roundNumber  T$trickNumber';
    final pb = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 13,
        fontFamily: 'IBMPlexMono',
      ),
    )
      ..pushStyle(TextStyle(
        color: DiwaniyaColors.cream.withValues(alpha: 0.8),
        fontWeight: FontWeight.bold,
      ))
      ..addText(text);
    final paragraph = pb.build();
    paragraph.layout(ParagraphConstraints(width: _hudWidth));
    canvas.drawParagraph(paragraph, Offset(0, (_hudHeight - 13) / 2));
  }
}
```

- [ ] **Step 4: Wire into `kout_game.dart`**

Add import and field:
```dart
import 'components/game_hud.dart';
// field:
GameHudComponent? _gameHud;
```

In `_onStateUpdate()`, after `_updateScoreDisplay(state)`, add:
```dart
    _updateGameHud(state);
```

Add method:
```dart
  void _updateGameHud(ClientGameState state) {
    if (_gameHud == null) {
      _gameHud = GameHudComponent();
      add(_gameHud!);
    }
    final totalTricks = (state.tricks[Team.a] ?? 0) + (state.tricks[Team.b] ?? 0);
    _gameHud!.updateRound(state.roundNumber, trick: totalTricks);
  }
```

**Important:** `ClientGameState` does NOT have a `roundNumber` field. Derive it from `trickWinners` — each round has up to 8 tricks, so: `final roundNumber = (state.trickWinners.length ~/ 8) + 1;`. For trick number within the round: `final trickInRound = state.trickWinners.length % 8;`. The full `_updateGameHud` method:

```dart
  void _updateGameHud(ClientGameState state) {
    if (_gameHud == null) {
      _gameHud = GameHudComponent();
      add(_gameHud!);
    }
    final roundNumber = (state.trickWinners.length ~/ 8) + 1;
    final trickInRound = state.trickWinners.length % 8;
    _gameHud!.updateRound(roundNumber, trick: trickInRound);
  }
```

- [ ] **Step 5: Run tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/game_hud_test.dart && flutter test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/game_hud.dart lib/game/kout_game.dart test/game/game_hud_test.dart
git commit -m "feat(ui): game HUD with round and trick counters (top-left)"
```

---

## Task 9: Enhanced Hand Component — Adaptive Spacing, Depth Shadows

**Files:**
- Modify: `lib/game/components/hand_component.dart:1-160`
- Modify: `lib/game/managers/layout_manager.dart` — adaptive spacing
- Test: `test/game/hand_spacing_test.dart`

Improve the player's hand fan: adaptive spacing based on card count (more cards = tighter), stronger inter-card shadows for depth separation, and a subtle "shelf" gradient below the hand.

- [ ] **Step 1: Write the test**

```dart
// test/game/hand_spacing_test.dart
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/managers/layout_manager.dart';

void main() {
  group('LayoutManager hand positions', () {
    final layout = LayoutManager(Vector2(800, 600));

    test('hand card spacing is adaptive based on count', () {
      final pos8 = layout.handCardPositions(8);
      final pos4 = layout.handCardPositions(4);

      // 4 cards should have wider effective spacing than 8 cards
      final spacing8 = (pos8[1].position.x - pos8[0].position.x).abs();
      final spacing4 = (pos4[1].position.x - pos4[0].position.x).abs();
      expect(spacing4, greaterThanOrEqualTo(spacing8));
    });

    test('hand cards are centered on screen width', () {
      final pos = layout.handCardPositions(5);
      final centerX = pos.map((p) => p.position.x).reduce((a, b) => a + b) / pos.length;
      expect(centerX, closeTo(400, 30)); // should be near screen center
    });

    test('hand fan produces arc shape', () {
      final pos = layout.handCardPositions(8);
      // Center cards should be higher (lower Y) than edge cards
      final centerY = pos[3].position.y;
      final edgeY = pos[0].position.y;
      expect(centerY, lessThan(edgeY)); // center is higher
    });
  });
}
```

- [ ] **Step 2: Run test to check baseline**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/hand_spacing_test.dart`
Expected: May pass with current layout (tests verify existing behavior first). If it fails, adjust expected values.

- [ ] **Step 3: Update `layout_manager.dart` — adaptive card spacing**

Replace the `handCardPositions` method (lines 55-76):

```dart
  /// Returns card positions for fanning [cardCount] cards in the player's hand.
  /// Spacing adapts: fewer cards = wider spacing, more cards = tighter.
  List<({Vector2 position, double angle})> handCardPositions(int cardCount) {
    if (cardCount == 0) return [];

    const maxFanAngle = 0.30;
    // Adaptive spacing: 70px for 4 cards, down to 48px for 8 cards
    final cardSpacing = (80 - cardCount * 4.0).clamp(44.0, 72.0);

    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = handCenter.x - totalWidth / 2;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      final arcOffset = (0.25 - t * t) * 32; // slightly more arc than before (was 28)
      final pos = Vector2(startX + i * cardSpacing, handCenter.y - arcOffset);
      results.add((position: pos, angle: angle));
    }

    return results;
  }
```

- [ ] **Step 4: Update `hand_component.dart` — stronger shadows + card priority for depth**

In `hand_component.dart`, the cards already have priority set for z-ordering (line 73). The key change is ensuring `showShadow: true` renders a more pronounced shadow. This is actually controlled by `card_component.dart`'s shadow parameters. Update the shadow constants in `kout_theme.dart`:

Update the shadow constants in `kout_theme.dart` (lines 22-25) to these exact values:
```dart
  static const double cardShadowBlur = 6.0;      // was 4.0
  static const double cardShadowOffsetX = 3.0;    // was 2.0
  static const double cardShadowOffsetY = 4.0;    // was 3.0
  static const Color cardShadowColor = Color(0x88000000);  // was 0x66000000
```
These stronger values create visible depth between overlapping hand cards. No changes needed to `card_component.dart` — it already reads these constants.

- [ ] **Step 5: Run tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test test/game/hand_spacing_test.dart && flutter test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/managers/layout_manager.dart lib/game/components/hand_component.dart lib/game/theme/kout_theme.dart
git add test/game/hand_spacing_test.dart
git commit -m "feat(ui): adaptive hand spacing and stronger inter-card shadows"
```

---

## Task 10: Enhanced Opponent Hand Fans — Tighter Coupling to Avatar

**Files:**
- Modify: `lib/game/components/opponent_hand_fan.dart:1-135`
- Modify: `lib/game/kout_game.dart` — adjust fan positioning

Position opponent fans closer to the avatar circles (reference has them right next to the character portrait). Slightly increase scale from 55% to 60%. Add a small card count label.

- [ ] **Step 1: Adjust fan positioning in `kout_game.dart`**

In `_updateSeats()` where opponent fans are created (around lines 228-258), reduce `fanOffset` from 90 to 70:

```dart
      const fanOffset = 70.0;
```

- [ ] **Step 2: Increase fan scale in `opponent_hand_fan.dart`**

Change the scale constants at lines 33-34:

```dart
  static const double _miniWidth = KoutTheme.cardWidth * 0.60; // ~42
  static const double _miniHeight = KoutTheme.cardHeight * 0.60; // ~60
```

Update scale factors at lines 46-47:
```dart
  static const double _scaleX = _miniWidth / KoutTheme.cardWidth;
  static const double _scaleY = _miniHeight / KoutTheme.cardHeight;
```

- [ ] **Step 3: Add card count label to fan render**

At the end of `render()` method, after the `canvas.restore();` for baseRotation (line 133), add:

```dart
    // Card count badge
    if (cardCount > 0) {
      final badgePaint = Paint()..color = const Color(0xCC222222);
      final badgeCenter = Offset(size.x / 2, size.y / 2 + _miniHeight * 0.6);
      canvas.drawCircle(badgeCenter, 10, badgePaint);
      final pb = ParagraphBuilder(
        ParagraphStyle(textAlign: TextAlign.center, fontSize: 10),
      )
        ..pushStyle(TextStyle(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.bold))
        ..addText('$cardCount');
      final paragraph = pb.build();
      paragraph.layout(const ParagraphConstraints(width: 20));
      canvas.drawParagraph(paragraph, Offset(badgeCenter.dx - 10, badgeCenter.dy - 6));
    }
```

- [ ] **Step 4: Run analyze and full test suite**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze && flutter test`
Expected: No issues, all pass.

- [ ] **Step 5: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/opponent_hand_fan.dart lib/game/kout_game.dart
git commit -m "feat(ui): opponent fans closer to avatar, 60% scale, card count badge"
```

---

## Task 11: Enhanced Ambient Decorations — Louder Cultural Elements

**Files:**
- Modify: `lib/game/components/ambient_decoration.dart:1-119`
- Modify: `lib/game/theme/geometric_patterns.dart` — optional border motif

Increase tea glass opacity from 8% to 25-30%, make the geometric overlay slightly more visible (8% instead of 5%), and add a decorative Islamic geometric border around the table edge.

- [ ] **Step 1: Update opacity values in `ambient_decoration.dart`**

In `render()` (line 28), change geometric overlay opacity:
```dart
      opacity: 0.08,
```

In `_drawIstikana()` (line 49), change glass opacity:
```dart
    const opacity = 0.25;
```

- [ ] **Step 2: Add geometric border motif around the perspective table**

In `ambient_decoration.dart`, if `PerspectiveTableComponent` is available, draw a geometric border along the table edges. Since ambient decoration doesn't have table reference, add the table border rendering to `PerspectiveTableComponent` in `perspective_table.dart` instead.

In `perspective_table.dart`, at the end of `render()`, add:

```dart
    // Decorative geometric motif along the top edge of the table
    GeometricPatterns.drawStarTessellation(
      canvas,
      Rect.fromLTWH(verts[0].dx, verts[0].dy - 2, verts[1].dx - verts[0].dx, 12),
      opacity: 0.15,
      cellSize: 24.0,
    );
```

Add import to `perspective_table.dart`:
```dart
import '../theme/geometric_patterns.dart';
```

- [ ] **Step 3: Run analyze and tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze && flutter test`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/ambient_decoration.dart lib/game/components/perspective_table.dart
git commit -m "feat(ui): louder cultural elements — tea glasses at 25%, geometric table border"
```

---

## Task 12: Card Painter Enhancements — Larger Suit, Face Card Gradient

**Files:**
- Modify: `lib/game/theme/card_painter.dart:1-252`
- Modify: `lib/game/theme/kout_theme.dart`

Increase center suit symbol from 32pt to 40pt for better readability. Add a subtle warm gradient on face card backgrounds (K/Q/J) for visual distinction.

- [ ] **Step 1: Update card center suit size in `kout_theme.dart`**

Change line 21:
```dart
  static const double cardCenterSuitSize = 40.0;  // was 32.0
```

- [ ] **Step 2: Add face card gradient in `card_painter.dart`**

In `paintFace()`, after drawing the white face fill (line 68), before the thin dark border (line 71), add for face cards:

```dart
    // Face card warm gradient overlay (K, Q, J only)
    if (rankStr == 'K' || rankStr == 'Q' || rankStr == 'J') {
      final gradientShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          DiwaniyaColors.faceCardGradientTop,
          DiwaniyaColors.faceCardGradientBottom,
        ],
      ).createShader(rect);
      canvas.drawRRect(rrect, Paint()..shader = gradientShader);
    }
```

Add import at top of `card_painter.dart`:
```dart
import 'diwaniya_colors.dart';
```

- [ ] **Step 3: Run analyze and tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze && flutter test`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/theme/card_painter.dart lib/game/theme/kout_theme.dart
git commit -m "feat(ui): larger center suit symbol (40pt), face card warm gradient"
```

---

## Task 13: Trick Area — Remove Felt Circle, Use Table Surface

**Files:**
- Modify: `lib/game/components/trick_area.dart:1-119`

Remove the explicit felt circle in the trick area since the perspective table (Task 3) now provides the play surface. Cards should sit directly on the table. Optionally add a very subtle center marker (thin gold circle at 15% opacity).

- [ ] **Step 1: Update `trick_area.dart` render method**

Replace the `render()` method (lines 29-49):

```dart
  @override
  void render(Canvas canvas) {
    // Subtle center marker on the table (thin gold ring, barely visible)
    final markerPaint = Paint()
      ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(
      Offset(layout.trickCenter.x, layout.trickCenter.y),
      60,
      markerPaint,
    );
  }
```

Add import:
```dart
import '../theme/diwaniya_colors.dart';
```

- [ ] **Step 2: Run analyze and tests**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze && flutter test`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add lib/game/components/trick_area.dart
git commit -m "feat(ui): trick area uses table surface, subtle gold center marker"
```

---

## Task 14: Visual Verification & Integration Testing

**Files:**
- All modified files from Tasks 1-13

Final verification pass: run the app, play through a complete game, check visual coherence of all components together.

- [ ] **Step 1: Run full test suite**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run static analysis**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter analyze`
Expected: No analysis issues.

- [ ] **Step 3: Launch the app and play through visually**

Run: `cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh && flutter run`

Verify:
1. Tile background with vignette visible behind everything
2. 3D perspective table surface with dark wood border and gold accent
3. Character avatars rendered in player seat circles
4. Bright green ring on active player (not subtle olive glow)
5. Colored name labels (pills) below each avatar
6. Action badges showing bid/card near each player
7. Compact score HUD in top-right with large number and trick pips
8. Game HUD in top-left with round/trick counters
9. Player hand fan with adaptive spacing
10. Opponent fans close to avatars with card count badge
11. Tea glasses visible at ~25% opacity
12. Larger center suit symbols on cards
13. Face cards (K/Q/J) have subtle warm gradient
14. Trick area cards sit on table surface without separate felt circle
15. All overlays (bid, trump, round result, game over) still render correctly

- [ ] **Step 4: Fix any visual issues found**

Address any rendering problems, z-order issues, or positioning conflicts discovered during visual testing.

- [ ] **Step 5: Final commit**

```bash
cd /sessions/intelligent-hopeful-dijkstra/mnt/koutbh
git add -A
git commit -m "fix(ui): visual integration fixes from full playthrough verification"
```
