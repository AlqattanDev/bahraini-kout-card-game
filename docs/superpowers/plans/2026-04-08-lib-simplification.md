# lib/ Code Simplification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all code duplication, remove dead code, fix state bugs, and consolidate scattered patterns across `lib/` — zero functional changes.

**Architecture:** Bottom-up refactoring: `shared/` first (foundational types used everywhere), then `offline/`, then `game/`, then `app/`. Each task is self-contained and produces passing tests.

**Tech Stack:** Dart/Flutter, Flame engine, flutter_test

---

## File Structure

Changes organized by directory:

**Modify:**
- `lib/shared/models/enums.dart` — add encoding methods to Suit and Rank enums
- `lib/shared/constants.dart` — remove encoding maps (moved to enums)
- `lib/shared/models/card.dart` — use enum methods instead of map lookups; remove `fullDeck()` duplication
- `lib/shared/models/deck.dart` — delegate to `GameCard.fullDeck()` instead of duplicating deck construction
- `lib/shared/logic/card_utils.dart` — add `lowestByRank()` utility
- `lib/offline/bot/play_strategy.dart` — use `lowestByRank()`, extract suit-strength helper
- `lib/offline/bot/hand_evaluator.dart` — use shared suit-strength accumulator
- `lib/offline/bot/trump_strategy.dart` — use shared suit-strength accumulator
- `lib/offline/bot/card_tracker.dart` — remove dead `playedCards` getter
- `lib/offline/local_game_controller.dart` — fix `_bidWasForced` lifecycle, remove dual trick tracking
- `lib/game/managers/overlay_controller.dart` — extract sound-event logic to SoundManager
- `lib/game/managers/sound_manager.dart` — absorb state-based sound triggering
- `lib/app/widgets/app_snackbar.dart` — consolidate into single parameterized method

**Test updates:**
- `test/shared/models/card_test.dart` — update encoding tests to reference enum methods
- `test/shared/models/deck_test.dart` — no changes needed (API unchanged)
- `test/offline/bot/card_tracker_test.dart` — remove tests for deleted getter
- `test/offline/bot/play_strategy_test.dart` — no changes (API unchanged)

---

### Task 1: Move encoding maps into Suit and Rank enums

The 4 encoding maps in `constants.dart` (`suitInitial`, `initialToSuit`, `rankString`, `stringToRank`) duplicate data already partially present in enum properties (`Rank.label`). Move all encoding into the enums as the single source of truth.

**Files:**
- Modify: `lib/shared/models/enums.dart`
- Modify: `lib/shared/constants.dart`
- Modify: `lib/shared/models/card.dart`
- Test: `test/shared/models/card_test.dart`

- [ ] **Step 1: Add encoding methods to Suit enum**

In `lib/shared/models/enums.dart`, add `initial` getter and `fromInitial` factory to `Suit`:

```dart
enum Suit {
  spades,
  hearts,
  clubs,
  diamonds;

  String get symbol => switch (this) {
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.clubs => '♣',
        Suit.diamonds => '♦',
      };

  /// Wire-format initial: S, H, C, D.
  String get initial => switch (this) {
        Suit.spades => 'S',
        Suit.hearts => 'H',
        Suit.clubs => 'C',
        Suit.diamonds => 'D',
      };

  /// Decode wire-format initial back to Suit.
  static Suit? fromInitial(String s) => switch (s) {
        'S' => Suit.spades,
        'H' => Suit.hearts,
        'C' => Suit.clubs,
        'D' => Suit.diamonds,
        _ => null,
      };

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}
```

- [ ] **Step 2: Add `fromLabel` factory to Rank enum**

`Rank.label` already exists and matches `rankString`. Add the inverse lookup:

```dart
enum Rank {
  ace(14),
  king(13),
  queen(12),
  jack(11),
  ten(10),
  nine(9),
  eight(8),
  seven(7);

  const Rank(this.value);
  final int value;

  String get label => switch (this) {
        Rank.ace => 'A',
        Rank.king => 'K',
        Rank.queen => 'Q',
        Rank.jack => 'J',
        Rank.ten => '10',
        Rank.nine => '9',
        Rank.eight => '8',
        Rank.seven => '7',
      };

  /// Decode wire-format label back to Rank.
  static Rank? fromLabel(String s) => switch (s) {
        'A' => Rank.ace,
        'K' => Rank.king,
        'Q' => Rank.queen,
        'J' => Rank.jack,
        '10' => Rank.ten,
        '9' => Rank.nine,
        '8' => Rank.eight,
        '7' => Rank.seven,
        _ => null,
      };
}
```

