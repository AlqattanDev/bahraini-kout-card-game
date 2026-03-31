# Bidding System Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current bidding system (malzoom/reshuffle) with correct Bahraini Kout rules: randomized first dealer, forced last-player bid, no reshuffle, and visible bid history on all seats.

**Architecture:** The bidding validator is rewritten to enforce "last player can't pass" instead of malzoom. The game controller randomizes the initial dealer (subsequent rounds rotate normally). `ClientGameState` gains `passedPlayers` and `bidHistory` fields so the UI can show what each player chose. The `BidOverlay` filters available bid buttons based on the current high bid and hides Pass when the player is forced.

**Tech Stack:** Dart/Flutter, Flame engine, Vitest (Workers tests)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Rewrite | `lib/shared/logic/bid_validator.dart` | Remove malzoom, add `isLastBidder`, reject pass from last player |
| Modify | `lib/shared/models/game_state.dart` | No changes needed (nextSeat already correct) |
| Modify | `lib/offline/full_game_state.dart` | Remove `reshuffleCount`/`consecutivePasses`, add `bidHistory` |
| Modify | `lib/offline/player_controller.dart` | Add `isForced`, `passedPlayers` to `BidContext` |
| Rewrite | `lib/offline/local_game_controller.dart` | Randomize first dealer, rewrite `_bidding()`, remove malzoom |
| Modify | `lib/offline/bot/bid_strategy.dart` | Handle forced bid (never return PassAction when forced) |
| Modify | `lib/app/models/client_game_state.dart` | Add `passedPlayers`, `bidHistory` fields |
| Rewrite | `lib/game/overlays/bid_overlay.dart` | Filter buttons by currentHighBid, hide Pass when forced |
| Modify | `lib/game/kout_game.dart` | Pass new fields to overlay, update seats with bid actions |
| Modify | `lib/game/components/player_seat.dart` | Add bid action label rendering ("Pass", "Bid 5", etc.) |
| Modify | `lib/app/screens/game_screen.dart` | Pass currentHighBid + isForced to BidOverlay |
| Rewrite | `test/shared/logic/bid_validator_test.dart` | Remove malzoom tests, add forced-bid tests |
| Modify | `test/offline/bot/bid_strategy_test.dart` | Add forced-bid test case |
| Modify | `test/offline/local_game_controller_test.dart` | Update bidding expectations |
| Rewrite | `workers/src/game/bid-validator.ts` | Mirror Dart changes (remove malzoom, add forced logic) |
| Modify | `workers/src/game/bid-validator.test.ts` | Mirror Dart test changes |

---

## Task 1: Rewrite BidValidator (Dart) — Remove Malzoom, Add Forced Bid

**Files:**
- Modify: `lib/shared/logic/bid_validator.dart`
- Rewrite: `test/shared/logic/bid_validator_test.dart`

### What changes and why

The current `BidValidator` has `MalzoomOutcome`, `checkMalzoom`, and allows all 4 players to pass. The new rules are:
- If 3 players have passed and **no bid exists yet**, the 4th player **cannot pass** — they must bid at least 5 (Bab).
- If 3 players have passed and **a bid exists**, bidding is complete (the bidder wins).
- Kout (8) instantly ends bidding.
- No reshuffle. No malzoom. Ever.

- [ ] **Step 1: Write failing tests for the new BidValidator**

