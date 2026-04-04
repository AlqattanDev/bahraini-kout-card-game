# iOS Landscape Layout Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix iPhone landscape layout with safe area handling, no avatars, no table, adaptive card scaling — without touching portrait mode.

**Architecture:** Add `EdgeInsets safeArea` and `isLandscape` branch to `LayoutManager`. In landscape, all positions are percentage-based within a safe rect. Portrait path is untouched. `PlayerSeatComponent` and `PerspectiveTableComponent` are hidden in landscape; opponents shown as lightweight name labels rendered directly in `KoutGame`.

**Tech Stack:** Flutter/Flame (Dart), no new dependencies.

---

### Task 1: Orientation Lock in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add orientation lock logic**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock iPhone to landscape. iPad/macOS/other: unrestricted.
  if (Platform.isIOS) {
    // Use shortestSide heuristic at startup — phones < 500, tablets >= 500.
    // This runs before the first frame, so we use the physical size.
    final physicalSize = PlatformDispatcher.instance.views.first.physicalSize;
    final devicePixelRatio = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final shortestSide = (physicalSize.shortestSide / devicePixelRatio);
    if (shortestSide < 500) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  runApp(const KoutApp());
}
```

- [ ] **Step 2: Run on iOS simulator to verify landscape lock**

Run: `flutter run -d <ios-simulator-id>`
Expected: App opens in landscape, cannot rotate to portrait.

- [ ] **Step 3: Run on macOS to verify no orientation change**

Run: `flutter run -d macos`
Expected: App opens normally, no orientation restrictions.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: lock iPhone to landscape orientation"
```

---

### Task 2: Pass Safe Area Insets from GameScreen to KoutGame

**Files:**
- Modify: `lib/app/screens/game_screen.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Add safeArea field to KoutGame**

In `lib/game/kout_game.dart`, add a field and setter after the existing fields (around line 43):

```dart
/// Safe area insets from the Flutter widget layer.
EdgeInsets _safeArea = EdgeInsets.zero;

