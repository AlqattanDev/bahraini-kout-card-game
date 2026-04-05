# Landscape UI Overhaul — Layout, Hierarchy, and Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every layout, spacing, information hierarchy, and polish issue identified in the landscape game UI — from floating HUD to missing turn indicators to unreadable scoreboard.

**Architecture:** All changes are in `lib/game/`. LayoutManager drives proportional sizing; components consume layout values. No model/logic/backend changes needed. Each task targets a specific component or concern, and all tasks are independently testable in landscape mode.

**Tech Stack:** Flutter/Flame (Dart), custom Canvas rendering. No external packages needed.

---

## Issue-to-Task Map

Every issue from the critique is assigned to a specific task below. Nothing is dropped.

| Critique Issue | Root Cause | Task |
|---|---|---|
| Scoreboard floating in no-man's land | HUD top-left with no visual anchoring | Task 2 |
| Player labels inconsistently positioned | OpponentNameLabel placement + player label using `right` placement | Task 3 |
| "human_" label cut off / trailing underscore | `shortUid()` generates ugly names for offline bots | Task 3 |
| Card fan cropped at bottom | Hand cards not getting enough bleed / viewport issue | Task 4 |
| Bot card backs tiny and inconsistent | OpponentHandFan not shown in landscape (portrait-only), OpponentNameLabel mini-fan too small | Task 5 |
| Massive dead space right side | Layout not centering content properly + right opponent label too far from edge | Task 1, Task 3 |
| Played cards no clear ownership | TrickArea positions cards by seat but no visual ownership indicator | Task 6 |
| Card z-ordering chaotic in pile | Nudge factor + jitter making stacking unclear | Task 6 |
| Card scale inconsistency (center vs hand) | Portrait trick cards use 1.0x vs hand at 1.4x — landscape is correct but portrait isn't | Task 4 |
| Card shadows inconsistent | Some cards have `showShadow`, trick area cards always do, but shadow params differ from animation shadow | Task 6 |
| "5 / 31 R1" — no context | HUD score labels have no explanation | Task 2 |
| "BID 5" spade icon dark on dark | Trump suit uses `pureWhite` for black suits — invisible on dark HUD | Task 2 |
| Team "B" and "A" pip circles — no legend | Pips have team letter but no context for what they mean | Task 2 |
| Timer with red dot looks like recording | Timer has no label/context, just raw time | Task 2 |
| HUD brown bg clashes with green felt | HUD uses `scoreHudBg` (#2A1A14) which is brown on green felt | Task 2 |
| Mixed font weights/styles/colors everywhere | Player names using different colors per-seat with no system | Task 3 |
| Player name colors suggest team but never explained | Color-coded names with no legend | Task 3 |
| No turn indicator — no glow/arrow/border | Active player glow exists in PlayerSeat but those are hidden in landscape; OpponentNameLabel has a subtle gold rect | Task 7 |
| Green felt radial gradient "2012 Flash game" | Vignette too heavy, gradient too centered | Task 8 |
| No trump indicator outside tiny scoreboard | Trump suit buried in HUD | Task 2 |
| No information hierarchy — everything same priority | Needs size/contrast/position hierarchy across all elements | All tasks collectively |

---

## File Structure

Files modified (no new files created):

```
lib/game/
├── managers/
│   └── layout_manager.dart         — Task 1: landscape zone system
│   └── component_lifecycle_manager.dart — Task 3, 5, 7: label/fan/glow management
├── components/
│   ├── unified_hud.dart            — Task 2: HUD redesign
│   ├── opponent_name_label.dart    — Task 3: label redesign + turn indicator
│   ├── player_seat.dart            — (no changes needed)
│   ├── trick_area.dart             — Task 6: ownership + stacking
│   ├── hand_component.dart         — Task 4: hand spacing/bleed
│   ├── card_component.dart         — Task 6: consistent shadows
│   ├── opponent_hand_fan.dart      — Task 5: landscape fan visibility
│   └── table_background.dart       — Task 8: felt gradient
├── theme/
│   ├── diwaniya_colors.dart        — Task 2, 8: new HUD colors, felt colors
│   ├── kout_theme.dart             — Task 2: trump display color helper
│   └── textures.dart               — Task 8: vignette params
├── shared/
│   └── models/
│       └── game_state.dart         — Task 3: shortUid fix
└── overlays/
    └── (no changes — landscape scaling already implemented)
```

---

### Task 1: Landscape Zone System in LayoutManager

**Why:** The root of most layout issues. Positions are proportional but don't follow a strict zone budget. Right side has dead space because right opponent is at `safeRect.right - 12%` but left opponent is at `safeRect.left + 12%`, leaving center unbalanced when HUD takes space from the left.

**Files:**
- Modify: `lib/game/managers/layout_manager.dart`

- [ ] **Step 1: Add zone budget constants for landscape**

Add after line 17 (after `_portraitTrickTrackerYOffset`):

```dart
// Landscape zone budget (proportional to safeRect)
static const double _topZoneHeight = 0.12;      // 12% of safeH
static const double _handZoneHeight = 0.28;      // 28% of safeH
static const double _sideZoneWidth = 0.13;       // 13% of safeW
static const double _handBleedRatio = 0.20;      // 20% of scaled card hidden below edge
```

- [ ] **Step 2: Update landscape hand center**

Replace lines 93-96 (`_landscapeHandCenter`):

```dart
Vector2 get _landscapeHandCenter {
  final bleedAmount = 100 * handCardScale * _handBleedRatio;
  return Vector2(safeRect.center.dx, height + bleedAmount);
}
```

- [ ] **Step 3: Update landscape seat positions to use zone constants**

Replace lines 99-126 (all landscape seat positions):

```dart
/// Player label: bottom-center-right, inside hand zone
Vector2 get _landscapeMySeat => Vector2(
      safeRect.center.dx + safeRect.width * 0.25,
      safeRect.bottom - safeRect.height * _handZoneHeight * 0.4,
    );

/// Partner label: top-center of safe rect, inside top zone
Vector2 get _landscapePartnerSeat => Vector2(
      safeRect.center.dx,
      safeRect.top + safeRect.height * _topZoneHeight * 0.5,
    );

/// Left opponent: left side zone, vertically centered between top and hand zones
Vector2 get _landscapeLeftSeat {
  final centerY = safeRect.top + safeRect.height * _topZoneHeight +
      (safeRect.height * (1.0 - _topZoneHeight - _handZoneHeight)) / 2;
  return Vector2(
    safeRect.left + safeRect.width * _sideZoneWidth,
    centerY,
  );
}

/// Right opponent: right side zone, vertically centered
Vector2 get _landscapeRightSeat {
  final centerY = safeRect.top + safeRect.height * _topZoneHeight +
      (safeRect.height * (1.0 - _topZoneHeight - _handZoneHeight)) / 2;
  return Vector2(
    safeRect.right - safeRect.width * _sideZoneWidth,
    centerY,
  );
}

/// Trick area: center of the play zone (between top zone and hand zone), slightly above center
Vector2 get _landscapeTrickCenter {
  final topEdge = safeRect.top + safeRect.height * _topZoneHeight;
  final bottomEdge = safeRect.bottom - safeRect.height * _handZoneHeight;
  final centerY = (topEdge + bottomEdge) / 2 - safeRect.height * 0.02;
  return Vector2(safeRect.center.dx, centerY);
}
```

- [ ] **Step 4: Run `flutter analyze` and verify no errors**

Run: `flutter analyze lib/game/managers/layout_manager.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/game/managers/layout_manager.dart
git commit -m "refactor(layout): add landscape zone system with proportional budget"
```

---

### Task 2: HUD Redesign — Readable, Contextual, Anchored

**Why:** The HUD is a blob of raw numbers. Score has no label. Pips have no context. Trump suit is invisible (white on dark). Timer looks like a recording indicator. Brown background clashes with green felt.

**Files:**
- Modify: `lib/game/components/unified_hud.dart`
- Modify: `lib/game/theme/diwaniya_colors.dart`
- Modify: `lib/game/theme/kout_theme.dart`

- [ ] **Step 1: Add new HUD color constants to DiwaniyaColors**

Add after line 31 in `diwaniya_colors.dart`:

```dart
// Improved HUD — translucent dark that blends with felt
static const Color hudBgLandscape = Color(0xDD1A2E1F);    // dark green-tinted
static const Color hudBorderLandscape = Color(0xFF4A6B4A); // muted green-gold
static const Color hudLabelMuted = Color(0x99F5ECD7);      // cream at 60%
```

- [ ] **Step 2: Add trump display color helper to KoutTheme**

Add after line 22 in `kout_theme.dart`:

```dart
/// Suit color for HUD/dark-background contexts — all suits must be visible.
/// Black suits get cream/gold instead of black.
static Color suitHudColor(Suit suit) =>
    suit.isRed ? const Color(0xFFCC0000) : DiwaniyaColors.goldAccent;
```

- [ ] **Step 3: Rewrite unified_hud.dart render method for clarity and context**

Replace the entire `render()` method (lines 123-211) and `_drawPipRow` (lines 213-233) with:

```dart
@override
void render(Canvas canvas) {
  final hudHeight = _computeHeight();
  size = Vector2(_hudWidth, hudHeight);

  // Background — use green-tinted bg in landscape for felt harmony
  final bgColor = _isLandscape
      ? DiwaniyaColors.hudBgLandscape
      : DiwaniyaColors.scoreHudBg;
  final borderColor = _isLandscape
      ? DiwaniyaColors.hudBorderLandscape
      : DiwaniyaColors.scoreHudBorder;

  final bgRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, _hudWidth, hudHeight),
    const Radius.circular(12),
  );
  canvas.drawRRect(bgRect, Paint()..color = bgColor);
  canvas.drawRRect(
    bgRect,
    Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  double y = _padding;

  // --- Score section with label ---
  TextRenderer.draw(canvas, 'SCORE', DiwaniyaColors.hudLabelMuted,
      Offset(_padding, y), 8, align: TextAlign.left, width: 50);
  TextRenderer.draw(canvas, 'R$roundNumber',
      DiwaniyaColors.hudLabelMuted,
      Offset(_hudWidth - _padding - 20, y), 8,
      align: TextAlign.right, width: 20);
  y += 10;

  // Large score number
  TextRenderer.draw(canvas, '$score', scoreColor,
      Offset(_padding, y), 28, align: TextAlign.left, width: 60);
  TextRenderer.draw(canvas, '/ 31',
      DiwaniyaColors.cream.withValues(alpha: 0.4),
      Offset(_padding + 50, y + 10), 11, align: TextAlign.left, width: 40);
  y += 30 + _rowGap;

  // Divider
  canvas.drawLine(
    Offset(_padding, y),
    Offset(_hudWidth - _padding, y),
    Paint()..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.25),
  );
  y += _dividerHeight + _rowGap;

  // --- Bid + Trump section ---
  if (_showBidRow && bidValue != null) {
    final bidTeamColor = bidderTeam != null
        ? KoutTheme.teamColor(bidderTeam!)
        : DiwaniyaColors.cream;

    final bidText = bidValue == 8 ? 'KOUT' : 'BID $bidValue';
    TextRenderer.draw(canvas, bidText, bidTeamColor,
        Offset(_padding, y), 12, align: TextAlign.left, width: 80);

    if (trumpSuit != null) {
      // Use HUD-safe suit color — gold for black suits, red for red suits
      final suitColor = KoutTheme.suitHudColor(trumpSuit!);
      TextRenderer.draw(canvas, trumpSuit!.symbol, suitColor,
          Offset(_hudWidth - _padding - 20, y - 2), 18,
          align: TextAlign.right, width: 20);
    }
    y += 18 + _rowGap;
  }

  // --- Trick progress pips with labels ---
  if (_showPips && bidValue != null) {
    final bidTeamColor = KoutTheme.teamColor(bidderTeam ?? Team.a);
    final oppTeamColor = KoutTheme.teamColor((bidderTeam ?? Team.a).opponent);
    final bidTeamLabel = bidderTeam == Team.a ? 'A' : 'B';
    final oppTeamLabel = bidderTeam == Team.a ? 'B' : 'A';

    // Bidder pip row: "A needs 5" shown as label + pips
    TextRenderer.draw(canvas, bidTeamLabel, bidTeamColor,
        Offset(_padding, y + 1), 10, align: TextAlign.left, width: 12);
    _drawPipRow(canvas, y + 4, bidValue!, bidderTricks, bidTeamColor);
    y += 16;

    // Opponent pip row
    TextRenderer.draw(canvas, oppTeamLabel, oppTeamColor,
        Offset(_padding, y + 1), 10, align: TextAlign.left, width: 12);
    _drawPipRow(canvas, y + 4, opponentTarget, opponentTricks, oppTeamColor);
    y += 16 + _rowGap;

    canvas.drawLine(
      Offset(_padding, y),
      Offset(_hudWidth - _padding, y),
      Paint()..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.25),
    );
    y += _dividerHeight + _rowGap;
  }

  // --- Timer with label ---
  TextRenderer.draw(canvas, timerText,
      DiwaniyaColors.cream.withValues(alpha: 0.5),
      Offset(_hudWidth / 2, y), 11,
      align: TextAlign.center, width: _hudWidth);
}
```

- [ ] **Step 4: Add `_isLandscape` field and update `updateLayout`**

Add field after line 29:

```dart
bool _isLandscape = false;
```

Update `updateLayout` (line 43) to set it:

```dart
void updateLayout(double screenWidth, {double rightInset = 0, double topInset = 0, bool landscape = false, double leftInset = 0}) {
  _isLandscape = landscape;
  if (landscape) {
    position = Vector2(leftInset + 12, 10 + topInset);
  } else {
    position = Vector2(screenWidth - _hudWidth - 12 - rightInset, 10 + topInset);
  }
}
```

- [ ] **Step 5: Run `flutter analyze`**

Run: `flutter analyze lib/game/components/unified_hud.dart lib/game/theme/diwaniya_colors.dart lib/game/theme/kout_theme.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/game/components/unified_hud.dart lib/game/theme/diwaniya_colors.dart lib/game/theme/kout_theme.dart
git commit -m "feat(hud): add labels, fix trump contrast, blend bg with felt"
```

---

### Task 3: Player Labels — Consistent Positioning, Team Clarity, Better Names

**Why:** Labels are scattered with no symmetry. "human_" is a `shortUid()` artifact — the function is at `lib/shared/models/game_state.dart:22` and just truncates to 6 chars. Colors are random per-seat with no system. Team assignment is opaque.

**Files:**
- Modify: `lib/shared/models/game_state.dart:22` (shortUid function — this is the canonical location)
- Modify: `lib/game/components/opponent_name_label.dart`
- Modify: `lib/game/managers/component_lifecycle_manager.dart`

- [ ] **Step 1: Fix `shortUid` to produce readable names for offline bots**

In `lib/shared/models/game_state.dart`, replace line 22:

```dart
/// Truncates a UID to 6 characters for display.
String shortUid(String uid) => uid.length <= 6 ? uid : uid.substring(0, 6);
```

With:

```dart
/// Produces a short display name from a UID.
/// Offline bot UIDs like "bot_1" become "Bot 1".
/// Online UIDs get first 6 chars.
String shortUid(String uid) {
  if (uid.startsWith('bot_')) {
    final num = uid.substring(4);
    return 'Bot $num';
  }
  if (uid.length <= 8) return uid;
  return uid.substring(0, 6);
}
```

- [ ] **Step 2: Update OpponentNameLabel for clearer team/active indication**

In `opponent_name_label.dart`, replace the `render()` method (lines 90-127):

```dart
@override
void render(Canvas canvas) {
  final isTop = placement == OpponentLabelPlacement.top;
  final cx = size.x / 2;

  // --- Active player glow (prominent, team-colored) ---
  if (isActive) {
    final teamColor = KoutTheme.teamColor(team);
    final glowPaint = Paint()
      ..color = teamColor.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isTop ? 10 : 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, isTop ? 12 : 10),
          width: isTop ? 140 : 100,
          height: isTop ? 26 : 22,
        ),
        Radius.circular(isTop ? 13 : 11),
      ),
      glowPaint,
    );
  }

  // --- Team indicator: colored dot + team letter ---
  final teamColor = KoutTheme.teamColor(team);
  final dotX = cx - (isTop ? 60 : 40);
  canvas.drawCircle(Offset(dotX, isTop ? 12 : 10), 4, Paint()..color = teamColor);
  final teamLetter = team == Team.a ? 'A' : 'B';
  TextRenderer.draw(canvas, teamLetter, teamColor.withValues(alpha: 0.8),
      Offset(dotX + 8, isTop ? 6 : 4), 8, align: TextAlign.left, width: 12);

  // --- Player name ---
  final nameColor = isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream;
  TextRenderer.drawCentered(
    canvas, playerName, nameColor,
    Offset(isTop ? cx : cx, isTop ? 12 : 10), isTop ? 11.0 : 10.0,
  );

  // Bid action label + bidder crown
  _drawBidStatus(canvas, cx, isTop);

  _renderFan(canvas, cx, isTop ? 26.0 : 40.0);
}
```

- [ ] **Step 3: Update player label in component_lifecycle_manager to show "You" and use bottom-center placement**

In `component_lifecycle_manager.dart`, update the player label creation (lines 186-195).

Note: We keep `placement: OpponentLabelPlacement.right` because the player label sits at `mySeat` (bottom-right of safe rect). The `right` placement gives it `Anchor.center` and a vertical 130x150 layout, which is correct for that position. The `top` placement would use `Anchor.topCenter` which would misalign it.

```dart
final myPos = layout.mySeat;
if (playerLabel == null) {
  playerLabel = OpponentNameLabel(
    seatIndex: state.mySeatIndex,
    playerName: 'You',
    team: state.myTeam,
    cardCount: state.myHand.length,
    placement: OpponentLabelPlacement.right, // Right-side vertical layout, anchored at center
    position: myPos,
  );
  game.add(playerLabel!);
} else {
  playerLabel!.playerName = 'You';
  playerLabel!.cardCount = state.myHand.length;
  playerLabel!.team = state.myTeam;
  playerLabel!.isActive = state.isMyTurn;
  playerLabel!.position = myPos;
}
```

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/game/components/player_seat.dart lib/game/components/opponent_name_label.dart lib/game/managers/component_lifecycle_manager.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/player_seat.dart lib/game/components/opponent_name_label.dart lib/game/managers/component_lifecycle_manager.dart
git commit -m "fix(labels): consistent positioning, readable names, team indicators"
```

---

### Task 4: Hand Fan — Full Visibility, Proper Bleed, Correct Scale

**Why:** Cards are cropped at bottom with rank/suit cut off. In portrait, trick cards use 1.0x vs hand at 1.4x creating jarring inconsistency.

**Files:**
- Modify: `lib/game/managers/layout_manager.dart`

- [ ] **Step 1: Increase hand card scale and ensure bleed shows enough card**

In `layout_manager.dart`, update `handCardScale` (lines 39-44):

```dart
double get handCardScale {
  if (!isLandscape) return 1.4;
  // Target 35% of safe height visible (was 33%)
  return (safeRect.height * 0.35 / 100).clamp(1.0, 1.6);
}
```

- [ ] **Step 2: Fix portrait trick card scale to match hand for consistency**

Replace `trickCardScale` (lines 48-51):

```dart
/// Trick cards match hand scale in ALL orientations for visual consistency.
/// Hierarchy comes from position/rotation, not size difference.
double get trickCardScale => handCardScale;
```

- [ ] **Step 3: Increase portrait hand card spacing to prevent crowding**

In `handCardPositions` (line 185), increase portrait spacing:

```dart
: (85 - cardCount * 4.0).clamp(48.0, 76.0);
```

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/game/managers/layout_manager.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/game/managers/layout_manager.dart
git commit -m "fix(hand): increase card visibility, consistent trick scale, better spacing"
```

---

### Task 5: Opponent Card Fans — Visible in Landscape, Proper Size

**Why:** `OpponentHandFan` components are portrait-only (hidden via `_toggleVisibility`). In landscape, `OpponentNameLabel` has a tiny 38x54 card fan that looks like thumbnails. The fans need to be larger and more prominent.

**Files:**
- Modify: `lib/game/components/opponent_name_label.dart`
- Modify: `lib/game/managers/component_lifecycle_manager.dart`

- [ ] **Step 1: Increase OpponentNameLabel fan card size to 55% of base (was ~54%)**

In `opponent_name_label.dart`, update the mini card constants (lines 27-28):

```dart
static const double _miniCardW = 42.0;   // was 38 → now 55% of 70 ≈ 38.5, round to 42
static const double _miniCardH = 60.0;   // was 54 → now 55% of 100 = 55, round to 60
static const double _cardOverlap = 14.0; // keep
static const int _fanDisplayCount = 8;   // show all cards, was 5
```

- [ ] **Step 2: Increase OpponentNameLabel component sizes for landscape**

Update `_sizeForPlacement` (lines 48-53):

```dart
static Vector2 _sizeForPlacement(OpponentLabelPlacement p) {
  return switch (p) {
    OpponentLabelPlacement.top => Vector2(200, 100),    // was 180x90
    OpponentLabelPlacement.left || OpponentLabelPlacement.right => Vector2(140, 150), // was 130x130
  };
}
```

- [ ] **Step 3: Run `flutter analyze`**

Run: `flutter analyze lib/game/components/opponent_name_label.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/opponent_name_label.dart
git commit -m "fix(opponents): larger card fans, show full hand count"
```

---

### Task 6: Trick Area — Card Ownership, Clean Stacking, Consistent Shadows

**Why:** Three cards piled in center with zero indication of who played what. Z-ordering + jitter makes stacking look random. Shadows inconsistent.

**Files:**
- Modify: `lib/game/components/trick_area.dart`

- [ ] **Step 1: Add ownership labels to trick cards**

Replace `updateState` method (lines 51-102):

```dart
void updateState(ClientGameState state) {
  // Remove old cards and labels
  for (final c in _trickCards) {
    c.removeFromParent();
  }
  _trickCards.clear();
  for (final l in _ownerLabels) {
    l.removeFromParent();
  }
  _ownerLabels.clear();

  final activeUids = state.currentTrickPlays.map((p) => p.playerUid).toSet();
  _cachedJitter.removeWhere((uid, _) => !activeUids.contains(uid));

  for (int i = 0; i < state.currentTrickPlays.length; i++) {
    final play = state.currentTrickPlays[i];
    final absoluteSeat = state.playerUids.indexOf(play.playerUid);
    if (absoluteSeat < 0) continue;

    final relativeSeat = layout.toRelativeSeat(absoluteSeat, mySeatIndex);
    final basePos = layout.trickCardPosition(relativeSeat);

    // Nudge inward for visual stacking
    final center = layout.trickCenter;
    final nudge = i * _nudgeFactor;
    final pos = basePos + (center - basePos) * nudge;

    // Reduced jitter for cleaner stacking (±3° instead of ±4.6°)
    final jitter = _cachedJitter.putIfAbsent(
      play.playerUid,
      () => (_random.nextDouble() - 0.5) * 0.10,
    );
    final angle = _seatBaseAngle(relativeSeat) + jitter;

    final trickScale = layout.isLandscape ? layout.trickCardScale : layout.trickCardScale;
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
      ..priority = 10 + i; // Higher base priority so trick cards render above labels

    _trickCards.add(cardComp);
    add(cardComp);

    // Ownership indicator: team-colored dot positioned between card and its seat edge
    final team = teamForSeat(absoluteSeat);
    final dotComp = _OwnerDotComponent(
      team: team,
      position: _ownerDotPosition(relativeSeat, pos),
    )..priority = 5 + i;
    _ownerLabels.add(dotComp);
    add(dotComp);
  }
}
```

- [ ] **Step 2: Add supporting fields and helper classes**

Add after line 25 (`_cachedJitter`):

```dart
final List<Component> _ownerLabels = [];
```

Add at the end of the file, before the closing:

```dart
/// Small team-colored dot near a trick card to indicate ownership.
Vector2 _ownerDotPosition(int relativeSeat, Vector2 cardPos) {
  const offset = 10.0;
  return switch (relativeSeat) {
    0 => cardPos + Vector2(0, 35),    // below (my card)
    1 => cardPos + Vector2(-35, 0),   // left of card
    2 => cardPos + Vector2(0, -35),   // above card
    3 => cardPos + Vector2(35, 0),    // right of card
    _ => cardPos,
  };
}
```

Add as a private class at the bottom of the file:

```dart
class _OwnerDotComponent extends PositionComponent {
  final Team team;

  _OwnerDotComponent({required this.team, required Vector2 position})
      : super(position: position, size: Vector2.all(10), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    final color = KoutTheme.teamColor(team);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      4,
      Paint()..color = color.withValues(alpha: 0.7),
    );
  }
}
```

- [ ] **Step 3: Add missing imports**

Add at top of `trick_area.dart` (after existing imports):

```dart
import '../../shared/models/game_state.dart' show Team, teamForSeat;
import '../theme/kout_theme.dart';
```

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/game/components/trick_area.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/trick_area.dart
git commit -m "feat(trick-area): add ownership dots, reduce jitter, consistent scale"
```

---

### Task 7: Active Turn Indicator — Prominent Glow in Landscape

**Why:** In landscape, `PlayerSeatComponent` (with its glow pulse) is hidden. `OpponentNameLabel` has only a subtle gold rect blur. Players can't tell whose turn it is.

**Files:**
- Modify: `lib/game/components/opponent_name_label.dart`

- [ ] **Step 1: Add pulsing glow to OpponentNameLabel when active**

Add a timer field after `cardCount` (line 23):

```dart
double _glowElapsed = 0.0;
static const double _glowCycleDuration = 1.6;
static const double _glowMinAlpha = 0.15;
static const double _glowMaxAlpha = 0.50;
```

Add an `update` override:

```dart
@override
void update(double dt) {
  super.update(dt);
  if (isActive) {
    _glowElapsed += dt;
  }
}
```

- [ ] **Step 2: Replace the static active glow with a pulsing one**

In `render()`, replace the `isActive` glow block with:

```dart
if (isActive) {
  final teamColor = KoutTheme.teamColor(team);
  final t = (_glowElapsed % _glowCycleDuration) / _glowCycleDuration;
  final wave = t < 0.5 ? t * 2 : 2 - t * 2;
  final alpha = _glowMinAlpha + (_glowMaxAlpha - _glowMinAlpha) * wave;

  final glowPaint = Paint()
    ..color = teamColor.withValues(alpha: alpha)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, isTop ? 12 : 10);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, isTop ? 12 : 10),
        width: isTop ? 150 : 110,
        height: isTop ? 28 : 24,
      ),
      Radius.circular(isTop ? 14 : 12),
    ),
    glowPaint,
  );
}
```

- [ ] **Step 3: Reset glow elapsed when active changes**

In `updateState()`, add after `isActive` assignment (line 67):

```dart
final wasActive = isActive;
// ... existing isActive assignment ...
if (isActive != wasActive) _glowElapsed = 0.0;
```

Wait — `isActive` is set on line 67. We need to capture the old value first. Reorder:

```dart
void updateState(ClientGameState state) {
  final uid = state.playerUids[seatIndex];
  final wasActive = isActive;
  playerName = shortUid(uid);
  team = teamForSeat(seatIndex);
  isActive = state.currentPlayerUid == uid;
  cardCount = state.cardCounts[seatIndex] ?? 8;
  if (isActive && !wasActive) _glowElapsed = 0.0;
  // ... rest of method
}
```

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/game/components/opponent_name_label.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/opponent_name_label.dart
git commit -m "feat(turn-indicator): pulsing team-colored glow on active player"
```

