# Offline Mode Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Full polish pass for offline single-player mode — sound effects, overlay animations, screen theming, enhanced round result/game over overlays, and component polish.

**Architecture:** Bottom-up incremental approach. First add foundation systems (sound manager, overlay animation mixin), then apply them to all overlays and screens, then polish individual components. Each task produces independently testable changes.

**Tech Stack:** Flutter/Flame, `audioplayers` package for sound, existing `KoutTheme` design tokens.

**Spec:** `docs/superpowers/specs/2026-03-24-offline-polish-design.md`

---

## File Structure

### New Files
- `lib/game/managers/sound_manager.dart` — Sound preloading and playback, mute toggle
- `lib/game/overlays/overlay_animation_wrapper.dart` — Reusable scale+fade animation wrapper widget

### Modified Files
- `pubspec.yaml` — Add `audioplayers` dep, declare `assets/sounds/` and `assets/fonts/`
- `lib/game/kout_game.dart` — Wire SoundManager, snapshot scores for round result, add victory particle burst
- `lib/app/screens/game_screen.dart` — Store OfflineGameMode, add onPlayAgain callback, mute button, pass previousScores to round result
- `lib/game/overlays/bid_overlay.dart` — Wrap in OverlayAnimationWrapper, add button press animation
- `lib/game/overlays/trump_selector.dart` — Wrap in OverlayAnimationWrapper, add button press animation
- `lib/game/overlays/round_result_overlay.dart` — Redesign with progress bars, score delta animation
- `lib/game/overlays/game_over_overlay.dart` — Add celebration, Play Again button, two callbacks
- `lib/app/screens/home_screen.dart` — Apply KoutTheme colors/fonts
- `lib/app/screens/offline_lobby_screen.dart` — Light theme polish
- `lib/game/components/score_display.dart` — Score change pulse animation, progress bars, height 44→52
- `lib/game/managers/layout_manager.dart` — Adjust score panel height constant
- `lib/game/components/hand_component.dart` — Card touch-down lift effect
- `lib/game/components/card_component.dart` — Add onTapDown lift, onTapUp play, hover on desktop
- `lib/game/components/player_seat.dart` — Enhanced glow, trick-win flash

---

## Task 1: Add `audioplayers` dependency and asset declarations

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add audioplayers dependency and asset declarations to pubspec.yaml**

In `pubspec.yaml`, add `audioplayers` to dependencies and declare asset directories:

```yaml
dependencies:
  # ... existing deps ...
  audioplayers: ^6.1.0
```

And in the flutter section, uncomment/add assets:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sounds/
```

- [ ] **Step 2: Create assets/sounds directory with a placeholder file**

```bash
mkdir -p assets/sounds
touch assets/sounds/.gitkeep
```

- [ ] **Step 3: Run flutter pub get**

```bash
flutter pub get
```

Expected: resolves without errors.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/sounds/.gitkeep
git commit -m "chore: add audioplayers dependency and sounds asset directory"
```

---

## Task 2: Create SoundManager

**Files:**
- Create: `lib/game/managers/sound_manager.dart`

