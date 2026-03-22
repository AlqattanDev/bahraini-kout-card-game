# Flame Game Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flame-based card table renderer — card components, hand fan layout, player seats, trick area, bid/trump overlays, and animations — all driven by the `ClientGameState` stream from the game service.

**Architecture:** `KoutGame` extends `FlameGame` and receives `ClientGameState` updates via a stream. Components react to state changes by updating their visual properties and triggering animations. Input (card taps, bid selection) flows back to `GameService` via callbacks.

**Tech Stack:** Flutter/Flame 1.x, Flame effects (`MoveEffect`, `ScaleEffect`, `OpacityEffect`)

**Spec:** `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md`

**Depends on:** Plan 1 (card models), Plan 3 (GameService + ClientGameState)

---

## File Structure

```
lib/
  game/
    kout_game.dart                # FlameGame subclass, state stream listener
    components/
      card_component.dart         # Single card: face, back, tap handling
      hand_component.dart         # Fan layout of player's cards
      player_seat.dart            # Avatar, name, card count, team indicator
      trick_area.dart             # Center area showing current trick cards
      score_display.dart          # Team scores, bid info
    overlays/
      bid_overlay.dart            # Bidding UI (Flutter overlay on Flame)
      trump_selector.dart         # Trump suit picker (Flutter overlay)
      round_result_overlay.dart   # Round result display
      game_over_overlay.dart      # Final result screen
    managers/
      animation_manager.dart      # Card animation sequencing
      layout_manager.dart         # Screen-size-aware positioning
    theme/
      kout_theme.dart             # Color constants, text styles

test/
  game/
    components/
      card_component_test.dart
      hand_component_test.dart
    kout_game_test.dart
```

---

### Task 1: KoutGame Shell & Theme

**Files:**
- Modify: `pubspec.yaml` (add flame dependency)
- Create: `lib/game/kout_game.dart`
- Create: `lib/game/theme/kout_theme.dart`
- Create: `lib/game/managers/layout_manager.dart`
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Add Flame dependency**

```yaml
# pubspec.yaml additions
dependencies:
  flame: ^1.17.0
```

Run: `flutter pub get`

- [ ] **Step 2: Implement theme constants**

```dart
// lib/game/theme/kout_theme.dart
import 'dart:ui';

class KoutTheme {
  static const Color primary = Color(0xFF5C1A1B);      // burgundy
  static const Color accent = Color(0xFFC9A84C);        // gold
  static const Color table = Color(0xFF3B2314);          // walnut
  static const Color textColor = Color(0xFFF5ECD7);      // cream
  static const Color secondary = Color(0xFF8B5E3C);      // copper

  static const Color cardBack = Color(0xFF5C1A1B);
  static const Color cardFace = Color(0xFFFFFFF0);
  static const Color cardBorder = Color(0xFFFFFFFF);

  static const Color teamAColor = Color(0xFFC9A84C);    // gold
  static const Color teamBColor = Color(0xFF8B5E3C);    // copper

  static const double cardWidth = 70;
  static const double cardHeight = 100;
  static const double cardBorderRadius = 6;
}
```

- [ ] **Step 3: Implement layout manager**

```dart
// lib/game/managers/layout_manager.dart
import 'dart:math';
import 'package:flame/game.dart';

class LayoutManager {
  final Vector2 screenSize;

  LayoutManager(this.screenSize);

  /// Bottom center — player's hand area
  Vector2 get handCenter => Vector2(screenSize.x / 2, screenSize.y - 120);

  /// Top center — partner's seat
  Vector2 get partnerSeat => Vector2(screenSize.x / 2, 80);

  /// Left center — opponent seat
  Vector2 get leftSeat => Vector2(60, screenSize.y / 2);

  /// Right center — opponent seat
  Vector2 get rightSeat => Vector2(screenSize.x - 60, screenSize.y / 2);

  /// Center — trick area
  Vector2 get trickCenter => Vector2(screenSize.x / 2, screenSize.y / 2);

  /// Card positions in trick area for each relative seat (0=bottom, 1=left, 2=top, 3=right)
  Vector2 trickCardPosition(int relativeSeat) {
    final center = trickCenter;
    return switch (relativeSeat) {
      0 => center + Vector2(0, 40),    // bottom player
      1 => center + Vector2(-50, 0),   // left player
      2 => center + Vector2(0, -40),   // top player
      3 => center + Vector2(50, 0),    // right player
      _ => center,
    };
  }

  /// Fan positions for N cards in hand
  List<({Vector2 position, double angle})> handCardPositions(int cardCount) {
    final positions = <({Vector2 position, double angle})>[];
    const maxFanAngle = 0.6; // radians total spread
    final angleStep = cardCount > 1 ? maxFanAngle / (cardCount - 1) : 0.0;
    final startAngle = -maxFanAngle / 2;

    for (var i = 0; i < cardCount; i++) {
      final angle = startAngle + (angleStep * i);
      final offset = Vector2(
        sin(angle) * 200,
        -cos(angle) * 30 + (angle.abs() * 20),
      );
      positions.add((position: handCenter + offset, angle: angle));
    }
    return positions;
  }
}
```