Replace `test/shared/logic/bid_validator_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/logic/bid_validator.dart';

void main() {
  group('BidValidator', () {
    group('validateBid', () {
      test('accepts first bid of 5', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.bab,
          currentHighest: null,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, true);
      });

      test('accepts bid higher than current', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.seven,
          currentHighest: BidAmount.six,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, true);
      });

      test('rejects bid equal to current', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.six,
          currentHighest: BidAmount.six,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'bid-not-higher');
      });

      test('rejects bid lower than current', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.bab,
          currentHighest: BidAmount.six,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'bid-not-higher');
      });

      test('rejects bid from player who already passed', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.seven,
          currentHighest: BidAmount.six,
          passedPlayers: [1],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });
    });

    group('validatePass', () {
      test('allows pass for non-passed player when not last', () {
        final result = BidValidator.validatePass(
          passedPlayers: [0],
          playerIndex: 1,
          playerCount: 4,
        );
        expect(result.isValid, true);
      });

      test('rejects pass from player who already passed', () {
        final result = BidValidator.validatePass(
          passedPlayers: [1],
          playerIndex: 1,
          playerCount: 4,
        );
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });

      test('rejects pass when player is last remaining and no bid exists', () {
        // 3 others passed, no bid — this player MUST bid
        final result = BidValidator.validatePass(
          passedPlayers: [0, 2, 3],
          playerIndex: 1,
          playerCount: 4,
          currentHighest: null,
        );
        expect(result.isValid, false);
        expect(result.error, 'must-bid');
      });

      test('allows pass when player is last remaining but a bid exists', () {
        // 3 others passed but someone already bid — last player can pass to end bidding
        final result = BidValidator.validatePass(
          passedPlayers: [0, 2, 3],
          playerIndex: 1,
          playerCount: 4,
          currentHighest: BidAmount.six,
        );
        expect(result.isValid, true);
      });
    });

    group('isLastBidder', () {
      test('returns true when 3 others have passed', () {
        expect(
          BidValidator.isLastBidder(
            passedPlayers: [0, 2, 3],
            playerIndex: 1,
            playerCount: 4,
          ),
          true,
        );
      });

      test('returns false when fewer than 3 have passed', () {
        expect(
          BidValidator.isLastBidder(
            passedPlayers: [0, 2],
            playerIndex: 1,
            playerCount: 4,
          ),
          false,
        );
      });

      test('returns false when player is in passedPlayers', () {
        expect(
          BidValidator.isLastBidder(
            passedPlayers: [0, 1, 2],
            playerIndex: 1,
            playerCount: 4,
          ),
          false,
        );
      });
    });

    group('checkBiddingComplete', () {
      test('complete when 3 players passed and a bid exists', () {
        final result = BidValidator.checkBiddingComplete(
          passedPlayers: [0, 2, 3],
          currentHighest: BidAmount.six,
          highestBidderIndex: 1,
        );
        expect(result.isComplete, true);
        expect(result.winnerIndex, 1);
        expect(result.winningBid, BidAmount.six);
      });

      test('not complete with fewer than 3 passes', () {
        final result = BidValidator.checkBiddingComplete(
          passedPlayers: [0, 2],
          currentHighest: BidAmount.six,
          highestBidderIndex: 1,
        );
        expect(result.isComplete, false);
      });

      test('not complete when all 4 passed but no bid (should not happen with forced bid)', () {
        final result = BidValidator.checkBiddingComplete(
          passedPlayers: [0, 1, 2, 3],
          currentHighest: null,
          highestBidderIndex: null,
        );
        expect(result.isComplete, false);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test test/shared/logic/bid_validator_test.dart`
Expected: FAIL — `validatePass` signature changed, `isLastBidder` doesn't exist, malzoom tests gone.

- [ ] **Step 3: Rewrite BidValidator implementation**

Replace `lib/shared/logic/bid_validator.dart` with:

```dart
import '../models/bid.dart';

class BidValidationResult {
  final bool isValid;
  final String? error;
  const BidValidationResult.valid() : isValid = true, error = null;
  const BidValidationResult.invalid(this.error) : isValid = false;
}

class BiddingOutcome {
  final bool isComplete;
  final int? winnerIndex;
  final BidAmount? winningBid;

  const BiddingOutcome._({required this.isComplete, this.winnerIndex, this.winningBid});

  factory BiddingOutcome.won({required int winnerIndex, required BidAmount bid}) =>
      BiddingOutcome._(isComplete: true, winnerIndex: winnerIndex, winningBid: bid);

  factory BiddingOutcome.ongoing() => const BiddingOutcome._(isComplete: false);

  @override
  bool operator ==(Object other) {
    if (other is! BiddingOutcome) return false;
    return isComplete == other.isComplete &&
        winnerIndex == other.winnerIndex &&
        winningBid == other.winningBid;
  }

  @override
  int get hashCode => Object.hash(isComplete, winnerIndex, winningBid);
}

class BidValidator {
  /// Validates a bid action. Bid must be strictly higher than current highest.
  static BidValidationResult validateBid({
    required BidAmount bidAmount,
    required BidAmount? currentHighest,
    required List<int> passedPlayers,
    required int playerIndex,
  }) {
    if (passedPlayers.contains(playerIndex)) {
      return const BidValidationResult.invalid('already-passed');
    }
    if (currentHighest != null && bidAmount.value <= currentHighest.value) {
      return const BidValidationResult.invalid('bid-not-higher');
    }
    return const BidValidationResult.valid();
  }

  /// Validates a pass action.
  /// Rejects if player already passed.
  /// Rejects if player is the last remaining bidder and no bid exists yet
  /// (they are forced to bid at least 5/Bab).
  static BidValidationResult validatePass({
    required List<int> passedPlayers,
    required int playerIndex,
    int playerCount = 4,
    BidAmount? currentHighest,
  }) {
    if (passedPlayers.contains(playerIndex)) {
      return const BidValidationResult.invalid('already-passed');
    }
    // Last player standing with no existing bid — must bid
    if (isLastBidder(
          passedPlayers: passedPlayers,
          playerIndex: playerIndex,
          playerCount: playerCount,
        ) &&
        currentHighest == null) {
      return const BidValidationResult.invalid('must-bid');
    }
    return const BidValidationResult.valid();
  }

  /// Returns true if [playerIndex] is the only player who hasn't passed.
  static bool isLastBidder({
    required List<int> passedPlayers,
    required int playerIndex,
    int playerCount = 4,
  }) {
    if (passedPlayers.contains(playerIndex)) return false;
    final activePlayers = playerCount - passedPlayers.length;
    return activePlayers == 1;
  }

  /// Bidding is complete when 3 players have passed and someone has bid.
  static BiddingOutcome checkBiddingComplete({
    required List<int> passedPlayers,
    required BidAmount? currentHighest,
    required int? highestBidderIndex,
  }) {
    if (passedPlayers.length >= 3 &&
        currentHighest != null &&
        highestBidderIndex != null) {
      return BiddingOutcome.won(
          winnerIndex: highestBidderIndex, bid: currentHighest);
    }
    return BiddingOutcome.ongoing();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test test/shared/logic/bid_validator_test.dart`