- [ ] **Step 1: Create SoundManager class**

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static const _muteKey = 'sound_muted';

  final Map<String, AudioPlayer> _players = {};
  bool _muted = false;
  bool _disposed = false;

  bool get muted => _muted;

  final List<String> _soundNames = [
    'card_play',
    'deal',
    'trick_win',
    'trick_collect',
    'round_win',
    'round_loss',
    'victory',
    'defeat',
    'poison_joker',
    'bid',
    'trump',
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? false;

    for (final name in _soundNames) {
      _players[name] = AudioPlayer();
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _muted);
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _muted);
  }

  Future<void> _play(String name) async {
    if (_muted || _disposed) return;
    final player = _players[name];
    if (player == null) return;
    try {
      await player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // Sound file may not exist yet (placeholder phase) — silently skip
    }
  }

  void playCardSound() => _play('card_play');
  void playDealSound() => _play('deal');
  void playTrickWinSound() => _play('trick_win');
  void playTrickCollectSound() => _play('trick_collect');
  void playRoundWinSound() => _play('round_win');
  void playRoundLossSound() => _play('round_loss');
  void playVictorySound() => _play('victory');
  void playDefeatSound() => _play('defeat');
  void playPoisonJokerSound() => _play('poison_joker');
  void playBidSound() => _play('bid');
  void playTrumpSound() => _play('trump');

  void dispose() {
    _disposed = true;
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/game/managers/sound_manager.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/game/managers/sound_manager.dart
git commit -m "feat: add SoundManager with mute toggle and sound playback methods"
```

---

## Task 3: Wire SoundManager into KoutGame

**Files:**
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Add SoundManager field and initialization**

In `KoutGame` class, add a `SoundManager` field. In `onLoad()`, create and init it. In `onRemove()`, dispose it.

Import:
```dart
import 'package:bahraini_kout/game/managers/sound_manager.dart';
```

Add field:
```dart
late final SoundManager soundManager;
```

In `onLoad()`, after creating `_animationManager`:
```dart
soundManager = SoundManager();
await soundManager.init();
```

Add or update `onRemove()`:
```dart
@override
void onRemove() {
  _stateSubscription?.cancel();
  soundManager.dispose();
  super.onRemove();
}
```

- [ ] **Step 2: Wire sound calls to existing animation hooks**

In `AnimationManager`, the audio hooks are no-ops. Instead of modifying AnimationManager, wire sounds at the KoutGame level where events are triggered.

In `_updateTrickArea()`, where `_animationManager.animateCardPlay()` is called, add:
```dart
soundManager.playCardSound();
```

Where trick collection happens, add:
```dart
soundManager.playTrickCollectSound();
```

Where trick win particles fire, add:
```dart
soundManager.playTrickWinSound();
```

In `_updateOverlays()`, where poison joker is detected (if applicable), add:
```dart
soundManager.playPoisonJokerSound();
```

- [ ] **Step 3: Verify it compiles**

```bash
flutter analyze lib/game/kout_game.dart
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/game/kout_game.dart
git commit -m "feat: wire SoundManager into KoutGame for game event sounds"
```

---

## Task 4: Create OverlayAnimationWrapper

**Files:**
- Create: `lib/game/overlays/overlay_animation_wrapper.dart`

- [ ] **Step 1: Create the reusable animation wrapper widget**

```dart
import 'package:flutter/material.dart';

/// Wraps overlay content with scale+fade entry/exit animation.
///
/// Usage:
/// ```dart
/// OverlayAnimationWrapper(
///   onDismissed: () => game.overlays.remove('overlayName'),
///   child: YourOverlayContent(...),
/// )
/// ```
class OverlayAnimationWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismissed;
  final Duration entryDuration;
  final Duration exitDuration;
  final Curve entryCurve;
  final Curve exitCurve;

  const OverlayAnimationWrapper({
    super.key,
    required this.child,
    this.onDismissed,
    this.entryDuration = const Duration(milliseconds: 250),
    this.exitDuration = const Duration(milliseconds: 150),
    this.entryCurve = Curves.easeOutBack,
    this.exitCurve = Curves.easeIn,
  });

  @override
  State<OverlayAnimationWrapper> createState() =>
      OverlayAnimationWrapperState();
}

