# HUD Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 6 scattered HUD elements with one unified top-right info panel, add bidder glow ring, add game timer, and remove card count badges + sound toggle.

**Architecture:** Delete `ScoreHudComponent` and `GameHudComponent`. Create a single `UnifiedHudComponent` (Flame `PositionComponent`) with dynamic height based on game phase. Add `isBidder` + glow ring to `PlayerSeatComponent`. Wire everything through `KoutGame._onStateUpdate()`.

**Tech Stack:** Dart/Flutter, Flame engine, Canvas API

**Spec:** `docs/superpowers/specs/2026-04-02-hud-redesign-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/game/components/unified_hud.dart` | Create | Single top-right panel: score, round, bid+trump, pips, timer |
| `lib/game/components/player_seat.dart` | Modify | Add `isBidder`/`bidderGlowColor` fields + static outer glow ring |
| `lib/game/kout_game.dart` | Modify | Replace `_scoreHud`/`_gameHud` with `_unifiedHud`, add `_gameTimer`, add `_updateBidderGlow()` |
| `lib/game/components/opponent_hand_fan.dart` | Modify | Remove card count badge rendering |
| `lib/app/screens/game_screen.dart` | Modify | Remove sound toggle widget |
| `lib/game/components/score_hud.dart` | Delete | Replaced by UnifiedHudComponent |
| `lib/game/components/game_hud.dart` | Delete | Absorbed into UnifiedHudComponent |
| `test/game/unified_hud_test.dart` | Create | Tests for UnifiedHudComponent |
| `test/game/player_seat_bidder_glow_test.dart` | Create | Tests for bidder glow ring |
| `test/game/score_hud_test.dart` | Delete | Component deleted |
| `test/game/game_hud_test.dart` | Delete | Component deleted |
| `test/game/kout_game_test.dart` | Modify | Update for `_unifiedHud` and `_gameTimer` |

---

### Task 1: Create UnifiedHudComponent — tests

**Files:**
- Create: `test/game/unified_hud_test.dart`

- [ ] **Step 1: Write unit tests for UnifiedHudComponent**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/unified_hud.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';