- [ ] **Step 4: Implement KoutGame shell**

```dart
// lib/game/kout_game.dart
import 'dart:async';
import 'package:flame/game.dart';
import '../app/models/client_game_state.dart';
import 'managers/layout_manager.dart';
import 'theme/kout_theme.dart';

class KoutGame extends FlameGame {
  final Stream<ClientGameState> stateStream;
  final void Function(String action, Map<String, dynamic> data) onAction;

  StreamSubscription<ClientGameState>? _stateSub;
  ClientGameState? _currentState;
  late LayoutManager layout;

  KoutGame({required this.stateStream, required this.onAction});

  @override
  Future<void> onLoad() async {
    layout = LayoutManager(size);

    _stateSub = stateStream.listen((state) {
      _currentState = state;
      _onStateUpdate(state);
    });
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    layout = LayoutManager(size);
  }

  void _onStateUpdate(ClientGameState state) {
    // Will be implemented as components are added
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    super.onRemove();
  }
}
```

- [ ] **Step 5: Wire GameScreen to KoutGame**

```dart
// lib/app/screens/game_screen.dart — updated
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../game/kout_game.dart';
import '../services/game_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameService _gameService;
  late KoutGame _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    _gameService = GameService(gameId: args['gameId']!, myUid: args['myUid']!);
    _gameService.startListening();

    _game = KoutGame(
      stateStream: _gameService.stateStream,
      onAction: (action, data) {
        switch (action) {
          case 'bid': _gameService.sendBid(data['amount'] as int);
          case 'pass': _gameService.sendPass();
          case 'trump': _gameService.sendTrumpSelection(data['suit'] as String);
          case 'play': _gameService.sendPlayCard(data['card'] as String);
        }
      },
    );
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: _game),
    );
  }
}
```

- [ ] **Step 6: Verify build**

Run: `flutter build apk --debug`
Expected: Compiles

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml lib/game/ lib/app/screens/game_screen.dart
git commit -m "feat: add KoutGame shell with layout manager, theme, and GameScreen integration"
```

---

### Task 2: Card Component

**Files:**
- Create: `lib/game/components/card_component.dart`
- Create: `test/game/components/card_component_test.dart`

- [ ] **Step 1: Write card component tests**

Tests: renders face-up with correct suit/rank, renders face-down (card back), tap callback fires, card encodes to correct string.

- [ ] **Step 2: Implement card component**

Renders a rounded rectangle with suit symbol and rank text. Face-down shows burgundy back with gold border. Supports `isFaceUp` toggle. `onTap` callback for hand interaction. Uses Flame's `PositionComponent` with custom `render()`.

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add lib/game/components/card_component.dart test/game/components/
git commit -m "feat: add card component with face/back rendering and tap handling"
```

---

### Task 3: Hand Component (Fan Layout)

**Files:**
- Create: `lib/game/components/hand_component.dart`
- Create: `test/game/components/hand_component_test.dart`

- [ ] **Step 1: Write hand component tests**

Tests: renders correct number of cards, cards are fanned, tapping a card invokes callback with card code, updates when hand changes (cards removed after play).

- [ ] **Step 2: Implement hand component**

Uses `LayoutManager.handCardPositions()` to position child `CardComponent`s in a fan. Highlights playable cards during PLAYING phase. Greyed-out cards that fail `PlayValidator.validatePlay()`.

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add lib/game/components/hand_component.dart test/game/components/
git commit -m "feat: add hand component with fan layout and playable card highlighting"
```

---

### Task 4: Player Seats & Trick Area

**Files:**
- Create: `lib/game/components/player_seat.dart`
- Create: `lib/game/components/trick_area.dart`

- [ ] **Step 1: Implement player seat**

Circular avatar frame (gold border), player name text, card count badge, team color indicator. Glow effect when it's that player's turn. Positioned by `LayoutManager`.

- [ ] **Step 2: Implement trick area**

Shows 0-4 cards in the center as they're played. Cards appear at positions based on which seat played them (relative to the human player). Clears after trick is resolved.

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/player_seat.dart lib/game/components/trick_area.dart
git commit -m "feat: add player seat and trick area components"
```

---

### Task 5: Score Display

**Files:**
- Create: `lib/game/components/score_display.dart`

- [ ] **Step 1: Implement score display**

Shows team scores (Team A vs Team B), current bid amount and bidder, trick count for current round. Positioned at top of screen. Updates reactively from `ClientGameState`.

- [ ] **Step 2: Commit**

