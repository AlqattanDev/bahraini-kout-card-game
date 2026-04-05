# Landscape UI Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 10 UI/UX issues in iPhone landscape mode — reposition opponents to sides, fix stale layout bug, push cards to bottom edge with tighter fan, compact overlays, add player label.

**Architecture:** Fix root-cause stale layout reference in HandComponent/TrickAreaComponent, then update LayoutManager landscape positions to place opponents on sides instead of top, tune card fan parameters, scale overlays for landscape, update OpponentNameLabel for side placement.

**Tech Stack:** Flutter/Flame (Dart), no new dependencies.

---

### Task 1: Fix Stale Layout Reference in HandComponent and TrickAreaComponent

**Files:**
- Modify: `lib/game/components/hand_component.dart`
- Modify: `lib/game/components/trick_area.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Make HandComponent layout mutable**

In `lib/game/components/hand_component.dart`, change line 12 from `final` to a mutable field:

```dart
  LayoutManager layout;
```

No other changes needed — the constructor already accepts `required this.layout` and the getter `handCardScale` reads from `layout.handCardScale`.

- [ ] **Step 2: Make TrickAreaComponent layout mutable**

In `lib/game/components/trick_area.dart`, change line 15 from `final` to mutable:

```dart
  LayoutManager layout;
```

Update the existing `updateLayout` method (lines 105-108) to actually store the new layout:

```dart
  void updateLayout(LayoutManager newLayout) {
    layout = newLayout;
  }
```

- [ ] **Step 3: Propagate layout updates in KoutGame**

In `lib/game/kout_game.dart`, update `updateSafeArea` (line 86) to also update hand and trick area:

```dart
  void updateSafeArea(EdgeInsets insets) {
    _safeArea = insets;
    // Re-create layout with new insets
    if (hasLayout) {
      layout = LayoutManager(size, safeArea: _safeArea);
      _unifiedHud?.updateWidth(size.x);
      _perspectiveTable?.updateLayout(layout);
      _hand?.layout = layout;
      _trickArea?.layout = layout;
    }
  }
```

Update `onGameResize` (line 147) similarly:

```dart
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    layout = LayoutManager(size, safeArea: _safeArea);
    _unifiedHud?.updateWidth(size.x);
    _perspectiveTable?.updateLayout(layout);
    _hand?.layout = layout;
    _trickArea?.layout = layout;
    // Sync landscape flag with new layout (handles macOS window resize)
    if (currentState != null) _updateLandscapeVisibility();
  }
```

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: All tests pass. No test directly tests component layout propagation but the build must succeed.

- [ ] **Step 5: Run analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/game/components/hand_component.dart lib/game/components/trick_area.dart lib/game/kout_game.dart
git commit -m "fix: propagate layout updates to HandComponent and TrickAreaComponent"
```

---

### Task 2: Reposition Landscape Opponents to Sides and Update Card Fan

**Files:**
- Modify: `lib/game/managers/layout_manager.dart`
- Modify: `test/game/hand_spacing_test.dart`

- [ ] **Step 1: Write new landscape position tests**