void main() {
  group('UnifiedHudComponent', () {
    test('positions at top-right with 12px margin', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      expect(hud.position.x, closeTo(800 - 160 - 12, 1));
      expect(hud.position.y, 10);
    });

    test('updateWidth repositions for new screen width', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateWidth(1024);
      expect(hud.position.x, closeTo(1024 - 160 - 12, 1));
    });

    test('default state has score 0, round 1, no bid', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      expect(hud.score, 0);
      expect(hud.roundNumber, 1);
      expect(hud.bidValue, isNull);
      expect(hud.trumpSuit, isNull);
    });

    test('updateState sets score and round from state', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateState(
        phase: GamePhase.playing,
        teamAScore: 10,
        teamBScore: 0,
        roundNumber: 3,
        bidValue: 6,
        bidderTeam: Team.a,
        trumpSuit: Suit.hearts,
        bidderTricks: 2,
        opponentTricks: 1,
        opponentTarget: 3,
      );
      expect(hud.score, 10);
      expect(hud.roundNumber, 3);
      expect(hud.bidValue, 6);
      expect(hud.trumpSuit, Suit.hearts);
    });

    test('updateTimer sets elapsed duration', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateTimer(const Duration(minutes: 5, seconds: 30));
      expect(hud.timerText, '05:30');
    });

    test('timer clamps at 59:59', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateTimer(const Duration(hours: 2));
      expect(hud.timerText, '59:59');
    });

    test('computePips clamps to target', () {
      expect(UnifiedHudComponent.computePips(target: 5, tricksTaken: 8), 5);
    });

    test('computePips returns actual tricks when under target', () {
      expect(UnifiedHudComponent.computePips(target: 6, tricksTaken: 3), 3);
    });

    test('computePips clamps negative to 0', () {
      expect(UnifiedHudComponent.computePips(target: 5, tricksTaken: -1), 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/game/unified_hud_test.dart`
Expected: Compilation error — `UnifiedHudComponent` doesn't exist yet.

---

### Task 2: Create UnifiedHudComponent — implementation

**Files:**
- Create: `lib/game/components/unified_hud.dart`

- [ ] **Step 1: Create the UnifiedHudComponent file**

```dart
import 'dart:ui';
import 'package:flame/components.dart';
import '../../shared/models/game_state.dart';
import '../../shared/models/card.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/kout_theme.dart';
import '../theme/text_renderer.dart';

/// Unified top-right HUD panel combining score, round, bid/trump, trick pips, and game timer.
class UnifiedHudComponent extends PositionComponent {
  static const double _hudWidth = 160.0;
  static const double _pipRadius = 4.5;
  static const double _pipSpacing = 13.0;
  static const double _dividerHeight = 1.0;
  static const double _padding = 12.0;
  static const double _rowGap = 6.0;

  // Public state — set via updateState() and updateTimer()
  int score = 0;
  Color scoreColor = DiwaniyaColors.cream;
  int roundNumber = 1;
  int? bidValue;
  Team? bidderTeam;
  Suit? trumpSuit;
  int bidderTricks = 0;
  int opponentTricks = 0;
  int opponentTarget = 0;
  GamePhase _phase = GamePhase.waiting;
  String timerText = '00:00';

  UnifiedHudComponent({required double screenWidth})
      : super(
          position: Vector2(screenWidth - _hudWidth - 12, 10),
          size: Vector2(_hudWidth, 80), // initial; recalculated on render
          anchor: Anchor.topLeft,
        );

  void updateWidth(double newWidth) {
    position = Vector2(newWidth - _hudWidth - 12, 10);
  }

  void updateState({
    required GamePhase phase,
    required int teamAScore,
    required int teamBScore,
    required int roundNumber,
    int? bidValue,
    Team? bidderTeam,
    Suit? trumpSuit,
    int bidderTricks = 0,
    int opponentTricks = 0,
    int opponentTarget = 0,
  }) {
    _phase = phase;
    this.roundNumber = roundNumber;
    this.bidValue = bidValue;
    this.bidderTeam = bidderTeam;
    this.trumpSuit = trumpSuit;
    this.bidderTricks = bidderTricks;
    this.opponentTricks = opponentTricks;
    this.opponentTarget = opponentTarget;

    // Tug-of-war score: only one team ever has non-zero
    if (teamAScore > 0) {
      score = teamAScore;
      scoreColor = KoutTheme.teamAColor;
    } else if (teamBScore > 0) {
      score = teamBScore;
      scoreColor = KoutTheme.teamBColor;
    } else {
      score = 0;
      scoreColor = DiwaniyaColors.cream;
    }
  }

  void updateTimer(Duration elapsed) {
    final totalSeconds = elapsed.inSeconds.clamp(0, 3599); // max 59:59
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    timerText = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static int computePips({required int target, required int tricksTaken}) {
    return tricksTaken.clamp(0, target);
  }

  bool get _showBidRow =>
      _phase == GamePhase.trumpSelection ||
      _phase == GamePhase.bidAnnouncement ||
      _phase == GamePhase.playing ||
      _phase == GamePhase.roundScoring;

  bool get _showPips =>
      _phase == GamePhase.playing || _phase == GamePhase.roundScoring;

  double _computeHeight() {
    double h = _padding; // top padding
    h += 30; // score + round row
    h += _rowGap;
    h += _dividerHeight; // divider
    h += _rowGap;
    if (_showBidRow) {
      h += 18; // bid + trump row
      h += _rowGap;
    }
    if (_showPips) {
      h += 16 + 16; // two pip rows
      h += _rowGap;
      h += _dividerHeight;
      h += _rowGap;
    }
    h += 16; // timer row
    h += _padding; // bottom padding
    return h;
  }

  @override
  void render(Canvas canvas) {
    final hudHeight = _computeHeight();
    size = Vector2(_hudWidth, hudHeight);

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, hudHeight),
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

    double y = _padding;

    // --- Row 1: Score + Round ---
    TextRenderer.draw(canvas, '$score', scoreColor,
        Offset(_padding, y), 28, align: TextAlign.left, width: 60);
    TextRenderer.draw(canvas, '/ 31',
        DiwaniyaColors.cream.withValues(alpha: 0.5),
        Offset(_padding + 50, y + 10), 11, align: TextAlign.left, width: 40);
    TextRenderer.draw(canvas, 'R$roundNumber',
        DiwaniyaColors.cream.withValues(alpha: 0.5),
        Offset(_hudWidth - _padding - 30, y + 10), 11,
        align: TextAlign.right, width: 30);
    y += 30 + _rowGap;

    // --- Divider ---
    canvas.drawLine(
      Offset(_padding, y),
      Offset(_hudWidth - _padding, y),
      Paint()..color = DiwaniyaColors.scoreHudBorder,
    );
    y += _dividerHeight + _rowGap;

    // --- Row 2: Bid + Trump (conditional) ---
    if (_showBidRow && bidValue != null) {
      final bidTeamColor = bidderTeam == Team.a
          ? KoutTheme.teamAColor
          : bidderTeam == Team.b
              ? KoutTheme.teamBColor
              : DiwaniyaColors.cream;

      final bidText = bidValue == 8 ? 'KOUT' : 'BID $bidValue';
      TextRenderer.draw(canvas, bidText, bidTeamColor,
          Offset(_padding, y), 12, align: TextAlign.left, width: 80);

      if (trumpSuit != null) {
        final suitSymbol = _suitSymbol(trumpSuit!);
        final suitColor = (trumpSuit == Suit.hearts || trumpSuit == Suit.diamonds)
            ? const Color(0xFFCC3333)
            : DiwaniyaColors.cream;
        TextRenderer.draw(canvas, suitSymbol, suitColor,
            Offset(_hudWidth - _padding - 16, y), 14,
            align: TextAlign.right, width: 16);
      }
      y += 18 + _rowGap;
    }

    // --- Row 3: Trick Pips (conditional) ---
    if (_showPips && bidValue != null) {
      final bidTeamColor = bidderTeam == Team.a
          ? KoutTheme.teamAColor
          : KoutTheme.teamBColor;
      final oppTeamColor = bidderTeam == Team.a
          ? KoutTheme.teamBColor
          : KoutTheme.teamAColor;

      _drawPipRow(canvas, y + 4, bidValue!, bidderTricks, bidTeamColor);
      y += 16;
      _drawPipRow(canvas, y + 4, opponentTarget, opponentTricks, oppTeamColor);
      y += 16 + _rowGap;

      // Divider before timer
      canvas.drawLine(
        Offset(_padding, y),
        Offset(_hudWidth - _padding, y),
        Paint()..color = DiwaniyaColors.scoreHudBorder,
      );
      y += _dividerHeight + _rowGap;
    }

    // --- Row 4: Timer ---
    TextRenderer.draw(canvas, timerText,
        DiwaniyaColors.cream.withValues(alpha: 0.65),
        Offset(_hudWidth / 2, y), 12,
        align: TextAlign.center, width: _hudWidth);
  }

  void _drawPipRow(Canvas canvas, double y, int total, int filled, Color color) {
    final clamped = filled.clamp(0, total);
    final totalWidth = (total - 1) * _pipSpacing;
    final startX = (_hudWidth - totalWidth) / 2;

    for (int i = 0; i < total; i++) {
      final cx = startX + i * _pipSpacing;
      if (i < clamped) {
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

  static String _suitSymbol(Suit suit) {
    const symbols = {
      Suit.spades: '♠',
      Suit.hearts: '♥',
      Suit.clubs: '♣',
      Suit.diamonds: '♦',
    };
    return symbols[suit] ?? '?';
  }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/game/unified_hud_test.dart`
Expected: All 9 tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/unified_hud.dart test/game/unified_hud_test.dart
git commit -m "feat: add UnifiedHudComponent with score, bid, pips, timer"
```

---

### Task 3: Add bidder glow ring to PlayerSeatComponent

**Files:**
- Create: `test/game/player_seat_bidder_glow_test.dart`
- Modify: `lib/game/components/player_seat.dart`

- [ ] **Step 1: Write tests for bidder glow fields**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/player_seat.dart';
import 'package:koutbh/game/theme/kout_theme.dart';

void main() {
  group('PlayerSeatComponent bidder glow', () {
    test('isBidder defaults to false', () {
      final seat = PlayerSeatComponent(
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
      );
      expect(seat.isBidder, isFalse);
      expect(seat.bidderGlowColor, isNull);
    });

    test('setBidderGlow sets fields correctly', () {
      final seat = PlayerSeatComponent(
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
      );
      seat.setBidderGlow(true, KoutTheme.teamAColor);
      expect(seat.isBidder, isTrue);
      expect(seat.bidderGlowColor, KoutTheme.teamAColor);
    });

    test('clearBidderGlow resets fields', () {
      final seat = PlayerSeatComponent(
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
      );
      seat.setBidderGlow(true, KoutTheme.teamAColor);
      seat.setBidderGlow(false, null);
      expect(seat.isBidder, isFalse);
      expect(seat.bidderGlowColor, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/game/player_seat_bidder_glow_test.dart`
Expected: Compilation error — `isBidder` and `setBidderGlow` don't exist.

- [ ] **Step 3: Add bidder glow fields and rendering to PlayerSeatComponent**

In `lib/game/components/player_seat.dart`, add fields after line 18 (`String? bidLabel;`):

```dart
bool isBidder = false;
Color? bidderGlowColor;
```

Add method after `flashTrickWin()` (after line 207):

```dart
void setBidderGlow(bool bidder, Color? color) {
  isBidder = bidder;
  bidderGlowColor = color;
}
```

In `render()`, add bidder glow ring immediately after `_drawRopeBorder(canvas, center);` (line 50) and before `AvatarPainter.paint(canvas, center, ...)` (line 53). This renders the glow behind the avatar and behind the active-turn ring:

```dart
// Bidder glow ring — static, behind everything else
if (isBidder && bidderGlowColor != null) {
  final glowPaint = Paint()
    ..color = bidderGlowColor!.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
  canvas.drawCircle(center, _radius + 6, glowPaint);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/game/player_seat_bidder_glow_test.dart`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/game/components/player_seat.dart test/game/player_seat_bidder_glow_test.dart
git commit -m "feat: add bidder glow ring to PlayerSeatComponent"
```

---

### Task 4: Wire UnifiedHudComponent + game timer + bidder glow into KoutGame

**Files:**
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Update imports**

Replace these two imports:
```dart
import 'components/game_hud.dart';
import 'components/score_hud.dart';
```
With:
```dart
import 'components/unified_hud.dart';
```

- [ ] **Step 2: Replace field declarations**

Replace lines 44-45:
```dart
ScoreHudComponent? _scoreHud;
GameHudComponent? _gameHud;
```
With:
```dart
UnifiedHudComponent? _unifiedHud;
Stopwatch? _gameTimer;
```

- [ ] **Step 3: Replace `_updateScoreDisplay` method**

Replace the entire `_updateScoreDisplay` method (lines 194-209) with:

```dart
void _updateScoreDisplay(ClientGameState state) {
  _gameTimer ??= Stopwatch()..start();

  if (_unifiedHud == null) {
    final w = hasLayout ? size.x : 375.0;
    _unifiedHud = UnifiedHudComponent(screenWidth: w);
    add(_unifiedHud!);
  }

  final teamAScore = state.scores[Team.a] ?? 0;
  final teamBScore = state.scores[Team.b] ?? 0;
  final roundNumber = (state.trickWinners.length ~/ 8) + 1;

  int? bidValue;
  Team? bidderTeam;
  int bidderTricks = 0;
  int opponentTricks = 0;
  int opponentTarget = 0;

  if (state.bidderUid != null && state.currentBid != null) {
    bidValue = state.currentBid!.value;
    final bidderSeat = state.playerUids.indexOf(state.bidderUid!);
    if (bidderSeat >= 0) {
      bidderTeam = teamForSeat(bidderSeat);
      bidderTricks = state.tricks[bidderTeam] ?? 0;
      opponentTricks = state.tricks[bidderTeam.opponent] ?? 0;
      opponentTarget = 9 - bidValue;
    }
  }

  _unifiedHud!.updateState(
    phase: state.phase,
    teamAScore: teamAScore,
    teamBScore: teamBScore,
    roundNumber: roundNumber,
    bidValue: bidValue,
    bidderTeam: bidderTeam,
    trumpSuit: state.trumpSuit,
    bidderTricks: bidderTricks,
    opponentTricks: opponentTricks,
    opponentTarget: opponentTarget,
  );

  _unifiedHud!.updateTimer(_gameTimer!.elapsed);

  // Track scores for round result overlay
  if (state.phase != GamePhase.roundScoring) {
    _lastScoreA = state.scores[Team.a] ?? 0;
    _lastScoreB = state.scores[Team.b] ?? 0;
  }
}
```

- [ ] **Step 4: Delete `_updateGameHud` method and its call**

Remove the `_updateGameHud(state);` call from `_onStateUpdate` (line 190), AND delete the entire `_updateGameHud` method body (lines 464-472).

- [ ] **Step 5: Add `_updateBidderGlow` method**

Add after the `_updateSeats` method:

```dart
void _updateBidderGlow(ClientGameState state) {
  final showGlow = state.phase != GamePhase.bidding &&
      state.phase != GamePhase.waiting &&
      state.phase != GamePhase.dealing;

  for (int i = 0; i < _seats.length; i++) {
    final uid = state.playerUids[i];
    if (showGlow && uid == state.bidderUid) {
      final teamColor = i.isEven ? KoutTheme.teamAColor : KoutTheme.teamBColor;
      _seats[i].setBidderGlow(true, teamColor);
    } else {
      _seats[i].setBidderGlow(false, null);
    }
  }
}
```

- [ ] **Step 6: Wire `_updateBidderGlow` into `_onStateUpdate`**

In `_onStateUpdate` (line 184), add `_updateBidderGlow(state);` after `_updateSeats(state);` AND remove the `_updateGameHud(state);` call (line 190, already deleted in Step 4). Final method:

```dart
void _onStateUpdate(ClientGameState state) {
  _updateScoreDisplay(state);
  _updateSeats(state);
  _updateBidderGlow(state);
  _spawnActionBadges(state);
  _updateHand(state);
  _updateTrickArea(state);
  _updateOverlays(state);
}
```

- [ ] **Step 7: Update `onGameResize` to use `_unifiedHud`**

Replace `_scoreHud?.updateWidth(size.x);` in `onGameResize` with:
```dart
_unifiedHud?.updateWidth(size.x);
```

- [ ] **Step 8: Run existing KoutGame tests**

Run: `flutter test test/game/kout_game_test.dart`
Expected: All existing tests pass (they don't test HUD internals, just overlay logic).

- [ ] **Step 9: Commit**

```bash
git add lib/game/kout_game.dart
git commit -m "feat: wire UnifiedHudComponent, game timer, and bidder glow into KoutGame"
```

---

### Task 5: Remove card count badge from OpponentHandFan

**Files:**
- Modify: `lib/game/components/opponent_hand_fan.dart`

- [ ] **Step 1: Remove badge rendering**

Delete lines 136-144 of `opponent_hand_fan.dart` (the card count badge block):

```dart
    // Card count badge
    if (cardCount > 0) {
      final badgeCenter = Offset(size.x / 2, size.y / 2 + _miniHeight * 0.6);
      canvas.drawCircle(badgeCenter, 10, Paint()..color = DiwaniyaColors.actionBadgeBg);
      TextRenderer.drawCentered(
        canvas, '$cardCount', DiwaniyaColors.pureWhite, badgeCenter, 10,
        width: 20,
      );
    }
```

Also remove the unused imports that were only needed for the badge. Check if `DiwaniyaColors` and `TextRenderer` are still used elsewhere in the file — `DiwaniyaColors` is not used elsewhere after removing the badge, but keep it if other code uses it. `TextRenderer` import can be removed if unused.

Actually, checking the file: both `DiwaniyaColors` and `TextRenderer` imports are only used for the badge. Remove them:
```dart
// Remove these imports:
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
```

- [ ] **Step 2: Run existing opponent_hand_fan tests**

Run: `flutter test test/game/opponent_hand_fan_test.dart`
Expected: All tests pass. (Tests verify fan layout, not badge rendering.)

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/opponent_hand_fan.dart
git commit -m "fix: remove card count badge from opponent hand fans"
```

---

### Task 6: Remove sound toggle from GameScreen

**Files:**
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Remove the Positioned sound toggle widget**

Delete lines 225-241 of `game_screen.dart`:

```dart
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                _koutGame?.soundManager?.muted == true
                    ? Icons.volume_off
                    : Icons.volume_up,
                color: const Color(0xFF738C5A),
                size: 24,
              ),
              onPressed: () async {
                await _koutGame?.soundManager?.toggleMute();
                if (mounted) setState(() {});
              },
            ),
          ),
```

The `Stack` and `GameWidget` remain — just the sound `Positioned` widget is removed. The `Stack` still wraps the `GameWidget` (needed for overlays).

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/app/screens/game_screen.dart`
Expected: No errors. Check for unused imports — `Icons` may still be used by other overlays. If not, clean up.

- [ ] **Step 3: Commit**

```bash
git add lib/app/screens/game_screen.dart
git commit -m "fix: remove sound toggle button from game screen"
```

---

### Task 7: Delete old HUD components and their tests

**Files:**
- Delete: `lib/game/components/score_hud.dart`
- Delete: `lib/game/components/game_hud.dart`
- Delete: `test/game/score_hud_test.dart`
- Delete: `test/game/game_hud_test.dart`

- [ ] **Step 1: Delete files**

```bash
rm lib/game/components/score_hud.dart
rm lib/game/components/game_hud.dart
rm test/game/score_hud_test.dart
rm test/game/game_hud_test.dart
```

- [ ] **Step 2: Verify no remaining imports reference deleted files**

Run: `grep -r "score_hud\|game_hud" lib/ test/ --include="*.dart"`
Expected: No results (imports were already updated in Task 4).

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass with no compilation errors referencing deleted files.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete ScoreHudComponent and GameHudComponent (replaced by UnifiedHud)"
```

---

### Task 8: Full verification

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No errors, no warnings related to changed files.

- [ ] **Step 3: Run the app and visually verify**

Run: `flutter run`

Verify:
1. Unified HUD panel appears top-right with score + round number.
2. During bidding: only score row + timer visible. Bid/pass badges still appear above seats.
3. After trump selection: bid row appears with team color + trump suit symbol. Bidder's avatar has a static glow ring in team color.
4. During playing: trick pip rows appear. Timer keeps counting.
5. No sound toggle icon visible.
6. No card count badges under opponent fans.
7. No R1/T0 pill in top-left.
8. Game still plays correctly end-to-end.

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: polish unified HUD after visual verification"
```