---

### Task 8: Table Background — Better Felt, Softer Vignette

**Why:** Green felt radial gradient is too centered with heavy vignette, looking like a 2012 Flash game. Needs to be subtler and more atmospheric.

**Files:**
- Modify: `lib/game/components/table_background.dart`
- Modify: `lib/game/theme/textures.dart`
- Modify: `lib/game/theme/diwaniya_colors.dart`

- [ ] **Step 1: Update felt gradient colors for richer, less neon green**

In `diwaniya_colors.dart`, update the table surface colors (keep originals for portrait):

```dart
// Landscape felt (richer, less saturated green)
static const Color feltCenter = Color(0xFF2A5438);
static const Color feltMid = Color(0xFF1E3F2A);
static const Color feltEdge = Color(0xFF142B1D);
```

- [ ] **Step 2: Update landscape background gradient**

In `table_background.dart`, replace landscape branch (lines 22-31):

```dart
if (isLandscape) {
  // Richer, wider radial felt gradient
  final feltShader = Gradient.radial(
    rect.center,
    rect.longestSide * 0.7, // wider spread (was 0.6)
    [DiwaniyaColors.feltCenter, DiwaniyaColors.feltMid, DiwaniyaColors.feltEdge],
    [0.0, 0.55, 1.0],
  );
  canvas.drawRect(rect, Paint()..shader = feltShader);
  TextureGenerator.drawVignette(canvas, rect, intensity: 0.35);
}
```