- [ ] **Step 3: Update GameCard.encode() and GameCard.decode() to use enum methods**

In `lib/shared/models/card.dart`, replace map lookups with enum methods:

```dart
// Before (line 22):
return '${suitInitial[suit!]}${rankString[rank!]}';

// After:
return '${suit!.initial}${rank!.label}';
```

```dart
// Before (lines 29-30):
final suit = initialToSuit[suitChar];
final rank = stringToRank[rankStr];

// After:
final suit = Suit.fromInitial(suitChar);
final rank = Rank.fromLabel(rankStr);
```

Then remove the `import 'package:koutbh/shared/constants.dart';` from card.dart (no longer needed).

- [ ] **Step 4: Remove encoding maps from constants.dart**

Delete `suitInitial`, `initialToSuit`, `rankString`, and `stringToRank` maps from `lib/shared/constants.dart`. The file should only retain game-rule constants:

```dart
import 'package:koutbh/shared/models/enums.dart';

const int targetScore = 31;
const int tricksPerRound = 8;
const int playerCount = 4;
const int poisonJokerPenalty = 10;
```

Wait — check if `constants.dart` still needs the enums import. It doesn't if the maps are gone. Remove the import too.

Final `constants.dart`:
```dart
/// Score a team must reach to win the game.
const int targetScore = 31;

/// Total tricks played per round (32 cards / 4 players).
const int tricksPerRound = 8;

/// Number of players in a standard game.
const int playerCount = 4;

/// Penalty points awarded when Poison Joker rule triggers.
const int poisonJokerPenalty = 10;
```

- [ ] **Step 5: Update tests for encoding**

In `test/shared/models/card_test.dart`, the `constants` group (lines 199-253) tests the old maps directly. Replace with tests for the new enum methods:

```dart
group('Suit encoding', () {
  test('initial returns wire-format character', () {
    expect(Suit.spades.initial, 'S');
    expect(Suit.hearts.initial, 'H');
    expect(Suit.clubs.initial, 'C');
    expect(Suit.diamonds.initial, 'D');
  });

  test('fromInitial round-trips with initial', () {
    for (final suit in Suit.values) {
      expect(Suit.fromInitial(suit.initial), suit);
    }
  });

  test('fromInitial returns null for unknown', () {
    expect(Suit.fromInitial('X'), isNull);
  });
});

group('Rank encoding', () {
  test('label returns wire-format string', () {
    expect(Rank.ace.label, 'A');
    expect(Rank.king.label, 'K');
    expect(Rank.queen.label, 'Q');
    expect(Rank.jack.label, 'J');
    expect(Rank.ten.label, '10');
    expect(Rank.nine.label, '9');
    expect(Rank.eight.label, '8');
    expect(Rank.seven.label, '7');
  });

  test('fromLabel round-trips with label', () {
    for (final rank in Rank.values) {
      expect(Rank.fromLabel(rank.label), rank);
    }
  });

  test('fromLabel returns null for unknown', () {
    expect(Rank.fromLabel('Z'), isNull);
  });
});
```

All existing encode/decode roundtrip tests remain untouched and must still pass.

- [ ] **Step 6: Run tests**

Run: `flutter test`
Expected: All 350 tests pass. Zero failures.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/models/enums.dart lib/shared/constants.dart lib/shared/models/card.dart test/shared/models/card_test.dart
git commit -m "refactor(shared): move encoding maps into Suit/Rank enums — single source of truth"
```

---

### Task 2: Deduplicate deck construction

`Deck.fourPlayer()` (deck.dart:7-22) duplicates the exact same 32-card deck construction logic as `GameCard.fullDeck()` (card.dart:52-68). Make `Deck.fourPlayer()` delegate to `GameCard.fullDeck()`.

**Files:**
- Modify: `lib/shared/models/deck.dart`

- [ ] **Step 1: Rewrite Deck.fourPlayer() to delegate**

```dart
import 'card.dart';

class Deck {
  final List<GameCard> cards;
  Deck._(this.cards);

  factory Deck.fourPlayer() => Deck._(GameCard.fullDeck().toList());