class OverlayAnimationWrapperState extends State<OverlayAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.entryDuration,
      reverseDuration: widget.exitDuration,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.entryCurve,
        reverseCurve: widget.exitCurve,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );
    _controller.forward();
  }

  /// Call this to play the exit animation, then remove the overlay.
  Future<void> dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    await _controller.reverse();
    widget.onDismissed?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: _opacityAnimation.value * 0.4),
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/game/overlays/overlay_animation_wrapper.dart
```

Expected: No issues found. (Note: `AnimatedBuilder` is the correct Flutter widget name — verify. If the project's Flutter version uses `AnimatedBuilder` vs `AnimatedWidget`, adjust. The standard widget is `AnimatedBuilder`.)

- [ ] **Step 3: Commit**

```bash
git add lib/game/overlays/overlay_animation_wrapper.dart
git commit -m "feat: add OverlayAnimationWrapper for scale+fade overlay transitions"
```

---

## Task 5: Apply animation wrapper to BidOverlay

**Files:**
- Modify: `lib/game/overlays/bid_overlay.dart`
- Modify: `lib/app/screens/game_screen.dart` (overlay builder)

- [ ] **Step 1: Wrap BidOverlay content in OverlayAnimationWrapper**

In `bid_overlay.dart`, import the wrapper:
```dart
import 'package:bahraini_kout/game/overlays/overlay_animation_wrapper.dart';
```

Add `onDismiss` callback parameter to `BidOverlay`:
```dart
final VoidCallback? onDismiss;
```

Wrap the existing `Center(child: Container(...))` widget tree with `OverlayAnimationWrapper`. The existing background scrim (if any) should be removed since the wrapper provides one.

- [ ] **Step 2: Add button press scale animation**

For each bid button and the pass button, wrap in a `GestureDetector` with `onTapDown`/`onTapUp` that briefly scales the button to 0.95 using a local `AnimationController` or `Transform.scale` with setState.

Simpler approach: use `InkWell` with `splashColor` set to gold with low alpha instead of custom animation, to keep it simple.

- [ ] **Step 3: Wire sound in game_screen.dart**

In `game_screen.dart`, update the 'bid' overlay builder. When `onBid` or `onPass` is called, also call `koutGame.soundManager.playBidSound()`.

- [ ] **Step 4: Verify it compiles and test manually**

```bash
flutter analyze lib/game/overlays/bid_overlay.dart lib/app/screens/game_screen.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/game/overlays/bid_overlay.dart lib/app/screens/game_screen.dart
git commit -m "feat: add scale+fade animation and sound to bid overlay"
```

---

## Task 6: Apply animation wrapper to TrumpSelectorOverlay

**Files:**
- Modify: `lib/game/overlays/trump_selector.dart`
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Wrap TrumpSelectorOverlay in OverlayAnimationWrapper**

Same pattern as bid overlay — import wrapper, add `onDismiss` callback, wrap content.

- [ ] **Step 2: Add button press feedback and sound**

Add `InkWell` splash to suit buttons. In `game_screen.dart`, call `koutGame.soundManager.playTrumpSound()` in the trump overlay's `onSelect` callback.

- [ ] **Step 3: Verify and commit**

```bash
flutter analyze lib/game/overlays/trump_selector.dart lib/app/screens/game_screen.dart
git add lib/game/overlays/trump_selector.dart lib/app/screens/game_screen.dart
git commit -m "feat: add scale+fade animation and sound to trump selector overlay"
```

---

## Task 7: Redesign RoundResultOverlay

**Files:**
- Modify: `lib/game/overlays/round_result_overlay.dart`
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Add previousScoreA/previousScoreB parameters**

Add two new required parameters to `RoundResultOverlay`:
```dart
final int previousScoreA;
final int previousScoreB;
```

- [ ] **Step 2: Redesign the overlay layout**

Replace the existing simple layout with the score-focused design:

```dart
import 'package:bahraini_kout/game/overlays/overlay_animation_wrapper.dart';
import 'package:bahraini_kout/game/theme/kout_theme.dart';
```

The widget should be a `StatefulWidget` with `SingleTickerProviderStateMixin` for the count-up and progress bar animations.

Layout structure:
1. Headline: "Round Won!" (gold/green) or "Round Lost" (red) — large text
2. Trick breakdown box: "Your Team: N tricks" / "Opponent: N tricks" / "Bid: N (name) - Made/Missed"
3. Score change: "+N" with count-up animation (Tween<int> from 0 to delta, 300ms)
4. Progress bars: Two horizontal bars showing Team A and Team B progress to 31
   - Animate from `previousScore/31` to `currentScore/31` width ratio (400ms, easeOut)
   - Team A bar: gold color, Team B bar: brown color
   - Show numeric score at end of each bar
5. "Continue" button

Wrap everything in `OverlayAnimationWrapper`.

- [ ] **Step 3: Update game_screen.dart to pass previous scores**

In `game_screen.dart`, the 'roundResult' overlay builder needs access to previous scores. Add fields to `_GameScreenState`:

```dart
int _previousScoreA = 0;
int _previousScoreB = 0;
```

Subscribe to the game's state stream (or have KoutGame expose a callback) to snapshot scores before a round scoring phase. The simplest approach: in the overlay builder, compute delta from `koutGame.currentState` — but we need the *previous* scores.

Better approach: In `KoutGame`, add fields:
```dart
int previousScoreA = 0;
int previousScoreB = 0;
```

In `_updateOverlays()`, just before adding the 'roundResult' overlay, snapshot the current scores as previous:
```dart
if (state.phase == GamePhase.roundScoring && !overlays.isActive('roundResult')) {
  previousScoreA = _lastScoreA;
  previousScoreB = _lastScoreB;
  overlays.add('roundResult');
}
```

Track `_lastScoreA`/`_lastScoreB` in `_updateScoreDisplay()`.

In the overlay builder in `game_screen.dart`:
```dart
'roundResult': (ctx, game) {
  final koutGame = game as KoutGame;
  return RoundResultOverlay(
    state: koutGame.currentState!,
    previousScoreA: koutGame.previousScoreA,
    previousScoreB: koutGame.previousScoreB,
    onContinue: () { /* existing logic */ },
  );
}
```

- [ ] **Step 4: Add round win/loss sound**

In the overlay builder or in `_updateOverlays()`, when showing round result, call:
```dart
final myTeamWon = /* determine from state */;
if (myTeamWon) {
  soundManager.playRoundWinSound();
} else {
  soundManager.playRoundLossSound();
}
```

- [ ] **Step 5: Verify and commit**

```bash
flutter analyze lib/game/overlays/round_result_overlay.dart lib/app/screens/game_screen.dart lib/game/kout_game.dart
git add lib/game/overlays/round_result_overlay.dart lib/app/screens/game_screen.dart lib/game/kout_game.dart
git commit -m "feat: redesign round result overlay with progress bars, score animation, and sound"
```

---

## Task 8: Enhance GameOverOverlay

**Files:**
- Modify: `lib/game/overlays/game_over_overlay.dart`
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Add onPlayAgain callback and store game mode**

Add `onPlayAgain` callback to `GameOverOverlay`:
```dart
final VoidCallback onPlayAgain;
final VoidCallback onReturnToMenu;
```

In `game_screen.dart`, store the `OfflineGameMode` in state:
```dart
GameMode? _gameMode;  // stored in _initFromGameMode
```

- [ ] **Step 2: Redesign with celebration effects**

Make `GameOverOverlay` a `StatefulWidget` with animation controllers:

**Victory state:**
- Headline "Victory!" scales in via the wrapper's animation
- After 200ms delay, add a repeating gold glow pulse on the headline text (use `AnimationController` with `repeat(reverse: true)`, animate shadow blur/spread)
- Trigger gold particle burst via `KoutGame` — call a method that spawns 24 `_GoldParticleComponent` at screen center

**Defeat state:**
- Headline "Defeat" fades in with muted red color
- No extra effects

**Buttons:**
- "Play Again": filled gold button (`KoutTheme.accent` background, dark text)
- "Back to Lobby": outlined button (gold border, gold text, transparent background)

Wrap in `OverlayAnimationWrapper`.

- [ ] **Step 3: Wire Play Again navigation**

In `game_screen.dart` overlay builder:
```dart
'gameOver': (ctx, game) {
  final koutGame = game as KoutGame;
  return GameOverOverlay(
    state: koutGame.currentState!,
    onPlayAgain: () {
      koutGame.overlays.remove('gameOver');
      if (_gameMode is OfflineGameMode) {
        Navigator.of(ctx).pushReplacementNamed('/game', arguments: _gameMode);
      }
    },
    onReturnToMenu: () {
      koutGame.overlays.remove('gameOver');
      Navigator.of(ctx).pushNamedAndRemoveUntil('/', (route) => false);
    },
  );
}
```

- [ ] **Step 4: Wire victory/defeat sounds**

In `_updateOverlays()` in `kout_game.dart`, when game over overlay is shown:
```dart
if (state.phase == GamePhase.gameOver && !overlays.isActive('gameOver')) {
  final myTeamWon = /* determine */;
  if (myTeamWon) {
    soundManager.playVictorySound();
  } else {
    soundManager.playDefeatSound();
  }
  overlays.add('gameOver');
}
```

- [ ] **Step 5: Add victory particle burst method to KoutGame**

Add a public method to `KoutGame` that the overlay can call:
```dart
void spawnVictoryParticles() {
  _animationManager.animateTrickWin(
    layout.trickCenter,
    particleCount: 24,
    durationSeconds: 1.0,
  );
}
```

The overlay builder can call `koutGame.spawnVictoryParticles()` after a 200ms delay.

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze lib/game/overlays/game_over_overlay.dart lib/app/screens/game_screen.dart lib/game/kout_game.dart
git add lib/game/overlays/game_over_overlay.dart lib/app/screens/game_screen.dart lib/game/kout_game.dart
git commit -m "feat: enhance game over overlay with celebration, Play Again, and sounds"
```