- [ ] **Step 3: Add intensity parameter to vignette**

In `textures.dart`, update `drawVignette` signature (line 53):

```dart
static void drawVignette(Canvas canvas, Rect bounds, {double intensity = 0.5}) {
  final center = bounds.center;
  final radius = math.max(bounds.width, bounds.height) * 0.7;

  final vignetteShader = Gradient.radial(
    center,
    radius,
    [
      const Color(0x00000000),
      const Color(0x00000000),
      DiwaniyaColors.vignette.withValues(alpha: intensity * 0.8),
      DiwaniyaColors.vignette.withValues(alpha: intensity),
    ],
    [0.0, 0.5, 0.8, 1.0],
  );

  canvas.drawRect(bounds, Paint()..shader = vignetteShader);
}
```

Update the portrait call in `table_background.dart` line 34 to use default (unchanged behavior):

```dart
TextureGenerator.drawVignette(canvas, rect); // uses default intensity 0.5
```

- [ ] **Step 4: Run `flutter analyze`**

Run: `flutter analyze lib/game/components/table_background.dart lib/game/theme/textures.dart lib/game/theme/diwaniya_colors.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/table_background.dart lib/game/theme/textures.dart lib/game/theme/diwaniya_colors.dart
git commit -m "fix(background): richer felt gradient, softer vignette"
```

