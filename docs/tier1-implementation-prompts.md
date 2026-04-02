# Tier 1 Implementation Prompts

Scoped prompts for Claude Code. Execute in order. Each prompt is self-contained.

---

## Prompt 0: Test Scaffold (run first)

```
Create unit tests for the current bot logic BEFORE any changes. These tests lock in existing behavior so we can verify Tier 1 changes don't break anything unintentionally.

Create `test/bot/play_strategy_test.dart` and `test/bot/bid_strategy_test.dart`.

For play_strategy_test.dart, test these scenarios in `_selectFollow()`:
1. Following suit + partner winning → plays lowest
2. Following suit + partner NOT winning + has winner → plays lowest winner
3. Following suit + no winner → plays lowest
4. Void + partner winning → dumps lowest (not trump partner)
5. Void + has Joker + trick >= 7 → plays Joker
6. Void + has Joker + trick < 5 → holds Joker
7. Void + has trump + no Joker → trumps in with lowest winning trump
8. Kout: leads highest trump on first trick

For `_selectLead()`:
9. Has Ace → leads it
10. No Ace → leads from longest non-trump suit

For bid_strategy_test.dart:
11. strength >= 4.5 → BidAction(bab)
12. strength < 4.5 → PassAction
13. isForced + no prior bid → BidAction(bab) minimum
14. currentHighBid exists + can outbid → smallest legal outbid
15. currentHighBid exists + can't outbid → PassAction

Import paths:
- `package:koutbh/offline/bot/play_strategy.dart`
- `package:koutbh/offline/bot/bid_strategy.dart`
- `package:koutbh/shared/models/card.dart`
- `package:koutbh/shared/models/bid.dart`
- `package:koutbh/offline/player_controller.dart`

Card encoding: `GameCard.decode('SA')` = Ace of Spades, `GameCard.decode('JO')` = Joker.
Suits: `Suit.spades`, `Suit.hearts`, `Suit.clubs`, `Suit.diamonds`.
Ranks: `Rank.ace` (14) down to `Rank.seven` (7).

Run `flutter test test/bot/` after creating.
```

---

## Prompt 1: T1.1 — Ace-First Leading

```
In `lib/offline/bot/play_strategy.dart`, modify `_selectLead()`.

Add Ace-first logic BEFORE the existing longest-suit code (before line ~70):

1. Collect all Aces from legalCards
2. If any Ace exists:
   a. Prefer Ace where we also hold King of same suit (cash both sequentially)
   b. Else prefer singleton Ace (win + create void for future ruffing)
   c. Else any Ace
3. Fall through to existing longest-suit logic if no Aces

Exception: if `isKout && isFirstTrick`, the existing Kout-specific logic (lead highest trump) takes priority — Ace-first goes AFTER the Kout first-trick block.

Do NOT touch `_selectFollow()` or any other method.

Run `flutter test test/bot/` and `flutter analyze` after.
```

---

## Prompt 2: T1.2 — Position-Aware Following

```
In `lib/offline/bot/play_strategy.dart`, modify `_selectFollow()`.

Add position awareness. Compute `final myPosition = trickPlays.length;` (0=lead, 1=2nd, 2=3rd, 3=4th/last).

Replace the `followingSuit` block (lines ~120-125) with:

```dart
if (followingSuit) {
  if (myPosition == 3) {
    // Last to play: perfect info. Win cheaply or dump.
    if (partnerWinning) return _lowest(legalCards);
    final winners = _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
    return _lowest(winners.isNotEmpty ? winners : legalCards);
  } else {
    // Not last: play to win (can't assume partner covers)
    final winners = _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
    if (winners.isNotEmpty) return _lowest(winners);
    return _lowest(legalCards);
  }
}
```

The key change: only trust `partnerWinning` when we're last to play (position 3). In positions 1-2, always try to win because opponents haven't played yet.

Do NOT touch the void/Joker section below this block — that's Prompt 3.

Run `flutter test test/bot/` and `flutter analyze` after.
```

---

## Prompt 3: T1.3 — Joker Logic Rewrite

```
In `lib/offline/bot/play_strategy.dart`, modify `_selectFollow()`.

Replace the void-in-led-suit section (everything from the `if (partnerWinning)` after `followingSuit` block through the fallback Joker dump before `return _lowest(legalCards)` at the end). This is roughly lines 127-161 in the current file.

CRITICAL: The `partnerWinning` guard MUST remain OUTSIDE and BEFORE the `if (hasJoker)` block. This prevents trumping over partner's winning trick.

New code:

```dart
// Void in led suit — partner winning: dump low, but dump Joker if poison imminent
if (partnerWinning) {
  if (hasJoker && hand.length <= 2) {
    return legalCards.firstWhere((c) => c.isJoker); // poison risk
  }
  return _lowest(legalCards); // don't trump partner
}