---

## Task 9: Theme HomeScreen

**Files:**
- Modify: `lib/app/screens/home_screen.dart`

- [ ] **Step 1: Bundle fonts locally for offline use**

The project currently uses `google_fonts` which downloads fonts at runtime. For offline mode, fonts must be bundled locally.

Download font files:
```bash
mkdir -p assets/fonts
# Download IBM Plex Mono (Regular + Bold)
curl -L -o assets/fonts/IBMPlexMono-Regular.ttf "https://github.com/IBM/plex/raw/master/IBM-Plex-Mono/fonts/complete/ttf/IBMPlexMono-Regular.ttf"
curl -L -o assets/fonts/IBMPlexMono-Bold.ttf "https://github.com/IBM/plex/raw/master/IBM-Plex-Mono/fonts/complete/ttf/IBMPlexMono-Bold.ttf"
# Download Noto Kufi Arabic (Regular + Bold)
curl -L -o assets/fonts/NotoKufiArabic-Regular.ttf "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoKufiArabic/NotoKufiArabic-Regular.ttf"
curl -L -o assets/fonts/NotoKufiArabic-Bold.ttf "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoKufiArabic/NotoKufiArabic-Bold.ttf"
```

Add font declarations to `pubspec.yaml` in the flutter section:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sounds/
  fonts:
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
        - asset: assets/fonts/IBMPlexMono-Bold.ttf
          weight: 700
    - family: NotoKufiArabic
      fonts:
        - asset: assets/fonts/NotoKufiArabic-Regular.ttf
        - asset: assets/fonts/NotoKufiArabic-Bold.ttf
          weight: 700