Expected: All PASS.

> **Note:** The new `validatePass` signature adds optional params (`playerCount`, `currentHighest`). Existing call sites in `local_game_controller.dart` will compile but won't enforce forced-bid until Task 3 rewrites `_bidding()` to pass `currentHighest`. This is intentional — no intermediate breakage.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/logic/bid_validator.dart test/shared/logic/bid_validator_test.dart
git commit -m "refactor: rewrite BidValidator — remove malzoom, add forced last-player bid"
```

---

## Task 2: Update State Models — FullGameState, BidContext, ClientGameState

**Files:**
- Modify: `lib/offline/full_game_state.dart`
- Modify: `lib/offline/player_controller.dart`
- Modify: `lib/app/models/client_game_state.dart`

### What changes and why

`FullGameState` needs `bidHistory` to track what each player chose (for UI display), and must drop `reshuffleCount`/`consecutivePasses` (malzoom is dead). `BidContext` needs `isForced` and `passedPlayers` so controllers know whether passing is allowed. `ClientGameState` needs `passedPlayers` and `bidHistory` so the Flame UI can render them.

- [ ] **Step 1: Update FullGameState**

In `lib/offline/full_game_state.dart`:
- Remove fields: `consecutivePasses`, `reshuffleCount`
- Add field: `List<({int seat, String action})> bidHistory` (default `const []`)

```dart
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/app/models/seat_config.dart';

class FullGameState {
  GamePhase phase;
  List<SeatConfig> players;
  Map<int, List<GameCard>> hands;
  Map<Team, int> scores;
  Map<Team, int> trickCounts;
  List<({int seat, GameCard card})> currentTrickPlays;
  int dealerSeat;
  int currentSeat;
  BidAmount? bid;
  int? bidderSeat;
  Suit? trumpSuit;
  List<int> passedPlayers;
  List<({int seat, String action})> bidHistory;
  int trickNumber;

  FullGameState({
    required this.phase,
    required this.players,
    required this.hands,
    required this.scores,
    required this.trickCounts,
    this.currentTrickPlays = const [],
    required this.dealerSeat,
    required this.currentSeat,
    this.bid,
    this.bidderSeat,
    this.trumpSuit,
    this.passedPlayers = const [],
    this.bidHistory = const [],
    this.trickNumber = 1,
  });
}
```

- [ ] **Step 2: Update BidContext in player_controller.dart**

In `lib/offline/player_controller.dart`, change `BidContext` to:

```dart
class BidContext extends ActionContext {
  final BidAmount? currentHighBid;
  final bool isForced;
  final List<int> passedPlayers;
  BidContext({
    this.currentHighBid,
    this.isForced = false,
    this.passedPlayers = const [],
  });
}
```

- [ ] **Step 3: Update ClientGameState**

In `lib/app/models/client_game_state.dart`, add two fields to the class:

```dart
final List<int> passedPlayers;
final List<({String playerUid, String action})> bidHistory;
```

Add them to the constructor with defaults:

```dart
this.passedPlayers = const [],
this.bidHistory = const [],
```

Also update `fromMap()` for online mode — parse `passedPlayers` and `bidHistory` from the Workers JSON with fallbacks to empty lists:

```dart
final passedPlayers = List<int>.from(
  gameData['passedPlayers'] ?? gameData['passed_players'] ?? [],
);
final rawBidHistory = gameData['bidHistory'] ?? gameData['bid_history'] as List?;
final bidHistory = rawBidHistory != null
    ? (rawBidHistory as List)
        .cast<Map<String, dynamic>>()
        .map((e) => (
              playerUid: e['player'] as String,
              action: e['action'] as String,
            ))
        .toList()
    : <({String playerUid, String action})>[];