// Void in led suit, NOT partner winning — Joker decision
if (hasJoker) {
  final nonJoker = legalCards.where((c) => !c.isJoker).toList();

  // POISON CHECK: if only 1 non-Joker card left, Joker WILL be last card next trick
  if (nonJoker.length <= 1) {
    return legalCards.firstWhere((c) => c.isJoker); // dump now
  }

  // Use Joker to steal: opponent trumped or played high card
  final opponentTrumped = trumpSuit != null &&
      trickPlays.any((p) => !p.card.isJoker && p.card.suit == trumpSuit);
  if (opponentTrumped) {
    return legalCards.firstWhere((c) => c.isJoker);
  }

  // Late game (≤3 cards) and void: use Joker rather than risk poison
  if (hand.length <= 3) {
    return legalCards.firstWhere((c) => c.isJoker);
  }

  // Otherwise hold Joker
}
```

Then keep the existing trump-in logic and final fallback dump AFTER this block. Remove the old `if (hasJoker && trickNumber >= 6)` fallback — the new block handles all Joker cases.

Run `flutter test test/bot/` and `flutter analyze` after.
```

---

## Prompt 4: T1.4 — Score-Aware Bidding

```
In `lib/offline/bot/bid_strategy.dart`, add score-awareness to `decideBid()`.

1. Add optional named params to `decideBid`:
   ```dart
   static GameAction decideBid(
     List<GameCard> hand,
     BidAmount? currentHighBid, {
     bool isForced = false,
     Map<Team, int>? scores,
     Team? myTeam,
   })
   ```
   Import `Team` from `package:koutbh/shared/models/game_state.dart`.

2. After computing `strength`, add threshold adjustment:
   ```dart
   double thresholdAdjust = 0.0;
   if (scores != null && myTeam != null) {
     final myScore = scores[myTeam] ?? 0;
     final oppScore = scores[myTeam.opponent] ?? 0;
     if (myScore >= 26) thresholdAdjust -= 0.5;
     if (oppScore >= 26) thresholdAdjust -= 0.5;
     if (oppScore >= 25 && myScore <= 5) thresholdAdjust -= 0.8;
   }
   ```

3. Pass adjusted value to `_strengthToBid`:
   ```dart
   final maxBid = _strengthToBid(strength.expectedWinners + thresholdAdjust);
   ```

4. In `lib/offline/bot_player_controller.dart`, update the BidContext case to pass scores:
   ```dart
   BidContext(:final currentHighBid, :final isForced) =>
     BidStrategy.decideBid(
       state.myHand,
       currentHighBid,
       isForced: isForced,
       scores: state.scores,
       myTeam: teamForSeat(seatIndex),
     ),
   ```
   Import `teamForSeat` from `package:koutbh/shared/models/game_state.dart`.

Run `flutter test test/bot/` and `flutter analyze` after.
```

---

## Prompt 5: Update Tests + Verify

```
Update `test/bot/play_strategy_test.dart` and `test/bot/bid_strategy_test.dart` to cover the new Tier 1 behaviors:

New play_strategy tests:
1. Ace-first: hand with A-K same suit → leads Ace (not longest suit card)
2. Ace-first: singleton Ace preferred over Ace with backup
3. Position: seat 2 (2nd to play) following suit → tries to win even if partner led
4. Position: seat 4 (last to play) + partner winning → dumps low
5. Joker: partner winning + 2 cards in hand → dumps Joker (poison escape)
6. Joker: partner winning + 5 cards → dumps lowest (holds Joker)
7. Joker: opponent trumped → plays Joker to steal
8. Joker: 1 non-Joker card left → dumps Joker (next-trick poison prevention)
9. Joker: 5 cards in hand, no special condition → holds Joker

New bid_strategy tests:
10. myScore=28, strength=4.0 → bids (threshold lowered by 0.5)
11. oppScore=28, strength=4.0 → bids (threshold lowered by 0.5)
12. oppScore=26, myScore=3, strength=3.5 → bids (desperate mode, -0.8)
13. No scores passed → same behavior as before (backward compat)

Run `flutter test test/bot/` — all tests must pass.
Run `flutter analyze` — zero issues.
```

---

## Execution Order

1. Prompt 0 (test scaffold) — establishes baseline
2. Prompts 1-4 in order (each builds on clean state)
3. Prompt 5 (update tests + final verify)

Total: ~100 lines of changes across 2 files + ~200 lines of tests.