```

- [ ] **Step 2: Update KoutTheme to use bundled fonts instead of google_fonts**

In `lib/game/theme/kout_theme.dart`, replace `GoogleFonts.ibmPlexMono(...)` calls with `TextStyle(fontFamily: 'IBMPlexMono', ...)` and `GoogleFonts.notoKufiArabic(...)` with `TextStyle(fontFamily: 'NotoKufiArabic', ...)`. Remove the `google_fonts` import.

- [ ] **Step 3: Remove google_fonts dependency**

In `pubspec.yaml`, remove `google_fonts: ^6.0.0` from dependencies. Run `flutter pub get`.

- [ ] **Step 4: Apply KoutTheme colors and fonts to HomeScreen**

Import:
```dart
import 'package:bahraini_kout/game/theme/kout_theme.dart';
```

Changes:
- `Scaffold` backgroundColor: `KoutTheme.table`
- Title text: `KoutTheme.textColor`, use `KoutTheme.headingStyle` (IBM Plex Mono 24pt bold cream)
- Add Arabic subtitle below title: "كوت البحريني" using `KoutTheme.arabicHeadingStyle`
- Buttons: `ElevatedButton.styleFrom(backgroundColor: KoutTheme.primary, foregroundColor: KoutTheme.accent)` with rounded corners (`borderRadius: 12`)
- Button border: `side: BorderSide(color: KoutTheme.accent, width: 1.5)`
- Loading spinner: `CircularProgressIndicator(color: KoutTheme.accent)`

- [ ] **Step 5: Verify visually**

```bash
flutter pub get
flutter analyze lib/app/screens/home_screen.dart lib/game/theme/kout_theme.dart
```

Then run the app and verify the home screen looks themed with bundled fonts (works without network).

- [ ] **Step 6: Commit**

```bash
git add assets/fonts/ pubspec.yaml pubspec.lock lib/game/theme/kout_theme.dart lib/app/screens/home_screen.dart
git commit -m "feat: bundle fonts locally and apply Diwaniya theme to home screen"
```

---

## Task 10: Polish OfflineLobbyScreen

**Files:**
- Modify: `lib/app/screens/offline_lobby_screen.dart`

- [ ] **Step 1: Apply theme colors**

Import KoutTheme. Apply:
- `Scaffold` backgroundColor: `KoutTheme.table`
- AppBar: backgroundColor `KoutTheme.primary`, foreground `KoutTheme.textColor`
- Table preview background: keep burgundy, add `BoxShadow` with gold at low alpha. Add geometric pattern overlay at 8% opacity via `CustomPaint` using `GeometricPatterns.drawStarTessellation()`
- Human player seat (index 0): add gold glow `BoxShadow(color: KoutTheme.accent.withValues(alpha: 0.4), blurRadius: 12)`
- "Start Game" button: same style as home screen (burgundy + gold border)
- All text: `KoutTheme.textColor`

- [ ] **Step 2: Verify and commit**

```bash
flutter analyze lib/app/screens/offline_lobby_screen.dart
git add lib/app/screens/offline_lobby_screen.dart
git commit -m "feat: apply Diwaniya theme to offline lobby screen"
```

---

## Task 11: Score display animation and progress bars

**Files:**
- Modify: `lib/game/components/score_display.dart`
- Modify: `lib/game/managers/layout_manager.dart`

- [ ] **Step 1: Increase panel height**

In `score_display.dart`, change `_panelHeight` from `44.0` to `52.0`.

In `layout_manager.dart`, if the score panel height is referenced (check `handCenter`, `partnerSeat`, or any Y offset that assumes 44px), update accordingly. The `partnerSeat` Y position of `80` should be fine since it's already below a 44px panel. But verify nothing clips.

- [ ] **Step 2: Add progress bars to render()**

In `render()`, after drawing the score text, add two thin horizontal bars:

```dart
// Progress bar for Team A (left side)
final barY = size.y - 6; // 3px bar, 3px from bottom
final barHeight = 3.0;
final maxBarWidth = size.x * 0.35; // each bar takes ~35% of width