```

Pass these to the constructor. The Workers backend will populate these fields in Task 8.

- [ ] **Step 4: Verify compilation**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter analyze --no-fatal-infos 2>&1 | head -30`
Expected: Compilation errors in `local_game_controller.dart` (references removed fields) — that's expected, we fix it in Task 3.

- [ ] **Step 5: Commit**

```bash
git add lib/offline/full_game_state.dart lib/offline/player_controller.dart lib/app/models/client_game_state.dart
git commit -m "refactor: update state models — add bidHistory, isForced, remove malzoom fields"
```

---

## Task 3: Rewrite LocalGameController Bidding Loop

**Files:**
- Modify: `lib/offline/local_game_controller.dart`

### What changes and why

Three changes:
1. **Randomize initial dealer** — `dealerSeat: Random().nextInt(4)` instead of hardcoded `0`. This only affects the **first round**. Subsequent rounds rotate normally via `nextSeat()` in the existing round loop.
2. **Rewrite `_bidding()`** — Remove malzoom/reshuffle. Cycle through players counter-clockwise. If a player is the last one standing with no bid, force them. Record each action in `bidHistory`. Add a delay between bot actions so the human can see what happened.
3. **Remove `reshuffleCount` references** — The `_deal()` and round loop no longer need it.

- [ ] **Step 1: Add dart:math import and randomize dealer**

At the top of `lib/offline/local_game_controller.dart`, add `import 'dart:math';`.

In `start()`, change:
```dart
dealerSeat: 0,
```
to:
```dart
dealerSeat: Random().nextInt(4),
```

- [ ] **Step 2: Update `_deal()` — remove reshuffleCount/consecutivePasses**

In `_deal()`, remove these two lines:
```dart
_state.consecutivePasses = 0;
_state.passedPlayers = [];
```

Replace with:
```dart
_state.passedPlayers = [];
_state.bidHistory = [];
```

- [ ] **Step 3: Remove reshuffleCount reset from round loop**

In `start()`, remove this line from the while loop:
```dart
_state.reshuffleCount = 0;
```

- [ ] **Step 4: Rewrite `_bidding()` method**

Replace the entire `_bidding()` method with:

```dart
Future<bool> _bidding() async {
  _state.phase = GamePhase.bidding;
  _state.currentSeat = nextSeat(_state.dealerSeat);
  _emitState();

  while (!_disposed) {
    // Skip players who already passed
    if (_state.passedPlayers.contains(_state.currentSeat)) {
      _state.currentSeat = nextSeat(_state.currentSeat);
      continue;
    }

    final isForced = BidValidator.isLastBidder(
      passedPlayers: _state.passedPlayers,
      playerIndex: _state.currentSeat,
    );

    _emitState();

    // Small delay before bot acts so the human can follow the action
    if (controllers[_state.currentSeat] is! HumanPlayerController) {
      if (enableDelays) await Future.delayed(const Duration(milliseconds: 800));
    }

    final clientState = _toClientState(_state, _state.currentSeat);
    final context = BidContext(
      currentHighBid: _state.bid,
      isForced: isForced,
      passedPlayers: List.unmodifiable(_state.passedPlayers),
    );
    final action = await controllers[_state.currentSeat]!
        .decideAction(clientState, context);
    if (_disposed) return false;

    if (action is BidAction) {
      final result = BidValidator.validateBid(
        bidAmount: action.amount,
        currentHighest: _state.bid,
        passedPlayers: _state.passedPlayers,
        playerIndex: _state.currentSeat,
      );
      if (result.isValid) {
        _state.bid = action.amount;
        _state.bidderSeat = _state.currentSeat;
        _state.bidHistory = [
          ..._state.bidHistory,
          (seat: _state.currentSeat, action: '${action.amount.value}'),
        ];
        _emitState();

        // Kout ends bidding immediately
        if (action.amount == BidAmount.kout) {
          return true;
        }
      }
    } else if (action is PassAction) {
      final result = BidValidator.validatePass(
        passedPlayers: _state.passedPlayers,
        playerIndex: _state.currentSeat,
        currentHighest: _state.bid,
      );
      if (result.isValid) {
        _state.passedPlayers = [..._state.passedPlayers, _state.currentSeat];
        _state.bidHistory = [
          ..._state.bidHistory,
          (seat: _state.currentSeat, action: 'pass'),
        ];
        _emitState();
      }
    }

    // Check if bidding complete (3 passed, 1 bidder with a bid)
    final outcome = BidValidator.checkBiddingComplete(
      passedPlayers: _state.passedPlayers,
      currentHighest: _state.bid,
      highestBidderIndex: _state.bidderSeat,
    );
    if (outcome.isComplete) return true;

    _state.currentSeat = nextSeat(_state.currentSeat);
  }
  return false;
}
```

- [ ] **Step 5: Update `_toClientState` to include new fields**