  List<List<GameCard>> deal(int playerCount) {
    final shuffled = List<GameCard>.from(cards)..shuffle();
    final cardsPerPlayer = shuffled.length ~/ playerCount;
    return List.generate(
      playerCount,
      (i) => shuffled.sublist(i * cardsPerPlayer, (i + 1) * cardsPerPlayer),
    );
  }
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/shared/models/deck_test.dart`
Expected: All deck tests pass. The API is unchanged — `Deck.fourPlayer()` still produces a 32-card deck, `deal()` still shuffles and distributes.

- [ ] **Step 3: Commit**

```bash
git add lib/shared/models/deck.dart
git commit -m "refactor(shared): deduplicate deck construction — Deck delegates to GameCard.fullDeck()"
```

---

### Task 3: Add `lowestByRank()` utility and use it in PlayStrategy

`PlayStrategy` has 6+ occurrences of the pattern: `list.sort((a, b) => a.rank!.value.compareTo(b.rank!.value)); return list.first;` — plus a dedicated `_lowest()` method. Extract a shared utility.

**Files:**
- Modify: `lib/shared/logic/card_utils.dart`
- Modify: `lib/offline/bot/play_strategy.dart`

- [ ] **Step 1: Add `lowestByRank()` to card_utils.dart**

```dart
import 'package:koutbh/shared/models/card.dart';

Map<Suit, int> countBySuit(List<GameCard> hand) {
  final counts = <Suit, int>{};
  for (final card in hand) {
    if (card.isJoker) continue;
    counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
  }
  return counts;
}

/// Returns the non-Joker card with the lowest rank value.
/// Falls back to the first card if all are Jokers.
GameCard lowestByRank(List<GameCard> cards) {
  final nonJoker = cards.where((c) => !c.isJoker).toList();
  if (nonJoker.isEmpty) return cards.first;
  nonJoker.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
  return nonJoker.first;
}
```

- [ ] **Step 2: Replace `_lowest()` and inline sorts in PlayStrategy**

In `lib/offline/bot/play_strategy.dart`:

Add import:
```dart
import 'package:koutbh/shared/logic/card_utils.dart';
```

(This import already exists — just verify.)

Remove the `_lowest()` method (lines 378-383) entirely.

Replace all calls to `_lowest(...)` with `lowestByRank(...)`:
- Line 216: `return lowestByRank(winningTrumps);`
- Line 226: `return lowestByRank(legalCards);`
- Line 234: `return lowestByRank(legalCards);`
- Line 237: `return lowestByRank(winners.isNotEmpty ? winners : legalCards);`
- Line 241: `return lowestByRank(winners);`
- Line 242: `return lowestByRank(legalCards);`
- Line 323: `return lowestByRank(winningTrumps);`
- Line 324: `return lowestByRank(trumpCards);`

Replace inline sorts in `_strategicDump()` and `_selectLead()` where the pattern is `sort ascending + return first`:
- Line 344 (`singletons.sort...return singletons.first`): `return lowestByRank(singletons);`
- Line 363 (`safeToBreak.sort...return safeToBreak.first`): `return lowestByRank(safeToBreak);`
- Line 371 (`nonTrump.sort...return nonTrump.first`): `return lowestByRank(nonTrump);`
- Line 374 (`dumpable.sort...return dumpable.first`): `return lowestByRank(dumpable);`

Note: Do NOT replace `sort descending` patterns (like `b.rank!.value.compareTo(a.rank!.value)`) — those find the highest, not the lowest.

- [ ] **Step 3: Run tests**

Run: `flutter test test/offline/bot/play_strategy_test.dart`
Expected: All play strategy tests pass. Behavior is identical.

Run: `flutter test`
Expected: All 350 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/shared/logic/card_utils.dart lib/offline/bot/play_strategy.dart
git commit -m "refactor(bot): extract lowestByRank() utility — eliminates 6 duplicate sort patterns"
```

---

### Task 4: Extract shared suit-strength accumulator

Both `HandEvaluator.evaluate()` (hand_evaluator.dart:14-57) and `TrumpStrategy.selectTrump()` (trump_strategy.dart:29-38) independently loop over cards, skip Jokers, and accumulate suit-based strength scores with different weight functions. Extract this pattern.

**Files:**
- Modify: `lib/shared/logic/card_utils.dart`
- Modify: `lib/offline/bot/hand_evaluator.dart`
- Modify: `lib/offline/bot/trump_strategy.dart`

- [ ] **Step 1: Add `accumulateBySuit()` to card_utils.dart**

```dart
/// Accumulates a per-suit score by applying [weight] to each non-Joker card's rank.
Map<Suit, double> accumulateBySuit(
  List<GameCard> hand,
  double Function(Rank rank) weight,
) {
  final result = <Suit, double>{};
  for (final card in hand) {
    if (card.isJoker) continue;
    result[card.suit!] = (result[card.suit!] ?? 0) + weight(card.rank!);
  }
  return result;
}
```

- [ ] **Step 2: Use it in TrumpStrategy**

In `lib/offline/bot/trump_strategy.dart`, replace lines 30-38:

```dart
// Before:
final suitStrength = <Suit, double>{};
for (final card in hand) {
  if (card.isJoker) continue;
  final suit = card.suit!;
  suitStrength[suit] =
      (suitStrength[suit] ?? 0) + _trumpSuitStrengthWeight(card.rank!);
}

// After:
final suitStrength = accumulateBySuit(hand, _trumpSuitStrengthWeight);
```

- [ ] **Step 3: Use it in HandEvaluator**

In `lib/offline/bot/hand_evaluator.dart`, the suit strength accumulation is interleaved with other logic (Joker scoring, trump bonuses). The cleanest approach: use `accumulateBySuit` for the base honor valuation, then do the trump bonus pass separately.

Replace the card loop (lines 16-57) with:

```dart
static HandStrength evaluate(List<GameCard> hand, {Suit? trumpSuit}) {
  double score = 0.0;
  final suitCounts = countBySuit(hand);

  // Base honor valuation per suit
  double honorWeight(Rank rank) => switch (rank) {
        Rank.ace => 0.9,
        Rank.king => 0.6, // base; adjusted below for long suits
        Rank.queen => 0.3,
        Rank.jack => 0.2,
        Rank.ten => 0.1,
        _ => 0.0,
      };
  final suitStrength = accumulateBySuit(hand, honorWeight);

  // Joker: guaranteed winner
  if (hand.any((c) => c.isJoker)) score += 1.0;

  // Per-card adjustments that depend on suit length and trump
  for (final card in hand) {
    if (card.isJoker) continue;
    final suit = card.suit!;
    final rank = card.rank!;
    final count = suitCounts[suit] ?? 0;

    // King/Queen bonus for long suits
    if (rank == Rank.king && count >= 3) score += 0.2;
    if (rank == Rank.queen && count >= 3) score += 0.2;

    // Trump honor bonus
    if (trumpSuit != null && suit == trumpSuit) {
      score += switch (rank) {
        Rank.ace => 0.5,
        Rank.king => 0.4,
        Rank.queen => 0.3,
        Rank.jack => 0.2,
        _ => 0.3,
      };
    }
  }

  // Add base honor scores
  for (final v in suitStrength.values) {
    score += v;
  }

  // Suit texture scoring
  score += _suitTextureBonus(hand);

  // Long suit bonus
  for (final entry in suitCounts.entries) {
    if (entry.value >= 4) score += 0.3;
  }

  // Void and ruffing potential
  final hasAnyTrump = hand.any(
    (c) => !c.isJoker && trumpSuit != null && c.suit == trumpSuit,
  );
  for (final suit in Suit.values) {
    if (!suitCounts.containsKey(suit)) {
      if (suit == trumpSuit) {
        // Void in trump: bad. No bonus.
      } else if (hasAnyTrump) {
        score += 0.3;
      } else {
        score += 0.1;
      }
    }
  }

  // Find strongest suit
  Suit? strongest;
  double bestStrength = -1;
  for (final entry in suitStrength.entries) {
    final combined = entry.value + (suitCounts[entry.key] ?? 0) * 0.1;
    if (combined > bestStrength) {
      bestStrength = combined;
      strongest = entry.key;
    }
  }

  return HandStrength(
    expectedWinners: score.clamp(0.0, 8.0),
    strongestSuit: strongest,
  );
}
```

**IMPORTANT:** The refactored code must produce the SAME `expectedWinners` scores as before. The original loop accumulates per-card scores into both `score` and `suitStrength`. The new version separates base honor valuation (via `accumulateBySuit`) from contextual adjustments (trump bonus, long-suit king/queen bonus).

Verify: in the original, a King in a 3-card suit scores `0.8` (line 31). In the new version, `honorWeight(King) = 0.6` + long-suit bonus `0.2` = `0.8`. Same result.

Verify: a Queen in a 3-card suit scores `0.5` (line 33). New: `honorWeight(Queen) = 0.3` + long-suit bonus `0.2` = `0.5`. Same result.

- [ ] **Step 4: Run tests**

Run: `flutter test test/offline/bot/hand_evaluator_test.dart test/offline/bot/trump_strategy_test.dart`
Expected: All tests pass with identical scores.

Run: `flutter test`
Expected: All 350 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/logic/card_utils.dart lib/offline/bot/hand_evaluator.dart lib/offline/bot/trump_strategy.dart
git commit -m "refactor(bot): extract accumulateBySuit() — deduplicates suit-strength calculation"
```

---

### Task 5: Remove dead code from CardTracker

`CardTracker.playedCards` getter (card_tracker.dart:15) is never referenced anywhere in the codebase. Remove it.

**Files:**
- Modify: `lib/offline/bot/card_tracker.dart`
- Modify: `test/offline/bot/card_tracker_test.dart` (if it tests `playedCards`)

- [ ] **Step 1: Check if tests reference playedCards**

Search `test/offline/bot/card_tracker_test.dart` for `playedCards`. If present, remove those test cases.

- [ ] **Step 2: Remove the getter**

In `lib/offline/bot/card_tracker.dart`, delete line 15:
```dart
Set<GameCard> get playedCards => Set.unmodifiable(_played);
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/offline/bot/card_tracker_test.dart`
Expected: All remaining tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/offline/bot/card_tracker.dart test/offline/bot/card_tracker_test.dart
git commit -m "refactor(bot): remove dead CardTracker.playedCards getter"
```

---

### Task 6: Fix `_bidWasForced` lifecycle bug

`LocalGameController._bidWasForced` (line 30) persists across rounds. If round 1 has a forced bid and round 2 doesn't, the play phase in round 2 still sees `_bidWasForced == true` from round 1. Reset it at the start of each round's bidding phase.

**Files:**
- Modify: `lib/offline/local_game_controller.dart`

- [ ] **Step 1: Reset the flag in `_deal()`**

In `lib/offline/local_game_controller.dart`, add `_bidWasForced = false;` in the `_deal()` method alongside the other round-state resets (around line 112-120):

```dart
// After line 119 (_state.bidHistory = []):
_bidWasForced = false;
```

This is the simplest fix — `_deal()` already resets all per-round state.

- [ ] **Step 2: Run tests**

Run: `flutter test test/offline/local_game_controller_test.dart test/offline/stream_integration_test.dart`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/offline/local_game_controller.dart
git commit -m "fix(offline): reset _bidWasForced per round — prevents stale forced-bid state"
```

---

### Task 7: Eliminate dual trick-play tracking in LocalGameController

`_playSingleTrick()` maintains two representations of the same data:
1. `_state.currentTrickPlays` — list of `({int seat, GameCard card})` records in mutable state
2. `trickPlays` — local `List<TrickPlay>` passed around and returned

Both track the exact same plays. The local list is only used in `_resolveTrick()` to build a `Trick` object. Eliminate the local list and build `Trick` directly from `_state.currentTrickPlays`.

**Files:**
- Modify: `lib/offline/local_game_controller.dart`

- [ ] **Step 1: Modify `_playSingleTrick` to not pass a local list**

Replace `_playSingleTrick`:

```dart
Future<List<TrickPlay>?> _playSingleTrick(
  int trickNumber,
  int leaderSeat,
  CardTracker tracker,
) async {
  _state.currentTrickPlays = [];
  _state.currentSeat = leaderSeat;
  _emitState();

  for (int play = 0; play < 4 && !_disposed; play++) {
    final result = await _playSingleCard(
      seat: _state.currentSeat,
      isLead: play == 0,
      isLastPlay: play == 3,
      tracker: tracker,
    );
    if (_disposed) return null;
    if (result == _PlayResult.poisonJoker) return null;

    if (play < 3) {
      _state.currentSeat = nextSeat(_state.currentSeat);
    }
  }

  // Build TrickPlay list from the single source of truth
  return _state.currentTrickPlays
      .map((p) => TrickPlay(playerIndex: p.seat, card: p.card))
      .toList();
}
```

- [ ] **Step 2: Remove the `trickPlays` parameter from `_playSingleCard`**

In `_playSingleCard`, remove the `required List<TrickPlay> trickPlays` parameter and the line `trickPlays.add(TrickPlay(playerIndex: seat, card: action.card));` (line 385).

The method signature becomes:
```dart
Future<_PlayResult> _playSingleCard({
  required int seat,
  required bool isLead,
  required bool isLastPlay,
  required CardTracker tracker,
}) async {
```

And remove line 385:
```dart
// DELETE: trickPlays.add(TrickPlay(playerIndex: seat, card: action.card));
```

Everything else stays the same — `_state.currentTrickPlays` (line 381-384) remains the single source of truth.

- [ ] **Step 3: Run tests**

Run: `flutter test test/offline/local_game_controller_test.dart test/offline/stream_integration_test.dart test/shared/integration/round_simulation_test.dart`
Expected: All tests pass.

Run: `flutter test`
Expected: All 350 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/offline/local_game_controller.dart
git commit -m "refactor(offline): single source of truth for trick plays — remove dual tracking"
```

---

### Task 8: Move sound-event tracking from OverlayController to SoundManager

`OverlayController` has 3 responsibilities: overlay visibility, sound triggering, and score snapshots. The `trackTrickSounds()` method (lines 46-65) and sound calls in `update()` belong in `SoundManager`, which already owns all sound playback.

**Files:**
- Modify: `lib/game/managers/sound_manager.dart`
- Modify: `lib/game/managers/overlay_controller.dart`
- Modify: `lib/game/kout_game.dart` (update call sites)

- [ ] **Step 1: Read current SoundManager and KoutGame**

Read `lib/game/managers/sound_manager.dart` and `lib/game/kout_game.dart` to understand current call patterns.

- [ ] **Step 2: Move `trackTrickSounds` into SoundManager**

Add to `SoundManager`:

```dart
int _prevTrickPlayCount = 0;

/// Detects card plays, trick completions, and trick clears from state changes.
void trackTrickSounds(int currentTrickPlayCount) {
  if (muted) {
    _prevTrickPlayCount = currentTrickPlayCount;
    return;
  }

  if (currentTrickPlayCount > _prevTrickPlayCount && currentTrickPlayCount > 0) {
    playCardSound();
  }
  if (currentTrickPlayCount == 4 && _prevTrickPlayCount < 4) {
    playTrickWinSound();
  }
  if (currentTrickPlayCount == 0 && _prevTrickPlayCount > 0) {
    playTrickCollectSound();
  }

  _prevTrickPlayCount = currentTrickPlayCount;
}
```

- [ ] **Step 3: Move phase-transition sounds into SoundManager**

Add to `SoundManager`:

```dart
/// Plays sounds for overlay transitions. Called by OverlayController when
/// showing an overlay.
void playOverlaySound(String overlayKey, {bool? myTeamWon}) {
  if (muted) return;
  switch (overlayKey) {
    case 'bid':
      playBidSound();
    case 'trump':
      playTrumpSound();
    case 'roundResult':
      if (myTeamWon == true) {
        playRoundWinSound();
      } else {
        playRoundLossSound();
      }
    case 'gameOver':
      if (myTeamWon == true) {
        playVictorySound();
      } else {
        playDefeatSound();
      }
  }
}
```

- [ ] **Step 4: Simplify OverlayController**

Remove `trackTrickSounds()` method and `_prevTrickPlayCount` field from `OverlayController`.

Simplify `update()` to delegate sound calls to `SoundManager.playOverlaySound()` instead of making individual sound calls inline. The `SoundManager?` parameter stays but is only used for `playOverlaySound()` and `playPoisonJokerSound()`.

```dart
void update(
  ClientGameState state, {
  required OverlayDelegate delegate,
  SoundManager? soundManager,
}) {
  // Detect poison joker sound
  if (state.phase == GamePhase.roundScoring &&
      _prevPhase == GamePhase.playing &&
      state.myHand.length == 1 &&
      state.myHand.first.isJoker) {
    soundManager?.playPoisonJokerSound();
  }
  _prevPhase = state.phase;

  String? targetOverlay;
  switch (state.phase) {
    case GamePhase.bidding:
      if (state.isMyTurn) targetOverlay = 'bid';
    case GamePhase.trumpSelection:
      if (state.bidderUid == state.myUid) targetOverlay = 'trump';
    case GamePhase.bidAnnouncement:
      targetOverlay = 'bidAnnouncement';
    case GamePhase.roundScoring:
      targetOverlay = 'roundResult';
    case GamePhase.gameOver:
      targetOverlay = 'gameOver';
    default:
      break;
  }

  for (final key in _allOverlays) {
    if (key != targetOverlay && delegate.isActive(key)) {
      delegate.remove(key);
    }
  }

  if (targetOverlay != null && !delegate.isActive(targetOverlay)) {
    if (targetOverlay == 'roundResult') {
      previousScoreA = _lastScoreA;
      previousScoreB = _lastScoreB;

      final bt = state.bidderTeam;
      final bidValue = state.currentBid?.value ?? 0;
      final bidderTricks = bt != null ? (state.tricks[bt] ?? 0) : 0;
      final bidderWon = bidderTricks >= bidValue;
      final myTeamWon = (bt == state.myTeam) ? bidderWon : !bidderWon;

      soundManager?.playOverlaySound('roundResult', myTeamWon: myTeamWon);
    } else if (targetOverlay == 'gameOver') {
      if (!delegate.isActive('gameOver')) {
        final myScore = state.scores[state.myTeam] ?? 0;
        final oppScore = state.scores[state.myTeam.opponent] ?? 0;
        soundManager?.playOverlaySound('gameOver', myTeamWon: myScore > oppScore);
      }
    } else {
      soundManager?.playOverlaySound(targetOverlay);
    }
    delegate.add(targetOverlay);
  }
}
```

- [ ] **Step 5: Update KoutGame call sites**

In `lib/game/kout_game.dart`, find where `overlayController.trackTrickSounds(state, soundManager)` is called and replace with:
```dart
soundManager.trackTrickSounds(state.currentTrickPlays.length);
```

- [ ] **Step 6: Run tests**

Run: `flutter test`
Expected: All 350 tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/game/managers/sound_manager.dart lib/game/managers/overlay_controller.dart lib/game/kout_game.dart
git commit -m "refactor(game): move sound-event tracking to SoundManager — OverlayController focused on visibility"
```

---

### Task 9: Consolidate snackbar methods

`AppSnackbarX` extension has two nearly identical methods (`showInfoSnack`, `showErrorSnack`) that differ only in background color and default duration. Merge into one parameterized method and keep the two convenience names as thin wrappers.

**Files:**
- Modify: `lib/app/widgets/app_snackbar.dart`

- [ ] **Step 1: Consolidate**

```dart
import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';

extension AppSnackbarX on BuildContext {
  void showSnack(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  void showInfoSnack(String message, {Duration? duration}) =>
      showSnack(message, duration: duration ?? const Duration(seconds: 2));

  void showErrorSnack(String message, {Duration? duration}) =>
      showSnack(message,
          backgroundColor: KoutTheme.lossColor,
          duration: duration ?? const Duration(seconds: 3));
}
```

This preserves the existing API (`showInfoSnack`, `showErrorSnack`) so no callers need to change, while eliminating the duplicated `ScaffoldMessenger` code.

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All 350 tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/app/widgets/app_snackbar.dart
git commit -m "refactor(app): consolidate snackbar methods — single implementation with convenience wrappers"
```

---

### Task 10: Final verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All 350 tests pass.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Verify no regressions with integration test**

Run: `flutter test test/offline/stream_integration_test.dart test/shared/integration/round_simulation_test.dart`
Expected: Full game simulations complete successfully.

---

## Summary of Changes

| Task | What | Impact |
|------|------|--------|
| 1 | Move encoding maps to enums | Eliminates 4 redundant const maps (35 lines) |
| 2 | Dedup deck construction | Eliminates 15 lines of duplicated logic |
| 3 | Extract `lowestByRank()` | Eliminates 6+ duplicate sort patterns |
| 4 | Extract `accumulateBySuit()` | Deduplicates suit-strength calculation |
| 5 | Remove dead `playedCards` | Removes unused code |
| 6 | Fix `_bidWasForced` lifecycle | Fixes cross-round state leak bug |
| 7 | Single trick-play tracking | Removes redundant data structure |
| 8 | Sound events to SoundManager | OverlayController down to single responsibility |
| 9 | Consolidate snackbars | Removes duplicated snackbar code |
| 10 | Final verification | Confirms zero regressions |