// Team A bar (left)
final scoreA = _state?.scores[Team.a] ?? 0;
final ratioA = (scoreA / 31).clamp(0.0, 1.0);
// Background track
canvas.drawRect(
  Rect.fromLTWH(8, barY, maxBarWidth, barHeight),
  Paint()..color = const Color(0x33F5ECD7),
);
// Fill
canvas.drawRect(
  Rect.fromLTWH(8, barY, maxBarWidth * ratioA, barHeight),
  Paint()..color = KoutTheme.teamAColor,
);

// Team B bar (right)
final scoreB = _state?.scores[Team.b] ?? 0;
final ratioB = (scoreB / 31).clamp(0.0, 1.0);
final rightBarX = size.x - 8 - maxBarWidth;
canvas.drawRect(
  Rect.fromLTWH(rightBarX, barY, maxBarWidth, barHeight),
  Paint()..color = const Color(0x33F5ECD7),
);
canvas.drawRect(
  Rect.fromLTWH(rightBarX, barY, maxBarWidth * ratioB, barHeight),
  Paint()..color = KoutTheme.teamBColor,
);
```

- [ ] **Step 3: Add score change pulse effect**

Track previous scores. When score changes, trigger a brief scale pulse:

Add fields:
```dart
int _prevScoreA = 0;
int _prevScoreB = 0;
double _pulseA = 1.0;
double _pulseB = 1.0;
```

In `updateState()`:
```dart
final newScoreA = state.scores[Team.a] ?? 0;
final newScoreB = state.scores[Team.b] ?? 0;
if (newScoreA != _prevScoreA) _pulseA = 1.3;
if (newScoreB != _prevScoreB) _pulseB = 1.3;
_prevScoreA = newScoreA;
_prevScoreB = newScoreB;
```

In `update(double dt)`:
```dart
if (_pulseA > 1.0) {
  _pulseA = (_pulseA - dt * 3).clamp(1.0, 1.3); // decay over ~100ms
}
if (_pulseB > 1.0) {
  _pulseB = (_pulseB - dt * 3).clamp(1.0, 1.3);
}
```

In `render()`, apply scale transform around score text using `canvas.save()` / `canvas.translate()` / `canvas.scale()` / `canvas.restore()`.

- [ ] **Step 4: Verify and commit**

```bash
flutter analyze lib/game/components/score_display.dart lib/game/managers/layout_manager.dart
git add lib/game/components/score_display.dart lib/game/managers/layout_manager.dart
git commit -m "feat: add progress bars and score pulse animation to score display"
```

---

## Task 12: Card touch-down lift effect

**Files:**
- Modify: `lib/game/components/card_component.dart`
- Modify: `lib/game/components/hand_component.dart`

- [ ] **Step 1: Add touch-down state to CardComponent**

In `card_component.dart`, add fields:
```dart
bool _pressed = false;
Vector2? _restPosition;
```

Change the tap handling from `onTapDown` directly calling `onTap` to a two-phase approach:

```dart
@override
void onTapDown(TapDownEvent event) {
  if (!isFaceUp || !isHighlighted) return;
  _pressed = true;
  _restPosition ??= position.clone();
  // Lift effect
  scale = Vector2.all(1.15);
  position.y = (_restPosition?.y ?? position.y) - 8;
}