In `_toClientState`, add the new fields to the `ClientGameState` constructor call:

```dart
passedPlayers: List.unmodifiable(full.passedPlayers),
bidHistory: full.bidHistory
    .map((e) => (playerUid: full.players[e.seat].uid, action: e.action))
    .toList(),
```

- [ ] **Step 6: Add HumanPlayerController import**

Add to imports at the top of `local_game_controller.dart`:
```dart
import 'package:bahraini_kout/offline/human_player_controller.dart';
```

- [ ] **Step 7: Verify compilation**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter analyze --no-fatal-infos 2>&1 | head -30`
Expected: Clean (or warnings only in unrelated files).

- [ ] **Step 8: Run existing controller tests**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test test/offline/local_game_controller_test.dart`
Expected: PASS (tests check phases and scores, not malzoom specifics).

- [ ] **Step 9: Commit**

```bash
git add lib/offline/local_game_controller.dart
git commit -m "refactor: rewrite bidding loop — randomize dealer, forced bid, bid history, no malzoom"
```

---

## Task 4: Update Bot BidStrategy for Forced Bid

**Files:**
- Modify: `lib/offline/bot/bid_strategy.dart`
- Modify: `test/offline/bot/bid_strategy_test.dart`

### What changes and why

The bot's `decideBid` currently returns `PassAction()` for weak hands. When `isForced` is true, it must return `BidAction(BidAmount.bab)` instead. The method also needs access to `isForced`.

- [ ] **Step 1: Write failing test for forced bid**

Add to `test/offline/bot/bid_strategy_test.dart`:

```dart
test('forced bid with strong hand bids higher than bab', () {
  final strongHand = [
    GameCard(suit: Suit.spades, rank: Rank.ace),
    GameCard(suit: Suit.spades, rank: Rank.king),
    GameCard(suit: Suit.spades, rank: Rank.queen),
    GameCard(suit: Suit.spades, rank: Rank.jack),
    GameCard(suit: Suit.spades, rank: Rank.ten),
    GameCard(suit: Suit.hearts, rank: Rank.ace),
    GameCard(suit: Suit.hearts, rank: Rank.king),
    GameCard(suit: Suit.hearts, rank: Rank.queen),
  ];
  final action = BidStrategy.decideBid(strongHand, null, isForced: true);
  expect(action, isA<BidAction>());
  expect((action as BidAction).amount.value, greaterThanOrEqualTo(6));
});

test('forced bid returns at least bab even with weak hand', () {
  // All low cards — normally would pass
  final weakHand = [
    GameCard(suit: Suit.hearts, rank: Rank.seven),
    GameCard(suit: Suit.clubs, rank: Rank.eight),
    GameCard(suit: Suit.diamonds, rank: Rank.nine),
    GameCard(suit: Suit.spades, rank: Rank.seven),
    GameCard(suit: Suit.hearts, rank: Rank.eight),
    GameCard(suit: Suit.clubs, rank: Rank.seven),
    GameCard(suit: Suit.diamonds, rank: Rank.eight),
    GameCard(suit: Suit.spades, rank: Rank.nine),
  ];
  final action = BidStrategy.decideBid(weakHand, null, isForced: true);
  expect(action, isA<BidAction>());
  expect((action as BidAction).amount, BidAmount.bab);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test test/offline/bot/bid_strategy_test.dart`
Expected: FAIL — `decideBid` doesn't accept `isForced`.

- [ ] **Step 3: Update BidStrategy**

In `lib/offline/bot/bid_strategy.dart`, change `decideBid` signature and add forced logic:

```dart
static GameAction decideBid(
  List<GameCard> hand,
  BidAmount? currentHighBid, {
  bool isForced = false,
}) {
  final strength = HandEvaluator.evaluate(hand);
  final maxBid = _strengthToBid(strength.expectedWinners);

  // Forced to bid — must return a BidAction, never PassAction
  if (isForced) {
    // Use natural hand strength if possible, floor at bab
    final naturalBid = maxBid ?? BidAmount.bab;
    if (currentHighBid == null) return BidAction(naturalBid);
    // Find smallest bid that's both >= natural strength and > current high
    for (final bid in BidAmount.values) {
      if (bid.value > currentHighBid.value) return BidAction(bid);
    }
    // Shouldn't happen (kout would have ended bidding), but safety fallback
    return BidAction(BidAmount.bab);
  }

  if (maxBid == null) {
    return PassAction();
  }

  if (currentHighBid == null) {
    return BidAction(maxBid);
  }

  // Can we outbid?
  if (maxBid.value > currentHighBid.value) {
    for (final bid in BidAmount.values) {
      if (bid.value > currentHighBid.value && bid.value <= maxBid.value) {
        return BidAction(bid);
      }
    }
  }

  // Can't outbid — forced must bid minimum above current
  if (isForced) {
    for (final bid in BidAmount.values) {
      if (bid.value > currentHighBid.value) return BidAction(bid);
    }
  }

  return PassAction();
}
```