---

### Task 9: ~~Overlay Landscape Scaling~~ — ALREADY IMPLEMENTED

**Status:** ✅ No changes needed.

`overlay_animation_wrapper.dart` already handles landscape scaling at lines 75-76:

```dart
final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
final landscapeScale = isLandscape ? 0.75 : 1.0;
```

And already wraps content in `SafeArea` + `Center` + `Transform.scale` (lines 83-91). This was implemented in a prior iteration. Skip this task during execution.

---

### Task 10: Integration Verification

**Why:** All tasks touch layout. Need to verify nothing overlaps and the full game flow works.

**Files:**
- No modifications — testing only.

- [ ] **Step 1: Run full `flutter analyze`**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 2: Run `flutter test`**

Run: `flutter test`
Expected: All tests pass (or pre-existing failures only)

- [ ] **Step 3: Visual verification checklist**

Launch the app in landscape on a device/simulator and verify:

1. HUD is top-left, anchored against safe area, with readable labels
2. "SCORE" label visible above the score number
3. Trump suit symbol is visible (gold for black suits)
4. Timer shows without looking like a recording indicator
5. Partner label centered at top
6. Left/right opponents symmetrically placed
7. "You" label at bottom-right near hand
8. All opponent fans show correct card count (up to 8)
9. Active player has pulsing team-colored glow
10. Hand cards visible with proper bleed (bottom 20% hidden, rest visible)
11. Trick cards same scale as hand cards
12. Trick card ownership dots visible (team-colored)
13. Card stacking in trick area shows play order (later on top, slight inward nudge)
14. Felt gradient is rich, not neon
15. Vignette is subtle, not heavy
16. Overlays (bid, trump) scale to 75% in landscape
17. No element overlaps another (HUD vs left opponent, partner vs HUD, etc.)

- [ ] **Step 4: Commit any final tweaks**

```bash
git add -A
git commit -m "polish: final integration adjustments for landscape UI"
```