@override
void onTapUp(TapUpEvent event) {
  if (_pressed) {
    _pressed = false;
    onTap?.call(card);
  }
}

@override
void onTapCancel(TapCancelEvent event) {
  if (_pressed) {
    _pressed = false;
    // Spring back
    scale = Vector2.all(1.0);
    if (_restPosition != null) {
      position = _restPosition!.clone();
    }
  }
}
```

Note: The `CardComponent` currently uses `TapCallbacks` mixin. Verify this mixin provides `onTapDown`, `onTapUp`, `onTapCancel`. If it only provides `onTapDown`, add `HasTappableComponents` or the appropriate Flame mixin.

- [ ] **Step 2: Add desktop/web hover effect**

On desktop and web, add pointer hover lift using Flame's `HoverCallbacks` mixin:

```dart
// Add to CardComponent class declaration:
// class CardComponent extends PositionComponent with TapCallbacks, HoverCallbacks {

@override
void onHoverEnter() {
  if (!isFaceUp || !isHighlighted) return;
  _restPosition ??= position.clone();
  scale = Vector2.all(1.15);
  position.y = (_restPosition?.y ?? position.y) - 8;
}

@override
void onHoverExit() {
  scale = Vector2.all(1.0);
  if (_restPosition != null) {
    position = _restPosition!.clone();
  }
}
```

Only add the `HoverCallbacks` mixin if the platform supports it. Check with `kIsWeb` or `Platform` at component creation time.

- [ ] **Step 3: Reset position on card rebuild**

In `HandComponent.updateState()`, when creating new `CardComponent` instances, ensure `_restPosition` is null so it gets set fresh on next tap.

- [ ] **Step 3: Verify and commit**

```bash
flutter analyze lib/game/components/card_component.dart lib/game/components/hand_component.dart
git add lib/game/components/card_component.dart lib/game/components/hand_component.dart
git commit -m "feat: add touch-down lift effect to playable cards"
```

---

## Task 13: Enhance PlayerSeat glow and trick-win flash

**Files:**
- Modify: `lib/game/components/player_seat.dart`

- [ ] **Step 1: Enhance active player glow**

In `_GlowPulseComponent`, increase the glow intensity:
- Change opacity range from `0.15 → 0.50` to `0.20 → 0.65`
- Increase blur radius from current value to `radius * 0.6` (was probably `radius * 0.4`)

- [ ] **Step 2: Add trick-win flash method**

Add a method to `PlayerSeatComponent`:
```dart
void flashTrickWin() {
  add(_TrickWinFlashComponent(radius: _radius));
}
```

Create inner class:
```dart
class _TrickWinFlashComponent extends Component with HasPaint {
  final double radius;
  double _life = 0.4; // 400ms flash