- [ ] **Step 4: Update BotPlayerController to pass isForced**

In `lib/offline/bot_player_controller.dart`, update the `BidContext` match arm:

```dart
BidContext(:final currentHighBid, :final isForced) =>
  BidStrategy.decideBid(state.myHand, currentHighBid, isForced: isForced),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test test/offline/bot/bid_strategy_test.dart`
Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/offline/bot/bid_strategy.dart lib/offline/bot_player_controller.dart test/offline/bot/bid_strategy_test.dart
git commit -m "feat: bot handles forced bid — always bids when last player"
```

---

## Task 5: Rewrite BidOverlay — Filter Buttons, Hide Pass When Forced

**Files:**
- Modify: `lib/game/overlays/bid_overlay.dart`
- Modify: `lib/app/screens/game_screen.dart`
- Modify: `lib/game/kout_game.dart`

### What changes and why

The overlay currently always shows 5/6/7/8/Pass. It needs to:
1. Only show bids **strictly higher** than the current high bid.
2. Hide Pass entirely when the player is forced (last player, no existing bid).
3. Show "You must bid" / "لازم تختار" text when forced.

- [ ] **Step 1: Rewrite BidOverlay to accept currentHighBid and isForced**

Replace `lib/game/overlays/bid_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import '../../shared/models/bid.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';

class BidOverlay extends StatelessWidget {
  final void Function(int amount) onBid;
  final VoidCallback onPass;
  final BidAmount? currentHighBid;
  final bool isForced;

  const BidOverlay({
    super.key,
    required this.onBid,
    required this.onPass,
    this.currentHighBid,
    this.isForced = false,
  });