void updateSafeArea(EdgeInsets insets) {
  _safeArea = insets;
  // Re-create layout with new insets
  if (hasLayout) {
    layout = LayoutManager(size, safeArea: _safeArea);
    _unifiedHud?.updateWidth(size.x);
    _perspectiveTable?.updateLayout(layout);
  }
}
```

Add `import 'package:flutter/painting.dart';` at the top (for `EdgeInsets`).

Update `onLoad` (line 99) to pass safeArea:

```dart
layout = LayoutManager(safeSize, safeArea: _safeArea);
```

Update `onGameResize` (line 131):

```dart
@override
void onGameResize(Vector2 size) {
  super.onGameResize(size);
  layout = LayoutManager(size, safeArea: _safeArea);
  _unifiedHud?.updateWidth(size.x);
  _perspectiveTable?.updateLayout(layout);
}
```

- [ ] **Step 2: Pass safe area from GameScreen**

In `lib/app/screens/game_screen.dart`, wrap the `GameWidget` in a `LayoutBuilder` + `Builder` to read `MediaQuery.padding` and pass it to the game. Replace the `build` method body (starting at line 121):

```dart
@override
Widget build(BuildContext context) {
  if (_koutGame == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // Read safe area insets and pass to game engine
  final padding = MediaQuery.of(context).padding;
  _koutGame!.updateSafeArea(padding);

  return Scaffold(
    body: Stack(
      children: [
        GameWidget(
          game: _koutGame!,
          overlayBuilderMap: {
            // ... (unchanged overlay map)
```

The rest of the build method stays identical.

- [ ] **Step 3: Verify it compiles and runs**

Run: `flutter run -d macos`
Expected: No behavior change — macOS has zero insets so layout is identical.

- [ ] **Step 4: Commit**

```bash
git add lib/game/kout_game.dart lib/app/screens/game_screen.dart
git commit -m "feat: pass safe area insets from GameScreen to KoutGame"
```

---

### Task 3: Add Landscape Branch to LayoutManager

**Files:**
- Modify: `lib/game/managers/layout_manager.dart`
- Modify: `test/game/hand_spacing_test.dart`

- [ ] **Step 1: Write tests for landscape layout**

Add to `test/game/hand_spacing_test.dart`:

```dart
group('LayoutManager landscape mode', () {
  // iPhone 15 Pro landscape: 852x393, safe area 59/59/0/21
  final landscapeLayout = LayoutManager(
    Vector2(852, 393),
    safeArea: const EdgeInsets.only(left: 59, right: 59, bottom: 21),
  );

  test('isLandscape is true when width > height', () {
    expect(landscapeLayout.isLandscape, isTrue);
  });

  test('safeRect excludes insets', () {
    expect(landscapeLayout.safeRect.left, 59);
    expect(landscapeLayout.safeRect.right, 852 - 59);
    expect(landscapeLayout.safeRect.bottom, 393 - 21);
    expect(landscapeLayout.safeRect.top, 0);
  });

  test('hand center is within safe rect horizontally', () {
    final hc = landscapeLayout.handCenter;
    expect(hc.x, greaterThan(landscapeLayout.safeRect.left));
    expect(hc.x, lessThan(landscapeLayout.safeRect.right));
  });

  test('trick center is within safe rect', () {
    final tc = landscapeLayout.trickCenter;
    expect(tc.x, greaterThan(landscapeLayout.safeRect.left));
    expect(tc.x, lessThan(landscapeLayout.safeRect.right));
    expect(tc.y, greaterThan(landscapeLayout.safeRect.top));
    expect(tc.y, lessThan(landscapeLayout.safeRect.bottom));
  });

  test('handCardScale is smaller on landscape phone', () {
    expect(landscapeLayout.handCardScale, lessThan(1.4));
    expect(landscapeLayout.handCardScale, greaterThan(0.5));
  });

  test('portrait layout is unchanged when no safe area', () {
    final portrait = LayoutManager(Vector2(800, 600));
    expect(portrait.isLandscape, isFalse);
    expect(portrait.handCenter, Vector2(400, 520));
    expect(portrait.handCardScale, 1.4);
  });
});
```

Add `import 'package:flutter/painting.dart';` at the top of the test file.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/game/hand_spacing_test.dart`
Expected: FAIL — `LayoutManager` doesn't accept `safeArea` param yet.

- [ ] **Step 3: Implement landscape branch in LayoutManager**

Replace `lib/game/managers/layout_manager.dart` entirely:

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

/// Calculates positions and angles for all game elements based on screen size.
/// Seat indices: 0=bottom (me), 1=left, 2=top (partner), 3=right.
class LayoutManager {
  final Vector2 screenSize;
  final EdgeInsets safeArea;

  LayoutManager(this.screenSize, {this.safeArea = EdgeInsets.zero});

  double get width => screenSize.x;
  double get height => screenSize.y;

  bool get isLandscape => width > height;

  /// The usable screen rect after subtracting safe area insets.
  Rect get safeRect => Rect.fromLTRB(
        safeArea.left,
        safeArea.top,
        width - safeArea.right,
        height - safeArea.bottom,
      );

  double get _safeWidth => safeRect.width;
  double get _safeHeight => safeRect.height;

  // ---------------------------------------------------------------------------
  // Dynamic card scale
  // ---------------------------------------------------------------------------

  /// Scale factor for hand cards. Smaller on landscape phones, 1.4x on portrait.
  double get handCardScale {
    if (!isLandscape) return 1.4;
    // Scale relative to safe height so cards are ~15% of available height
    return (safeRect.height * 0.15 / 100).clamp(0.6, 1.4);
  }

  // ---------------------------------------------------------------------------
  // Positions — delegates to portrait or landscape
  // ---------------------------------------------------------------------------

  Vector2 get handCenter => isLandscape ? _landscapeHandCenter : _portraitHandCenter;
  Vector2 get mySeat => isLandscape ? _landscapeMySeat : _portraitMySeat;
  Vector2 get partnerSeat => isLandscape ? _landscapePartnerSeat : _portraitPartnerSeat;
  Vector2 get leftSeat => isLandscape ? _landscapeLeftSeat : _portraitLeftSeat;
  Vector2 get rightSeat => isLandscape ? _landscapeRightSeat : _portraitRightSeat;
  Vector2 get trickCenter => isLandscape ? _landscapeTrickCenter : _portraitTrickCenter;
  Vector2 get trickTrackerCenter => Vector2(trickCenter.x, trickCenter.y + (isLandscape ? 80 : 130));

  // ---------------------------------------------------------------------------
  // Portrait positions (UNCHANGED from original)
  // ---------------------------------------------------------------------------

  Vector2 get _portraitHandCenter => Vector2(width / 2, height - 80);
  Vector2 get _portraitMySeat => Vector2(width - 60, height - 80);
  Vector2 get _portraitPartnerSeat => Vector2(width / 2, 120);
  Vector2 get _portraitLeftSeat => Vector2(80, height / 2);
  Vector2 get _portraitRightSeat => Vector2(width - 80, height / 2);
  Vector2 get _portraitTrickCenter => Vector2(width / 2, height / 2);

  // ---------------------------------------------------------------------------
  // Landscape positions (safe-area aware)
  // ---------------------------------------------------------------------------

  /// Hand at bottom-center of safe rect
  Vector2 get _landscapeHandCenter {
    final cardH = 100 * handCardScale;
    return Vector2(safeRect.center.dx, safeRect.bottom - cardH / 2 - 8);
  }

  /// Player label at bottom-right of safe rect
  Vector2 get _landscapeMySeat => Vector2(safeRect.right - 50, safeRect.bottom - 20);

  /// Partner label at top-center of safe rect
  Vector2 get _landscapePartnerSeat => Vector2(safeRect.center.dx, safeRect.top + 30);

  /// Left opponent at top-left of safe rect
  Vector2 get _landscapeLeftSeat => Vector2(safeRect.left + 60, safeRect.top + 30);

  /// Right opponent at top-right of safe rect
  Vector2 get _landscapeRightSeat => Vector2(safeRect.right - 60, safeRect.top + 30);

  /// Trick area slightly above center of safe rect
  Vector2 get _landscapeTrickCenter => Vector2(safeRect.center.dx, safeRect.top + _safeHeight * 0.48);

  // ---------------------------------------------------------------------------
  // 3D Perspective table surface geometry (portrait only)
  // ---------------------------------------------------------------------------

  static const double _tableTopWidthRatio = 0.55;
  static const double _tableBottomWidthRatio = 0.85;

  double get _tableTopY => 70.0;
  double get _tableBottomY => height - 130.0;

  List<Offset> get tableVertices {
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

  Offset get tableCenter {
    final v = tableVertices;
    return Offset(
      (v[0].dx + v[1].dx + v[2].dx + v[3].dx) / 4,
      (v[0].dy + v[1].dy + v[2].dy + v[3].dy) / 4,
    );
  }

  /// Position for a trick card played by relative seat index.
  Vector2 trickCardPosition(int relativeSeat) {
    final offset = isLandscape ? 45.0 : 55.0;
    switch (relativeSeat) {
      case 0:
        return trickCenter + Vector2(0, offset);
      case 1:
        return trickCenter + Vector2(-offset, 0);
      case 2:
        return trickCenter + Vector2(0, -offset);
      case 3:
        return trickCenter + Vector2(offset, 0);
      default:
        return trickCenter;
    }
  }

  /// Returns card positions for fanning [cardCount] cards in the player's hand.
  List<({Vector2 position, double angle})> handCardPositions(int cardCount) {
    if (cardCount == 0) return [];

    const maxFanAngle = 0.30;
    final cardSpacing = isLandscape
        ? (60 - cardCount * 3.0).clamp(32.0, 52.0)
        : (80 - cardCount * 4.0).clamp(44.0, 72.0);

    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = handCenter.x - totalWidth / 2;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      final arcBow = isLandscape ? 20.0 : 32.0;
      final arcOffset = (0.25 - t * t) * arcBow;
      final pos = Vector2(startX + i * cardSpacing, handCenter.y - arcOffset);
      results.add((position: pos, angle: angle));
    }

    return results;
  }

  /// Returns the screen position for a given absolute seat index based on myIndex.
  Vector2 seatPosition(int absoluteSeatIndex, int mySeatIndex) {
    final relative = (absoluteSeatIndex - mySeatIndex + 4) % 4;
    switch (relative) {
      case 0:
        return mySeat;
      case 1:
        return leftSeat;
      case 2:
        return partnerSeat;
      case 3:
        return rightSeat;
      default:
        return trickCenter;
    }
  }

  int toRelativeSeat(int absoluteSeatIndex, int mySeatIndex) {
    return (absoluteSeatIndex - mySeatIndex + 4) % 4;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/game/hand_spacing_test.dart`
Expected: All tests PASS including existing portrait tests.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All tests pass. Some tests may need the `safeArea` import added if they construct `LayoutManager` directly.

- [ ] **Step 6: Commit**

```bash
git add lib/game/managers/layout_manager.dart test/game/hand_spacing_test.dart
git commit -m "feat: add landscape branch to LayoutManager with safe area"
```

---

### Task 4: Use Dynamic Card Scale in HandComponent

**Files:**
- Modify: `lib/game/components/hand_component.dart`

- [ ] **Step 1: Replace hardcoded scale with layout.handCardScale**

In `lib/game/components/hand_component.dart`:

Change line 16 from a static const to a getter that reads from layout:

```dart
/// Scale factor applied to hand cards for readability.
/// Dynamic: smaller on landscape phones, full 1.4x on portrait.
double get handCardScale => layout.handCardScale;
```

Remove the `static const double handCardScale = 1.4;` line.

- [ ] **Step 2: Fix the static reference in KoutGame**

In `lib/game/kout_game.dart` line 418, change:

```dart
final sourceScale = isFromHand ? HandComponent.handCardScale : 1.0;
```

to:

```dart
final sourceScale = isFromHand ? (_hand?.handCardScale ?? 1.4) : 1.0;
```

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: All pass. The `handCardScale` is now instance-level, not static.

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/hand_component.dart lib/game/kout_game.dart
git commit -m "feat: use dynamic card scale from LayoutManager in hand"
```

---

### Task 5: Hide Table and Avatars in Landscape

**Files:**
- Modify: `lib/game/kout_game.dart`
- Modify: `lib/game/components/table_background.dart`

- [ ] **Step 1: Make TableBackgroundComponent landscape-aware**

In `lib/game/components/table_background.dart`, add a landscape mode that renders a simple radial gradient instead of the tile texture:

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/textures.dart';

/// Full-screen textured tile background with vignette.
class TableBackgroundComponent extends PositionComponent {
  bool isLandscape = false;

  TableBackgroundComponent() : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    if (isLandscape) {
      // Clean radial green felt gradient for landscape
      final feltShader = Gradient.radial(
        rect.center,
        rect.longestSide * 0.6,
        [const Color(0xFF2d6b3a), const Color(0xFF1e4d2a), const Color(0xFF163d20)],
        [0.0, 0.5, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = feltShader);
      // Warm vignette
      TextureGenerator.drawVignette(canvas, rect);
    } else {
      TextureGenerator.drawTileTexture(canvas, rect);
      TextureGenerator.drawVignette(canvas, rect);
    }
  }
}
```

- [ ] **Step 2: Hide PerspectiveTable, PlayerSeats, AmbientDecoration in landscape**

In `lib/game/kout_game.dart`, update `_onStateUpdate` to toggle visibility. Add a helper method after `_onStateUpdate` (around line 198):

```dart
void _updateLandscapeVisibility() {
  final landscape = layout.isLandscape;

  // Hide perspective table in landscape
  if (_perspectiveTable != null) {
    _perspectiveTable!.opacity = landscape ? 0.0 : 1.0;
  }

  // Hide player seat avatars in landscape
  for (final seat in _seats) {
    seat.opacity = landscape ? 0.0 : 1.0;
  }

  // Hide ambient decoration in landscape
  if (_ambientDecoration != null) {
    _ambientDecoration!.opacity = landscape ? 0.0 : 1.0;
  }

  // Hide opponent fans in landscape (we'll render inline name labels instead)
  for (final fan in _opponentFans.values) {
    fan.opacity = landscape ? 0.0 : 1.0;
  }

  // Update table background mode
  final tableBg = children.whereType<TableBackgroundComponent>().firstOrNull;
  if (tableBg != null) {
    tableBg.isLandscape = landscape;
  }
}
```

Call it at the start of `_onStateUpdate`:

```dart
void _onStateUpdate(ClientGameState state) {
  _updateLandscapeVisibility();
  _updateScoreDisplay(state);
  _updateSeats(state);
  _updateBidderGlow(state);
  _updateHand(state);
  _updateTrickArea(state);
  _updateOverlays(state);
}
```

Also need to make `PerspectiveTableComponent`, `PlayerSeatComponent`, `AmbientDecorationComponent`, and `OpponentHandFan` extend `PositionComponent` with `HasOpacity` mixin (or just use the opacity property which `PositionComponent` already has via the `HasPaint` mixin in Flame — actually `PositionComponent` doesn't have `opacity` by default).

Actually, simpler approach — just don't render when landscape. Add to `_perspectiveTable`:

Instead of using opacity, let's just track a boolean. In `_updateLandscapeVisibility`:

```dart
void _updateLandscapeVisibility() {
  _isLandscape = layout.isLandscape;

  // Update table background mode
  final tableBg = children.whereType<TableBackgroundComponent>().firstOrNull;
  if (tableBg != null) {
    tableBg.isLandscape = _isLandscape;
  }
}
```

And add a field:

```dart
bool _isLandscape = false;
```

Then in `_updateSeats`, guard seat creation and fan creation:

```dart
void _updateSeats(ClientGameState state) {
  if (_seats.isEmpty) {
    for (int i = 0; i < 4; i++) {
      final pos = layout.seatPosition(i, state.mySeatIndex);
      final seat = PlayerSeatComponent(
        playerName: _shortUid(state.playerUids[i]),
        cardCount: 0,
        isActive: false,
        isTeamA: i.isEven,
        avatarSeed: i,
        position: pos,
      );
      _seats.add(seat);
      if (!_isLandscape) add(seat);
    }

    if (!_isLandscape) {
      _ambientDecoration = AmbientDecorationComponent(
        seatPositions: [
          for (int i = 0; i < 4; i++)
            layout.seatPosition(i, state.mySeatIndex),
        ],
      );
      add(_ambientDecoration!);
    }

    const fanOffset = 70.0;
    for (int i = 0; i < 4; i++) {
      if (i == state.mySeatIndex) continue;
      final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
      final seatPos = layout.seatPosition(i, state.mySeatIndex);

      final double rotation;
      final Vector2 offset;
      switch (relativeSeat) {
        case 1:
          rotation = math.pi / 2;
          offset = Vector2(fanOffset, -10);
        case 2:
          rotation = math.pi;
          offset = Vector2(0, fanOffset);
        case 3:
          rotation = -math.pi / 2;
          offset = Vector2(-fanOffset, -10);
        default:
          continue;
      }

      final fan = OpponentHandFan(
        cardCount: 8,
        position: seatPos + offset,
        baseRotation: rotation,
      );
      _opponentFans[i] = fan;
      if (!_isLandscape) add(fan);
    }
  }

  // ... rest of update logic unchanged
```

Also hide the perspective table in landscape. In `onLoad`:

```dart
// 3D perspective table surface — only in portrait
_perspectiveTable = PerspectiveTableComponent(layout: layout);
add(_perspectiveTable!);
```

And in `_updateLandscapeVisibility`:

```dart
void _updateLandscapeVisibility() {
  final landscape = layout.isLandscape;
  if (landscape == _isLandscape) return; // no change
  _isLandscape = landscape;

  // Toggle perspective table
  if (_perspectiveTable != null) {
    if (landscape && _perspectiveTable!.isMounted) {
      _perspectiveTable!.removeFromParent();
    } else if (!landscape && !_perspectiveTable!.isMounted) {
      add(_perspectiveTable!);
    }
  }

  // Toggle seats
  for (final seat in _seats) {
    if (landscape && seat.isMounted) {
      seat.removeFromParent();
    } else if (!landscape && !seat.isMounted) {
      add(seat);
    }
  }

  // Toggle ambient decoration
  if (_ambientDecoration != null) {
    if (landscape && _ambientDecoration!.isMounted) {
      _ambientDecoration!.removeFromParent();
    } else if (!landscape && !_ambientDecoration!.isMounted) {
      add(_ambientDecoration!);
    }
  }

  // Toggle opponent fans
  for (final fan in _opponentFans.values) {
    if (landscape && fan.isMounted) {
      fan.removeFromParent();
    } else if (!landscape && !fan.isMounted) {
      add(fan);
    }
  }

  // Update table background
  final tableBg = children.whereType<TableBackgroundComponent>().firstOrNull;
  if (tableBg != null) {
    tableBg.isLandscape = landscape;
  }
}
```

- [ ] **Step 3: Run app on iOS simulator**

Run: `flutter run -d <ios-simulator-id>`
Expected: Landscape shows green felt, no table trapezoid, no avatars, no opponent fans. Hand and trick area render normally.

- [ ] **Step 4: Run on macOS to verify portrait unchanged**

Run: `flutter run -d macos`
Expected: Everything looks exactly the same as before — table, avatars, fans, all present.

- [ ] **Step 5: Commit**

```bash
git add lib/game/kout_game.dart lib/game/components/table_background.dart
git commit -m "feat: hide table and avatars in landscape mode"
```

---

### Task 6: Add Landscape Opponent Name Labels

**Files:**
- Create: `lib/game/components/opponent_name_label.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Create OpponentNameLabel component**

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
import '../theme/kout_theme.dart';
import '../theme/card_painter.dart';

/// Lightweight landscape-mode label for an opponent: name, team dot,
/// bid status, and a small face-down card fan.
class OpponentNameLabel extends PositionComponent {
  String playerName;
  bool isTeamA;
  String? bidAction;
  bool isBidder;
  bool isActive;
  int cardCount;

  /// How many card backs to show in the mini fan.
  static const int _fanDisplayCount = 5;
  static const double _miniCardW = 26.0;
  static const double _miniCardH = 37.0;
  static const double _cardOverlap = 12.0;
  static const double _scaleX = _miniCardW / KoutTheme.cardWidth;
  static const double _scaleY = _miniCardH / KoutTheme.cardHeight;

  OpponentNameLabel({
    required this.playerName,
    required this.isTeamA,
    this.bidAction,
    this.isBidder = false,
    this.isActive = false,
    this.cardCount = 8,
    super.position,
    super.anchor = Anchor.topCenter,
  }) : super(size: Vector2(140, 70));

  void updateState({
    required String name,
    required bool teamA,
    required bool active,
    required int cards,
    String? bidAction,
    bool isBidder = false,
  }) {
    playerName = name;
    isTeamA = teamA;
    isActive = active;
    cardCount = cards;
    this.bidAction = bidAction;
    this.isBidder = isBidder;
  }

  @override
  void render(Canvas canvas) {
    final centerX = size.x / 2;

    // --- Name row: [dot] name [crown] [bid status] ---
    final dotColor = isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor;
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(centerX - 45, 8), 3, dotPaint);

    // Active glow behind name
    if (isActive) {
      final glowPaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(centerX, 8), width: 100, height: 18),
          const Radius.circular(9),
        ),
        glowPaint,
      );
    }

    // Player name
    TextRenderer.drawCentered(
      canvas,
      playerName,
      isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream,
      Offset(centerX - 10, 8),
      9,
    );

    // Crown for bidder
    if (isBidder) {
      TextRenderer.drawCentered(
        canvas, '\u{1F451}', DiwaniyaColors.goldAccent,
        Offset(centerX + 30, 8), 8,
      );
    }

    // Bid action
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final color = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, color, Offset(centerX + 50, 8), 7);
    }

    // --- Card fan below name ---
    final displayCount = cardCount.clamp(0, 8);
    if (displayCount == 0) return;

    final fanY = 22.0;
    final totalFanWidth = _miniCardW + (_fanDisplayCount - 1) * _cardOverlap;
    final fanStartX = centerX - totalFanWidth / 2;

    for (int i = 0; i < displayCount && i < _fanDisplayCount; i++) {
      final t = _fanDisplayCount == 1 ? 0.0 : (i / (_fanDisplayCount - 1)) - 0.5;
      final angle = t * 0.40;
      final dx = fanStartX + i * _cardOverlap;
      final dy = fanY - (0.25 - t * t) * 8;

      canvas.save();
      canvas.translate(dx + _miniCardW / 2, dy + _miniCardH / 2);
      canvas.rotate(angle);
      canvas.translate(-_miniCardW / 2, -_miniCardH / 2);
      canvas.scale(_scaleX, _scaleY);
      CardPainter.paintBack(
        canvas,
        Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight),
      );
      canvas.restore();
    }
  }
}
```

- [ ] **Step 2: Wire OpponentNameLabels into KoutGame for landscape**

In `lib/game/kout_game.dart`, add a field:

```dart
final Map<int, OpponentNameLabel> _opponentLabels = {};
```

Add a method `_updateLandscapeLabels` called from `_onStateUpdate` (after `_updateLandscapeVisibility`):

```dart
void _updateLandscapeLabels(ClientGameState state) {
  if (!_isLandscape) {
    // Remove labels in portrait
    for (final label in _opponentLabels.values) {
      if (label.isMounted) label.removeFromParent();
    }
    _opponentLabels.clear();
    return;
  }

  // Create or update labels for all 4 players (including self as just a name)
  for (int i = 0; i < 4; i++) {
    final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
    final pos = layout.seatPosition(i, state.mySeatIndex);

    if (relativeSeat == 0) {
      // "You" label — just update position, no card fan needed
      // Skip for now — the user sees their own hand
      continue;
    }

    String? bidAction;
    if (state.phase == GamePhase.bidding || state.phase == GamePhase.trumpSelection) {
      for (final entry in state.bidHistory) {
        if (entry.playerUid == state.playerUids[i]) {
          bidAction = entry.action;
        }
      }
    }

    final showBidderGlow = state.phase != GamePhase.bidding &&
        state.phase != GamePhase.waiting &&
        state.phase != GamePhase.dealing;

    if (_opponentLabels.containsKey(i)) {
      _opponentLabels[i]!.updateState(
        name: _shortUid(state.playerUids[i]),
        teamA: i.isEven,
        active: state.currentPlayerUid == state.playerUids[i],
        cards: state.cardCounts[i] ?? 8,
        bidAction: bidAction,
        isBidder: showBidderGlow && state.playerUids[i] == state.bidderUid,
      );
      _opponentLabels[i]!.position = pos;
    } else {
      final label = OpponentNameLabel(
        playerName: _shortUid(state.playerUids[i]),
        isTeamA: i.isEven,
        bidAction: bidAction,
        isActive: state.currentPlayerUid == state.playerUids[i],
        cardCount: state.cardCounts[i] ?? 8,
        position: pos,
      );
      _opponentLabels[i] = label;
      add(label);
    }
  }
}
```

Add the import at the top of `kout_game.dart`:

```dart
import 'components/opponent_name_label.dart';
```

Update `_onStateUpdate`:

```dart
void _onStateUpdate(ClientGameState state) {
  _updateLandscapeVisibility();
  _updateLandscapeLabels(state);
  _updateScoreDisplay(state);
  _updateSeats(state);
  _updateBidderGlow(state);
  _updateHand(state);
  _updateTrickArea(state);
  _updateOverlays(state);
}
```

- [ ] **Step 3: Run on iOS simulator**

Run: `flutter run -d <ios-simulator-id>`
Expected: Landscape shows 3 opponent name labels along the top with card fans, active player name glows gold, bidder shows crown.

- [ ] **Step 4: Run on macOS to verify no labels in portrait**

Run: `flutter run -d macos`
Expected: No name labels visible, normal avatars and fans.

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/opponent_name_label.dart lib/game/kout_game.dart
git commit -m "feat: add landscape opponent name labels with card fans"
```

---

### Task 7: Landscape-Aware Overlays

**Files:**
- Modify: `lib/game/overlays/overlay_animation_wrapper.dart`

- [ ] **Step 1: Make overlay centering respect safe area**

The overlays are Flutter widgets positioned via `Center` inside a full-screen scrim. The scrim should remain full-screen but the content should center within the safe area. Update `overlay_animation_wrapper.dart`:

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      return Container(
        color: Colors.black.withValues(alpha: _opacityAnimation.value * 0.4),
        child: SafeArea(
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: child,
              ),
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
```

The only change is wrapping `Center` in `SafeArea`. This pushes the overlay content inside the safe area on all devices. On macOS/iPad (zero insets), no visual change.

- [ ] **Step 2: Run on iOS simulator, trigger bid overlay**

Run: `flutter run -d <ios-simulator-id>`
Expected: Start a game, bid overlay appears centered within the safe area (not behind Dynamic Island).

- [ ] **Step 3: Run on macOS to verify no change**

Run: `flutter run -d macos`
Expected: Overlays appear centered as before.

- [ ] **Step 4: Commit**

```bash
git add lib/game/overlays/overlay_animation_wrapper.dart
git commit -m "fix: center overlays within safe area for landscape"
```

---

### Task 8: HUD Positioning in Landscape

**Files:**
- Modify: `lib/game/components/unified_hud.dart`

- [ ] **Step 1: Read the current HUD positioning**

The HUD is positioned at `Vector2(screenWidth - _hudWidth - 12, 10)`. In landscape this could overlap with the safe area on the right. We need to offset by `safeArea.right`.

- [ ] **Step 2: Make HUD position safe-area aware**

In `lib/game/components/unified_hud.dart`, find the `updateWidth` method and the position calculation. Add a method:

```dart
void updateLayout(double screenWidth, {double rightInset = 0, double topInset = 0}) {
  position = Vector2(screenWidth - _hudWidth - 12 - rightInset, 10 + topInset);
}
```

- [ ] **Step 3: Call updateLayout from KoutGame**

In `lib/game/kout_game.dart`, in `_updateScoreDisplay`, after creating or finding `_unifiedHud`, update its position:

After `_unifiedHud!.updateTimer(...)` at the end of `_updateScoreDisplay`, add:

```dart
// Position HUD within safe area
if (_isLandscape) {
  _unifiedHud!.updateLayout(
    hasLayout ? size.x : 852,
    rightInset: _safeArea.right,
    topInset: _safeArea.top,
  );
}
```

- [ ] **Step 4: Run on iOS simulator**

Run: `flutter run -d <ios-simulator-id>`
Expected: HUD positioned inside safe area on the right side, not clipped by Dynamic Island.

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/unified_hud.dart lib/game/kout_game.dart
git commit -m "fix: position HUD within safe area in landscape"
```

---

### Task 9: Final Integration Test

**Files:** None (testing only)

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors. Warnings are acceptable if pre-existing.

- [ ] **Step 3: Test on iOS simulator — full game flow**

Run: `flutter run -d <ios-simulator-id>`
Test: Start offline game, go through bidding, trump selection, play a few tricks, let round end. Verify:
- All elements within safe area
- No clipping on either side
- Cards properly sized
- Opponent names and card fans visible
- HUD readable
- Overlays centered correctly
- Trick area centered and visible

- [ ] **Step 4: Test on macOS — verify no regression**

Run: `flutter run -d macos`
Test: Same full game flow. Verify portrait layout is identical to before — avatars, table, fans, everything.

- [ ] **Step 5: Commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: integration test fixes for landscape layout"
```