  _TrickWinFlashComponent({required this.radius});

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_life / 0.4 * 180).toInt().clamp(0, 180);
    canvas.drawCircle(
      Offset(parent!.size.x / 2, parent!.size.y / 2),
      radius + 4,
      Paint()
        ..color = KoutTheme.accent.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}
```

- [ ] **Step 3: Wire trick-win flash from KoutGame**

In `kout_game.dart`, when a trick is won (in `_updateTrickArea()` or wherever the winner is determined), call:
```dart
_seats[winnerRelativeSeat].flashTrickWin();
```

- [ ] **Step 4: Verify and commit**

```bash
flutter analyze lib/game/components/player_seat.dart lib/game/kout_game.dart
git add lib/game/components/player_seat.dart lib/game/kout_game.dart
git commit -m "feat: enhance player seat glow and add trick-win flash"
```

---

## Task 14: Add mute button to game screen

**Files:**
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Add mute toggle button**

In `game_screen.dart`, add a `Stack` or `Positioned` widget above the `GameWidget`. Place a small `IconButton` in the top-right corner:

```dart
Positioned(
  top: 8,
  right: 8,
  child: IconButton(
    icon: Icon(
      _koutGame?.soundManager.muted == true
          ? Icons.volume_off
          : Icons.volume_up,
      color: KoutTheme.accent,
      size: 24,
    ),
    onPressed: () {
      setState(() {
        _koutGame?.soundManager.toggleMute();
      });
    },
  ),
)
```

The game screen's build method currently returns a `GameWidget`. Wrap it in a `Stack` with the mute button on top.

- [ ] **Step 2: Verify and commit**

```bash
flutter analyze lib/app/screens/game_screen.dart
git add lib/app/screens/game_screen.dart
git commit -m "feat: add sound mute toggle button to game screen"
```

---

## Task 15: Final integration test

**Files:**
- No new files — manual verification

- [ ] **Step 1: Run flutter analyze on entire project**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 2: Run existing tests to verify no regressions**

```bash
flutter test
```

Expected: All existing tests pass.

- [ ] **Step 3: Manual smoke test**

Launch the app and verify:
1. Home screen has Diwaniya theme (dark brown background, cream text, gold buttons)
2. Offline lobby has matching theme, gold glow on human seat
3. Start a game — bid overlay scales in with animation
4. Trump selector scales in with animation
5. Cards lift on touch-down
6. Score display shows progress bars
7. Round result shows progress bars and score delta
8. Play through to game over — victory headline pulses gold, particles burst
9. "Play Again" button starts a new game with same setup
10. "Back to Lobby" returns to lobby
11. Mute button toggles (no crash even without sound files)

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: integration fixes from smoke test"
```