  List<BidAmount> get _availableBids {
    if (currentHighBid == null) return BidAmount.values.toList();
    return BidAmount.values
        .where((b) => b.value > currentHighBid!.value)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bids = _availableBids;

    return OverlayAnimationWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF5C1A1B).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KoutTheme.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heading
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isForced ? 'You Must Bid' : 'Place Your Bid',
                  style: KoutTheme.headingStyle.copyWith(
                    color: KoutTheme.accent,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isForced ? 'لازم تختار' : 'ضع مزايدتك',
                  style: KoutTheme.arabicHeadingStyle.copyWith(
                    color: KoutTheme.accent,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Bid buttons — only show bids higher than current
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < bids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _bidButton(
                    '${bids[i].value}',
                    _labelForBid(bids[i]),
                    bids[i].value,
                  ),
                ],
              ],
            ),
            // Pass button — hidden when forced
            if (!isForced) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onPass,
                style: TextButton.styleFrom(
                  foregroundColor: KoutTheme.textColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 10),
                  side: const BorderSide(
                      color: KoutTheme.textColor, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      KoutTheme.gameTerms['pass']!.$1,
                      style: KoutTheme.bodyStyle,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      KoutTheme.gameTerms['pass']!.$2,
                      style: KoutTheme.arabicBodyStyle,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String) _labelForBid(BidAmount bid) {
    return switch (bid) {
      BidAmount.bab => KoutTheme.gameTerms['bab']!,
      BidAmount.six => ('6', '٦'),
      BidAmount.seven => ('7', '٧'),
      BidAmount.kout => KoutTheme.gameTerms['kout']!,
    };
  }

  Widget _bidButton(String number, (String, String) label, int amount) {
    return ElevatedButton(
      onPressed: () => onBid(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.accent,
        foregroundColor: const Color(0xFF3B1A1B),
        minimumSize: const Size(68, 68),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ).copyWith(
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? KoutTheme.accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label.$1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label.$2,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update GameScreen overlay builder to pass new props**

In `lib/app/screens/game_screen.dart`, update the `'bid'` overlay builder:

```dart
'bid': (context, game) {
  final koutGame = game as KoutGame;
  final state = koutGame.currentState;
  return BidOverlay(
    currentHighBid: state?.currentBid,
    isForced: koutGame.isHumanForced,
    onBid: (amount) {
      koutGame.soundManager?.playBidSound();
      koutGame.overlays.remove('bid');
      final bidAmount = BidAmount.fromValue(amount);
      if (bidAmount != null) {
        koutGame.inputSink.placeBid(bidAmount);
      }
    },
    onPass: () {
      koutGame.soundManager?.playBidSound();
      koutGame.overlays.remove('bid');
      koutGame.inputSink.pass();
    },
  );
},
```

- [ ] **Step 3: Add `isHumanForced` getter to KoutGame**

In `lib/game/kout_game.dart`, add this getter:

```dart
/// Whether the human player is forced to bid (last player, no existing bid).
bool get isHumanForced {
  final state = currentState;
  if (state == null) return false;
  if (state.phase != GamePhase.bidding) return false;
  if (!state.isMyTurn) return false;
  // Forced = all other 3 players passed AND no bid exists
  final othersPassed = state.passedPlayers.length >= 3;
  final noBidYet = state.currentBid == null;
  return othersPassed && noBidYet;
}
```

- [ ] **Step 4: Verify compilation**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter analyze --no-fatal-infos 2>&1 | head -30`
Expected: Clean.

- [ ] **Step 5: Commit**

```bash
git add lib/game/overlays/bid_overlay.dart lib/app/screens/game_screen.dart lib/game/kout_game.dart
git commit -m "feat: BidOverlay filters by current bid, hides Pass when forced"
```

---

## Task 6: Show Bid Actions on Player Seats During Bidding

**Files:**
- Modify: `lib/game/components/player_seat.dart`
- Modify: `lib/game/kout_game.dart`

### What changes and why

During the bidding phase, each player's choice should be visible next to their seat. We add a `bidAction` string field to `PlayerSeatComponent` that renders a small label below the team dot: "Pass" in red, "5"/"6"/"7"/"8" in gold.

- [ ] **Step 1: Add bidAction field and rendering to PlayerSeatComponent**

In `lib/game/components/player_seat.dart`:

Add field:
```dart
String? bidAction; // null = hasn't acted yet, "pass" = passed, "5"/"6"/"7"/"8" = bid
```

Add to constructor parameters:
```dart
this.bidAction,
```

Add to `updateState`:
```dart
void updateState({
  required String name,
  required int cards,
  required bool active,
  required bool teamA,
  bool dealer = false,
  String? bidAction,
}) {
  // ... existing code ...
  this.bidAction = bidAction;
}
```

Add rendering at the end of `render()`, after the team dot:
```dart
// Bid action label (shown during bidding)
if (bidAction != null) {
  final isPass = bidAction == 'pass';
  final label = isPass ? 'PASS' : 'BID $bidAction';
  final labelColor = isPass
      ? const Color(0xFFCC4444)  // red for pass
      : const Color(0xFFC9A84C); // gold for bid
  _drawText(
    canvas,
    label,
    labelColor,
    Offset(center.dx, center.dy + _radius + 20),
    9,
  );
}
```

- [ ] **Step 2: Wire bidHistory to seat updates in KoutGame**

In `lib/game/kout_game.dart`, update `_updateSeats` to pass `bidAction`:

In the loop inside `_updateSeats`, compute `bidAction` per seat:

```dart
for (int i = 0; i < state.playerUids.length && i < _seats.length; i++) {
  final uid = state.playerUids[i];

  // Find this player's bid action from history
  String? bidAction;
  if (state.phase == GamePhase.bidding || state.phase == GamePhase.trumpSelection) {
    for (final entry in state.bidHistory) {
      if (entry.playerUid == uid) {
        bidAction = entry.action;
      }
    }
  }

  _seats[i].updateState(
    name: _shortUid(uid),
    cards: i == state.mySeatIndex ? state.myHand.length : 8,
    active: state.currentPlayerUid == uid,
    teamA: i.isEven,
    dealer: uid == state.dealerUid,
    bidAction: bidAction,
  );
  _seats[i].position = layout.seatPosition(i, state.mySeatIndex);
}
```

- [ ] **Step 3: Verify compilation and run game test**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter analyze --no-fatal-infos 2>&1 | head -20`
Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test test/game/kout_game_test.dart`
Expected: Clean compilation, tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/player_seat.dart lib/game/kout_game.dart
git commit -m "feat: show bid/pass labels on player seats during bidding phase"
```

---

## Task 7: Mirror Changes in Workers Backend (TypeScript)

**Files:**
- Modify: `workers/src/game/bid-validator.ts`
- Modify: `workers/test/game/bid-validator.test.ts`

### What changes and why

The Workers backend must stay in sync with the Dart shared logic. Remove `checkMalzoom`, add `isLastBidder`, update `validatePass` to reject last-player passes with no bid.

- [ ] **Step 1: Rewrite bid-validator.ts**

Replace `workers/src/game/bid-validator.ts` with:

```typescript
export interface BidValidationResult {
  valid: boolean;
  error?: string;
}

export interface BiddingCompleteResult {
  complete: boolean;
  winner?: string;
  bid?: number;
}

export function validateBid(
  bidAmount: number,
  currentHighest: number | null,
  passedPlayers: string[],
  playerId: string
): BidValidationResult {
  if (passedPlayers.includes(playerId)) {
    return { valid: false, error: 'already-passed' };
  }
  if (currentHighest !== null && bidAmount <= currentHighest) {
    return { valid: false, error: 'bid-not-higher' };
  }
  return { valid: true };
}

export function validatePass(
  passedPlayers: string[],
  playerId: string,
  playerCount: number = 4,
  currentHighest: number | null = null
): BidValidationResult {
  if (passedPlayers.includes(playerId)) {
    return { valid: false, error: 'already-passed' };
  }
  if (isLastBidder(passedPlayers, playerId, playerCount) && currentHighest === null) {
    return { valid: false, error: 'must-bid' };
  }
  return { valid: true };
}

export function isLastBidder(
  passedPlayers: string[],
  playerId: string,
  playerCount: number = 4
): boolean {
  if (passedPlayers.includes(playerId)) return false;
  const activePlayers = playerCount - passedPlayers.length;
  return activePlayers === 1;
}

export function checkBiddingComplete(
  passedPlayers: string[],
  currentHighest: number | null,
  highestBidder: string | null
): BiddingCompleteResult {
  if (passedPlayers.length >= 3 && currentHighest !== null && highestBidder !== null) {
    return { complete: true, winner: highestBidder, bid: currentHighest };
  }
  return { complete: false };
}
```

- [ ] **Step 2: Rewrite bid-validator.test.ts**

Update `workers/test/game/bid-validator.test.ts` to mirror the Dart tests — remove malzoom tests, add `isLastBidder` and forced-pass-rejection tests.

- [ ] **Step 3: Run Workers tests**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game/workers" && npx vitest run test/game/bid-validator.test.ts`
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add workers/src/game/bid-validator.ts workers/test/game/bid-validator.test.ts
git commit -m "refactor: mirror bidding overhaul in Workers backend — remove malzoom, add forced bid"
```

---

## Task 8: Update GameRoom DO Bidding Handler

**Files:**
- Modify: `workers/src/game/game-room.ts` (bidding-related sections only)

### What changes and why

The GameRoom's `handleBid` method currently has malzoom/reshuffle logic. It needs to use the updated `validatePass` (with `currentHighest` param) and remove reshuffle paths. This task is scoped to just the bidding handler — not a full rewrite.

- [ ] **Step 1: Update handleBid in game-room.ts**

In the bidding handler:
- Remove any `checkMalzoom` calls and reshuffle logic
- Update `validatePass` calls to pass `playerCount` and `currentHighest`
- Use `isLastBidder` to detect forced-bid situations
- Add `bidHistory` array to game state

- [ ] **Step 2: Run GameRoom tests**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game/workers" && npx vitest run test/game/game-room.test.ts`
Expected: PASS (may need test updates if they test malzoom paths).

- [ ] **Step 3: Commit**

```bash
git add workers/src/game/game-room.ts
git commit -m "refactor: update GameRoom bidding handler — remove malzoom, use forced bid logic"
```

---

## Task 9: Full Integration Verification

**Files:** None (test-only)

### What changes and why

Run the full test suite and verify the game plays end-to-end correctly with the new bidding rules.

- [ ] **Step 1: Run all Dart tests**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter test`
Expected: All PASS.

- [ ] **Step 2: Run all Workers tests**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game/workers" && npx vitest run`
Expected: All PASS.

- [ ] **Step 3: Run flutter analyze**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter analyze`
Expected: No errors.

- [ ] **Step 4: Manual smoke test (if applicable)**

Run: `cd "/sessions/modest-jolly-darwin/mnt/Bahraini Kout Card Game" && flutter run`
Verify:
- First round dealer is not always seat 0
- Bidding cycles through players, showing each choice on their seat
- When 3 players pass, the last one sees "You Must Bid" with no Pass button
- Bid buttons only show options higher than current bid
- Kout instantly ends bidding
- Game plays through to completion normally after bidding

- [ ] **Step 5: Update CLAUDE.md**

Update the bidding rules section in `CLAUDE.md` to reflect:
- Randomized initial dealer
- No malzoom/reshuffle
- Last player forced to bid
- Bid history visible on seats

---

## Summary of Removed Code

| What | Where | Why |
|------|-------|-----|
| `MalzoomOutcome` enum | `bid_validator.dart` | No reshuffle mechanic |
| `checkMalzoom()` method | `bid_validator.dart` | No reshuffle mechanic |
| `reshuffleCount` field | `full_game_state.dart` | No reshuffle mechanic |
| `consecutivePasses` field | `full_game_state.dart` | Replaced by `passedPlayers.length` |
| Malzoom handling in `_bidding()` | `local_game_controller.dart` | Replaced by forced last-player bid |
| `reshuffleCount` reset in round loop | `local_game_controller.dart` | Field removed |
| `checkMalzoom()` function | `bid-validator.ts` | Mirror Dart changes |
| `MalzoomOutcome` type | `bid-validator.ts` | Mirror Dart changes |