Replace the `'LayoutManager landscape mode'` group in `test/game/hand_spacing_test.dart` with:

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

    test('hand center X is centered in safe rect', () {
      final hc = landscapeLayout.handCenter;
      expect(hc.x, closeTo(landscapeLayout.safeRect.center.dx, 1));
    });

    test('hand center Y extends below screen height (cards at edge)', () {
      final hc = landscapeLayout.handCenter;
      expect(hc.y, greaterThan(393), reason: 'Hand should extend past bottom edge');
    });

    test('left seat is on left side vertically centered', () {
      final ls = landscapeLayout.leftSeat;
      expect(ls.x, closeTo(landscapeLayout.safeRect.left + 80, 1));
      final centerY = landscapeLayout.safeRect.center.dy;
      expect(ls.y, closeTo(centerY, 10));
    });

    test('right seat is on right side vertically centered', () {
      final rs = landscapeLayout.rightSeat;
      expect(rs.x, closeTo(landscapeLayout.safeRect.right - 80, 1));
      final centerY = landscapeLayout.safeRect.center.dy;
      expect(rs.y, closeTo(centerY, 10));
    });

    test('partner seat is at top center', () {
      final ps = landscapeLayout.partnerSeat;
      expect(ps.x, closeTo(landscapeLayout.safeRect.center.dx, 1));
      expect(ps.y, closeTo(landscapeLayout.safeRect.top + 25, 1));
    });

    test('trick center is within safe rect', () {
      final tc = landscapeLayout.trickCenter;
      expect(tc.x, greaterThan(landscapeLayout.safeRect.left));
      expect(tc.x, lessThan(landscapeLayout.safeRect.right));
      expect(tc.y, greaterThan(landscapeLayout.safeRect.top));
      expect(tc.y, lessThan(landscapeLayout.safeRect.bottom));
    });

    test('handCardScale is between 0.7 and 1.0 on landscape phone', () {
      expect(landscapeLayout.handCardScale, lessThan(1.0));
      expect(landscapeLayout.handCardScale, greaterThan(0.7));
    });

    test('landscape card spacing is tighter than portrait', () {
      final lPos = landscapeLayout.handCardPositions(8);
      final pLayout = LayoutManager(Vector2(600, 800));
      final pPos = pLayout.handCardPositions(8);
      final lSpacing = (lPos[1].position.x - lPos[0].position.x).abs();
      final pSpacing = (pPos[1].position.x - pPos[0].position.x).abs();
      expect(lSpacing, lessThan(pSpacing));
    });

    test('portrait layout is unchanged when no safe area', () {
      final portrait = LayoutManager(Vector2(600, 800));
      expect(portrait.isLandscape, isFalse);
      expect(portrait.handCenter, Vector2(300, 720));
      expect(portrait.handCardScale, 1.4);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/game/hand_spacing_test.dart`
Expected: FAIL — positions don't match new expectations yet.

- [ ] **Step 3: Update landscape positions and card fan in LayoutManager**

In `lib/game/managers/layout_manager.dart`, replace the landscape section (lines 32-85 and lines 138-141) with updated values.

Replace `handCardScale` getter (lines 32-37):

```dart
  /// Scale factor for hand cards. Smaller on landscape phones, 1.4x on portrait.
  double get handCardScale {
    if (!isLandscape) return 1.4;
    // Target ~22% of safe height for card height, clamped for readability
    return (safeRect.height * 0.22 / 100).clamp(0.75, 1.4);
  }
```

Replace `trickTrackerCenter` (line 49):

```dart
  Vector2 get trickTrackerCenter => Vector2(trickCenter.x, trickCenter.y + (isLandscape ? 60 : 130));
```

Replace ALL landscape position getters (lines 66-85):

```dart
  // ---------------------------------------------------------------------------
  // Landscape positions (safe-area aware, opponents on sides)
  // ---------------------------------------------------------------------------

  /// Hand at bottom-center, pushed below screen edge so cards bleed off-screen
  Vector2 get _landscapeHandCenter {
    return Vector2(safeRect.center.dx, height + 15);
  }

  /// Player label at bottom-right of safe rect
  Vector2 get _landscapeMySeat => Vector2(safeRect.right - 50, safeRect.bottom - 25);

  /// Partner label at top-center of safe rect
  Vector2 get _landscapePartnerSeat => Vector2(safeRect.center.dx, safeRect.top + 25);

  /// Left opponent at left side, vertically centered in safe rect
  Vector2 get _landscapeLeftSeat => Vector2(safeRect.left + 80, safeRect.center.dy);

  /// Right opponent at right side, vertically centered in safe rect
  Vector2 get _landscapeRightSeat => Vector2(safeRect.right - 80, safeRect.center.dy);

  /// Trick area at center of safe rect, slightly above center
  Vector2 get _landscapeTrickCenter => Vector2(safeRect.center.dx, safeRect.center.dy - 15);
```

Replace landscape card spacing clamp (line 140):

```dart
    final cardSpacing = isLandscape
        ? (50 - cardCount * 3.0).clamp(24.0, 40.0)
        : (80 - cardCount * 4.0).clamp(44.0, 72.0);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/game/hand_spacing_test.dart`
Expected: All tests PASS including portrait tests unchanged.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add lib/game/managers/layout_manager.dart test/game/hand_spacing_test.dart
git commit -m "feat: reposition landscape opponents to sides, cards to bottom edge"
```

---

### Task 3: Update OpponentNameLabel for Side Placement

**Files:**
- Modify: `lib/game/components/opponent_name_label.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Add placement enum and update OpponentNameLabel**

Replace `lib/game/components/opponent_name_label.dart` entirely:

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
import '../theme/kout_theme.dart';
import '../theme/card_painter.dart';

/// Where the label sits on screen — determines anchor and internal layout.
enum OpponentLabelPlacement { top, left, right }

/// Lightweight landscape-mode label for an opponent: name, team dot,
/// bid status, and a small face-down card fan.
class OpponentNameLabel extends PositionComponent {
  String playerName;
  bool isTeamA;
  String? bidAction;
  bool isBidder;
  bool isActive;
  int cardCount;
  OpponentLabelPlacement placement;

  static const double _miniCardW = 22.0;
  static const double _miniCardH = 31.0;
  static const double _cardOverlap = 10.0;
  static const int _fanDisplayCount = 5;
  static const double _scaleX = _miniCardW / KoutTheme.cardWidth;
  static const double _scaleY = _miniCardH / KoutTheme.cardHeight;

  OpponentNameLabel({
    required this.playerName,
    required this.isTeamA,
    this.bidAction,
    this.isBidder = false,
    this.isActive = false,
    this.cardCount = 8,
    this.placement = OpponentLabelPlacement.top,
    super.position,
  }) : super(
          size: _sizeForPlacement(placement),
          anchor: _anchorForPlacement(placement),
        );

  static Vector2 _sizeForPlacement(OpponentLabelPlacement p) {
    return switch (p) {
      OpponentLabelPlacement.top => Vector2(140, 60),
      OpponentLabelPlacement.left || OpponentLabelPlacement.right => Vector2(80, 90),
    };
  }

  static Anchor _anchorForPlacement(OpponentLabelPlacement p) {
    return switch (p) {
      OpponentLabelPlacement.top => Anchor.topCenter,
      OpponentLabelPlacement.left => Anchor.center,
      OpponentLabelPlacement.right => Anchor.center,
    };
  }

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
    if (placement == OpponentLabelPlacement.top) {
      _renderTop(canvas);
    } else {
      _renderSide(canvas);
    }
  }

  /// Top placement: name row on top, card fan below (for partner at top-center).
  void _renderTop(Canvas canvas) {
    final cx = size.x / 2;

    // Team dot
    final dotPaint = Paint()..color = (isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor);
    canvas.drawCircle(Offset(cx - 45, 8), 3, dotPaint);

    // Active glow
    if (isActive) {
      final glowPaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 8), width: 100, height: 18),
          const Radius.circular(9),
        ),
        glowPaint,
      );
    }

    // Name
    TextRenderer.drawCentered(
      canvas, playerName,
      isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream,
      Offset(cx - 10, 8), 9,
    );

    // Crown
    if (isBidder) {
      TextRenderer.drawCentered(canvas, '\u{1F451}', DiwaniyaColors.goldAccent, Offset(cx + 30, 8), 8);
    }

    // Bid action
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final color = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, color, Offset(cx + 50, 8), 7);
    }

    // Card fan
    _renderFan(canvas, cx, 22.0);
  }

  /// Side placement: name on top, card fan below, compact vertical stack.
  void _renderSide(Canvas canvas) {
    final cx = size.x / 2;

    // Team dot
    final dotPaint = Paint()..color = (isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor);
    canvas.drawCircle(Offset(cx - 25, 8), 3, dotPaint);

    // Active glow
    if (isActive) {
      final glowPaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 8), width: 70, height: 16),
          const Radius.circular(8),
        ),
        glowPaint,
      );
    }

    // Name (compact)
    TextRenderer.drawCentered(
      canvas, playerName,
      isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream,
      Offset(cx, 8), 8,
    );

    // Bid action (below name)
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final color = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, color, Offset(cx, 22), 7);
    } else if (isBidder) {
      TextRenderer.drawCentered(canvas, '\u{1F451}', DiwaniyaColors.goldAccent, Offset(cx, 22), 8);
    }

    // Card fan (below text)
    _renderFan(canvas, cx, 36.0);
  }

  void _renderFan(Canvas canvas, double centerX, double fanY) {
    final displayCount = cardCount.clamp(0, 8);
    if (displayCount == 0) return;

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

- [ ] **Step 2: Update _updateLandscapeLabels in KoutGame to pass placement**

In `lib/game/kout_game.dart`, update the `_updateLandscapeLabels` method. Replace the label creation block (lines 314-323) with:

```dart
      final placement = switch (relativeSeat) {
        1 => OpponentLabelPlacement.left,
        2 => OpponentLabelPlacement.top,
        3 => OpponentLabelPlacement.right,
        _ => OpponentLabelPlacement.top,
      };

      final label = OpponentNameLabel(
        playerName: _shortUid(state.playerUids[i]),
        isTeamA: i.isEven,
        bidAction: bidAction,
        isActive: state.currentPlayerUid == state.playerUids[i],
        cardCount: state.cardCounts[i] ?? 8,
        placement: placement,
        position: pos,
      );
      _opponentLabels[i] = label;
      add(label);
```

- [ ] **Step 3: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: No issues, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/opponent_name_label.dart lib/game/kout_game.dart
git commit -m "feat: update OpponentNameLabel with side placement for landscape"
```

---

### Task 4: Add Player "You" Label in Landscape

**Files:**
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Add player label field and management**

In `lib/game/kout_game.dart`, add a field after `_opponentLabels` (around line 43):

```dart
  OpponentNameLabel? _playerLabel;
```

- [ ] **Step 2: Add player label logic to _updateLandscapeLabels**

At the end of `_updateLandscapeLabels`, after the opponent loop, add:

```dart
    // Player "You" label at bottom-right
    final myPos = layout.mySeat;
    if (_playerLabel == null) {
      _playerLabel = OpponentNameLabel(
        playerName: _shortUid(state.playerUids[state.mySeatIndex]),
        isTeamA: state.mySeatIndex.isEven,
        cardCount: 0, // No card fan for self — player sees their hand
        placement: OpponentLabelPlacement.right,
        position: myPos,
      );
      add(_playerLabel!);
    } else {
      _playerLabel!.updateState(
        name: _shortUid(state.playerUids[state.mySeatIndex]),
        teamA: state.mySeatIndex.isEven,
        active: state.currentPlayerUid == state.myUid,
        cards: 0,
      );
      _playerLabel!.position = myPos;
    }
```

- [ ] **Step 3: Clean up player label in portrait path**

In the portrait cleanup at the top of `_updateLandscapeLabels` (the `if (!_isLandscape)` block), add:

```dart
    if (_playerLabel != null) {
      if (_playerLabel!.isMounted) _playerLabel!.removeFromParent();
      _playerLabel = null;
    }
```

- [ ] **Step 4: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: No issues, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/game/kout_game.dart
git commit -m "feat: add player 'You' label in landscape mode"
```

---

### Task 5: Compact Overlays for Landscape

**Files:**
- Modify: `lib/game/overlays/overlay_animation_wrapper.dart`

- [ ] **Step 1: Add landscape scaling to overlay wrapper**

In `lib/game/overlays/overlay_animation_wrapper.dart`, update the `build` method (line 74) to detect landscape and scale down:

```dart
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final landscapeScale = isLandscape ? 0.75 : 1.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: _opacityAnimation.value * 0.4),
          child: SafeArea(
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value * landscapeScale,
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

- [ ] **Step 2: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: No issues, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/game/overlays/overlay_animation_wrapper.dart
git commit -m "fix: scale overlays to 75% in landscape for better fit"
```

---

### Task 6: Clean Up HUD Positioning

**Files:**
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Move HUD positioning from _updateScoreDisplay to layout update points**

In `lib/game/kout_game.dart`, remove the per-frame HUD positioning from `_updateScoreDisplay`. Find and delete these lines (around line 374):

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

Instead, add HUD positioning to `updateSafeArea` and `onGameResize`. In `updateSafeArea`, after the existing `_hand?.layout = layout;` line, add:

```dart
      if (layout.isLandscape) {
        _unifiedHud?.updateLayout(size.x, rightInset: _safeArea.right, topInset: _safeArea.top);
      }
```

In `onGameResize`, after `_trickArea?.layout = layout;`, add:

```dart
    if (layout.isLandscape) {
      _unifiedHud?.updateLayout(size.x, rightInset: _safeArea.right, topInset: _safeArea.top);
    }
```

- [ ] **Step 2: Run analyze and tests**

Run: `flutter analyze && flutter test`
Expected: No issues, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/game/kout_game.dart
git commit -m "fix: move HUD positioning to layout update points instead of per-frame"
```

---

### Task 7: Final Verification

**Files:** None (testing only)

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Run on iOS simulator**

Run: `flutter run -d <ios-simulator-id>`
Verify:
- Opponents positioned on left and right sides, partner at top center
- No overlap with HUD (top-right)
- Cards extend to bottom edge, no gap
- Tighter card fan spacing
- Overlays scaled down and centered within safe area
- Player "You" label visible at bottom-right
- All content within safe area, nothing behind Dynamic Island
- Trick area centered

- [ ] **Step 4: Run on macOS to verify portrait unchanged**

Run: `flutter run -d macos`
Verify: Portrait layout identical to before — avatars, table, fans, all present.