```bash
git add lib/game/components/score_display.dart
git commit -m "feat: add score display component"
```

---

### Task 6: Flutter Overlays (Bid, Trump, Results)

**Files:**
- Create: `lib/game/overlays/bid_overlay.dart`
- Create: `lib/game/overlays/trump_selector.dart`
- Create: `lib/game/overlays/round_result_overlay.dart`
- Create: `lib/game/overlays/game_over_overlay.dart`
- Modify: `lib/game/kout_game.dart`
- Modify: `lib/app/screens/game_screen.dart`

These are Flutter widgets overlaid on the Flame game via `GameWidget.overlayBuilderMap`.

- [ ] **Step 1: Implement bid overlay**

Shows bid buttons (5/Bab, 6, 7, 8/Kout) and a Pass button. Only visible during BIDDING phase when it's the player's turn. Calls `onAction('bid', ...)` or `onAction('pass', ...)`.

- [ ] **Step 2: Implement trump selector**

Shows 4 suit buttons (Spades, Hearts, Clubs, Diamonds). Only visible during TRUMP_SELECTION phase when the player is the bid winner. Calls `onAction('trump', ...)`.

- [ ] **Step 3: Implement round result overlay**

Shows "Round Won!" or "Round Lost" with points awarded. Visible during ROUND_SCORING phase. Auto-dismisses after 3 seconds.

- [ ] **Step 4: Implement game over overlay**

Shows final result ("Victory!" / "Defeat"), final scores, and a "Return to Menu" button.

- [ ] **Step 5: Register overlays in GameWidget**

```dart
// In game_screen.dart build method
GameWidget(
  game: _game,
  overlayBuilderMap: {
    'bid': (context, game) => BidOverlay(
      onBid: (amount) => _game.onAction('bid', {'amount': amount}),
      onPass: () => _game.onAction('pass', {}),
    ),
    'trump': (context, game) => TrumpSelector(
      onSelect: (suit) => _game.onAction('trump', {'suit': suit}),
    ),
    'roundResult': (context, game) => RoundResultOverlay(state: _game._currentState!),
    'gameOver': (context, game) => GameOverOverlay(
      state: _game._currentState!,
      onReturnToMenu: () => Navigator.pushReplacementNamed(context, '/'),
    ),
  },
)
```

- [ ] **Step 6: Update KoutGame._onStateUpdate to show/hide overlays**

```dart
void _onStateUpdate(ClientGameState state) {
  // Show/hide overlays based on phase
  if (state.phase == GamePhase.bidding && state.isMyTurn) {
    overlays.add('bid');
  } else {
    overlays.remove('bid');
  }

  if (state.phase == GamePhase.trumpSelection && state.bidderUid == state.myUid) {
    overlays.add('trump');
  } else {
    overlays.remove('trump');
  }

  // ... etc for roundResult and gameOver
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/game/overlays/ lib/game/kout_game.dart lib/app/screens/game_screen.dart
git commit -m "feat: add bid, trump, round result, and game over overlays"
```

---

### Task 7: Animation Manager

**Files:**
- Create: `lib/game/managers/animation_manager.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Implement animation manager**

Sequences card animations:
- **Deal:** Cards fly from center to each player's area with staggered 100ms delay.
- **Play card:** Card arcs from hand position to trick area position with `MoveEffect` (300ms) + slight `ScaleEffect`.
- **Trick collection:** All 4 trick cards slide to the winning team's score area (400ms).
- **Poison Joker:** Joker card flashes red, shakes, then the round result overlay appears.

Uses Flame's `EffectController` with `CurvedEffectController` for easing.

- [ ] **Step 2: Wire animations into KoutGame._onStateUpdate**

Detect state diffs (new card in trick, trick completed, new round) and trigger appropriate animations before updating component positions.

- [ ] **Step 3: Commit**

```bash
git add lib/game/managers/animation_manager.dart lib/game/kout_game.dart
git commit -m "feat: add animation manager for card dealing, playing, and trick collection"
```

---

### Task 8: Integration — Full Game Loop Verification

**Files:**
- Create: `test/game/kout_game_test.dart`

- [ ] **Step 1: Write KoutGame integration test**

Using `FlameTester`, feed a sequence of `ClientGameState` snapshots through the stream and verify: components update, overlays show/hide, card count changes, scores update.

- [ ] **Step 2: Run all game tests**

Run: `flutter test test/game/`
Expected: All PASS

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add test/game/
git commit -m "test: add KoutGame integration test verifying full game loop rendering"
```

---

## Summary

8 tasks. Produces:
- Complete Flame rendering layer with card, hand, seats, trick area, score display
- Flutter overlays for bidding, trump selection, round results, game over
- Animation system for card dealing, playing, and collection
- Layout manager for portrait mobile screens
- Diwaniya color theme
- All driven reactively by ClientGameState stream
