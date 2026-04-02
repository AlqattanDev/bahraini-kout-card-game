# Tier 2 Implementation Prompts

Scoped prompts for Claude Code. Refer to `docs/bot-intelligence-plan.md` for full rationale.

**Dependency graph:**
```
Phase 2 (hand eval) ──┐
Phase 3 (bid)      ───┤── all independent, can run in parallel
Phase 4 (trump)    ───┘
                        ↓ (recalibrate thresholds after 2-4 ship)
Phase 1 (foundation) ──── must ship before 5-7
                        ↓
Phase 5 (leading)  ──┐
Phase 6 (following)──┤── sequential (all modify play_strategy.dart)
Phase 7 (Joker)    ──┘
                        ↓
Phase 8 (timing)   ──┐
Phase 9 (personality)─┤── independent
Phase 10 (testing)  ──┘
```

**Execution order (recommended):**
1. Phases 2, 3, 4 in parallel (separate files, no conflicts)
2. Phase 1 (foundation — CardTracker, GameContext, interface change)
3. Phases 5 → 6 → 7 sequentially (same file, each builds on prior)
4. Phases 8, 9, 10 in any order

---

## Prompt P1: Foundation — CardTracker

```
Create `lib/offline/bot/card_tracker.dart`.

This class persists across all 8 tricks within a round, tracking every card played. It is reset at round start. The koutbh deck is 32 cards: S/H/C have 8 each (A,K,Q,J,10,9,8,7), Diamonds has 7 (no 7♦), plus 1 Joker.

```dart
import 'package:koutbh/shared/models/card.dart';

class CardTracker {
  final Set<GameCard> _played = {};
  final Map<int, Set<Suit>> _knownVoids = {};

  /// Call after each confirmed play in LocalGameController._playSingleCard().
  void recordPlay(int seat, GameCard card) {
    _played.add(card);
    // No void inference from Joker plays (Joker is suitless)
    if (card.isJoker) return;
    // If player didn't follow the led suit, infer void
    // (Caller should call inferVoid separately if needed)
  }

  /// Record that a player showed void in a suit (couldn't follow led suit).
  void inferVoid(int seat, Suit suit) {
    _knownVoids.putIfAbsent(seat, () => {}).add(suit);
  }

  Set<GameCard> get playedCards => Set.unmodifiable(_played);

  /// All cards NOT yet played and NOT in my hand.
  Set<GameCard> remainingCards(List<GameCard> myHand) {
    final fullDeck = GameCard.fullDeck(); // must exist or create it
    return fullDeck.difference(_played).difference(myHand.toSet());
  }

  Map<int, Set<Suit>> get knownVoids => Map.unmodifiable(_knownVoids);

  /// How many trump cards remain outside my hand.
  int trumpsRemaining(Suit trumpSuit, List<GameCard> myHand) {
    return remainingCards(myHand)
        .where((c) => !c.isJoker && c.suit == trumpSuit)
        .length;
  }

  /// Is this card the highest remaining in its suit (a "master card")?
  bool isHighestRemaining(GameCard card, List<GameCard> myHand) {
    if (card.isJoker) return true;
    final suit = card.suit!;
    final remaining = remainingCards(myHand)
        .where((c) => !c.isJoker && c.suit == suit);
    // If no remaining cards of this suit exist elsewhere, it's master
    if (remaining.isEmpty) return true;
    final highestRemaining = remaining.map((c) => c.rank!.value).reduce((a, b) => a > b ? a : b);
    return card.rank!.value > highestRemaining;
  }

  /// Is a suit fully exhausted? (all cards of that suit have been played
  /// or are in myHand — no outstanding cards remain with other players)
  bool isSuitExhausted(Suit suit, List<GameCard> myHand) {
    return remainingCards(myHand)
        .where((c) => !c.isJoker && c.suit == suit)
        .isEmpty;
  }

  void reset() {
    _played.clear();
    _knownVoids.clear();
  }
}
```

You also need a `GameCard.fullDeck()` static method if one doesn't exist. The 32-card deck:
- Spades: A,K,Q,J,10,9,8,7
- Hearts: A,K,Q,J,10,9,8,7
- Clubs: A,K,Q,J,10,9,8,7
- Diamonds: A,K,Q,J,10,9,8 (NO 7 of diamonds)
- 1 Joker

Check if `Deck` class in `lib/shared/models/` already has this — if so, reuse. Otherwise add `static Set<GameCard> fullDeck()` to `GameCard`.

**Void inference wiring**: In `LocalGameController._playSingleCard()`, after a valid play is committed (after line 336 where `trickPlays.add(...)` happens), add:
```dart
tracker.recordPlay(seat, action.card);
// Infer void: if not leading and didn't follow led suit
if (!isLead && ledSuit != null && !action.card.isJoker && action.card.suit != ledSuit) {
  tracker.inferVoid(seat, ledSuit);
}
```

The `tracker` must be created before the trick loop in `_playTricks()` (before line 232) and passed through. For now, just create it as a local variable — it will be wired to bot controllers in the next prompt.

Write `test/offline/bot/card_tracker_test.dart`:
- recordPlay adds to playedCards
- remainingCards excludes played + hand
- inferVoid records correctly
- trumpsRemaining counts correctly
- isHighestRemaining: King becomes master after Ace played
- isSuitExhausted: true when all suit cards played or in hand
- reset clears everything

Run `flutter test test/offline/bot/card_tracker_test.dart` and `flutter analyze`.
```

---

## Prompt P1b: Foundation — GameContext + Interface

```
Create `lib/offline/bot/game_context.dart`.

GameContext is a read-only snapshot built from ClientGameState + CardTracker, passed to all bot strategies. It replaces passing raw state fields everywhere.

```dart
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'card_tracker.dart';

class GameContext {
  final int mySeat;
  final Team myTeam;
  final Map<Team, int> scores;
  final BidAmount? currentBid;
  final int? bidderSeat;
  final bool isBiddingTeam;
  final bool isForcedBid;
  final Map<Team, int> trickCounts;
  final List<Team> trickWinners;
  final List<({int seat, String action})>? bidHistory;
  final Suit? trumpSuit;
  final CardTracker? tracker;

  const GameContext({
    required this.mySeat,
    required this.myTeam,
    required this.scores,
    required this.currentBid,
    required this.bidderSeat,
    required this.isBiddingTeam,
    required this.isForcedBid,
    required this.trickCounts,
    required this.trickWinners,
    this.bidHistory,
    this.trumpSuit,
    this.tracker,
  });

  Team get opponentTeam => myTeam.opponent;
  int get partnerSeat => (mySeat + 2) % 4;
  int get myTricks => trickCounts[myTeam] ?? 0;
  int get opponentTricks => trickCounts[opponentTeam] ?? 0;
  int get tricksPlayed => trickWinners.length;

  /// How many more tricks the bidding team needs to make the bid.
  int get tricksNeededForBid {
    final biddingTeam = bidderSeat != null ? teamForSeat(bidderSeat!) : myTeam;
    final won = trickCounts[biddingTeam] ?? 0;
    return (currentBid?.value ?? 5) - won;
  }

  factory GameContext.fromClientState(
    ClientGameState state,
    int seatIndex, {
    CardTracker? tracker,
    bool isForcedBid = false,
  }) {
    final myTeam = teamForSeat(seatIndex);
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : null;
    return GameContext(
      mySeat: seatIndex,
      myTeam: myTeam,
      scores: state.scores,
      currentBid: state.currentBid,
      bidderSeat: bidderSeat,
      isBiddingTeam: bidderSeat != null && teamForSeat(bidderSeat) == myTeam,
      isForcedBid: isForcedBid,
      trickCounts: state.tricks,
      trickWinners: state.trickWinners,
      trumpSuit: state.trumpSuit,
      tracker: tracker,
    );
  }
}
```

**Note on bidHistory**: The local game controller stores bidHistory as `List<({int seat, String action})>` but ClientGameState stores it as `List<({String playerUid, String action})>`. GameContext needs the seat-based version. For now, bidHistory is passed separately to BidStrategy (which already knows seatIndex). Don't add bidHistory to GameContext until the BidStrategy overhaul (Phase 3) — it will handle the conversion there.

**Interface change** — update `lib/offline/player_controller.dart`:
```dart
abstract class PlayerController {
  Future<GameAction> decideAction(
    ClientGameState state,
    ActionContext context, {
    CardTracker? tracker,
  });
}
```

Update `lib/offline/human_player_controller.dart` — add `{CardTracker? tracker}` to `decideAction` signature, ignore it (humans don't use tracker).

Update `lib/offline/bot_player_controller.dart`:
- Store `CardTracker?` reference (passed from controller)
- Build `GameContext.fromClientState(state, seatIndex, tracker: tracker)`
- Pass context to all strategies (strategies will accept it in later phases — for now just build it, don't pass it yet. This avoids breaking strategy signatures until those phases land.)
- Keep the current direct calls to strategies for now. Each Phase (2,3,4,5,6,7) will update its own strategy to accept GameContext when it lands.

Update `lib/offline/local_game_controller.dart`:
- In `_playTricks()`: create `final tracker = CardTracker()` before the trick loop
- Pass tracker to `controllers[seat]!.decideAction(clientState, context, tracker: tracker)`
- After valid play committed (line 336), add: `tracker.recordPlay(seat, action.card);` and void inference as described in P1.

Run `flutter analyze` and `flutter test`.
```

---

## Prompt P2: Hand Evaluation Fixes

```
Modify `lib/offline/bot/hand_evaluator.dart`. These are the Phase 2 changes from the bot intelligence plan.

**Step 2.1 — Fix honor valuation.** Replace the honor scoring block:

Before:
```dart
if (rank == Rank.ace) cardScore = 0.9;
else if (rank == Rank.king) cardScore = count >= 3 ? 0.7 : 0.4;
else if (rank == Rank.queen) cardScore = count >= 4 ? 0.4 : 0.15;
else if (rank == Rank.jack || rank == Rank.ten) cardScore = 0.1;
```

After:
```dart
if (rank == Rank.ace) cardScore = 0.9;
else if (rank == Rank.king) cardScore = count >= 3 ? 0.8 : 0.6;
else if (rank == Rank.queen) cardScore = count >= 3 ? 0.5 : 0.3;
else if (rank == Rank.jack) cardScore = 0.2;
else if (rank == Rank.ten) cardScore = 0.1;
```

**Step 2.2 — Trump honor bonus.** Replace the trump bonus block:

Before:
```dart
if (trumpSuit != null && suit == trumpSuit && rank.value < Rank.jack.value) {
  cardScore += 0.3;
}
```

After:
```dart
if (trumpSuit != null && suit == trumpSuit) {
  if (rank == Rank.ace) cardScore += 0.5;
  else if (rank == Rank.king) cardScore += 0.4;
  else if (rank == Rank.queen) cardScore += 0.3;
  else if (rank == Rank.jack) cardScore += 0.2;
  else cardScore += 0.3;
}
```

**Step 2.3 — Suit texture scoring.** Add a new static method `_suitTextureBonus` and call it after individual card scoring:

```dart
static double _suitTextureBonus(List<GameCard> hand) {
  double bonus = 0.0;
  final bySuit = <Suit, List<Rank>>{};
  for (final c in hand) {
    if (c.isJoker) continue;
    bySuit.putIfAbsent(c.suit!, () => []).add(c.rank!);
  }
  for (final ranks in bySuit.values) {
    final hasAce = ranks.contains(Rank.ace);
    final hasKing = ranks.contains(Rank.king);
    final hasQueen = ranks.contains(Rank.queen);
    if (hasAce && hasKing && hasQueen) {
      bonus += 0.5; // A-K-Q: 3 near-guaranteed tricks
    } else if (hasAce && hasKing) {
      bonus += 0.3; // A-K: both near-guaranteed
    } else if (hasKing && hasQueen && !hasAce) {
      bonus += 0.2; // K-Q without Ace: Queen protects King
    }
  }
  return bonus;
}
```

Call it after the per-card loop, before the long suit bonus:
```dart
score += _suitTextureBonus(hand);
```

**Step 2.4+2.5 — Void and ruffing potential (consolidated).** Replace the void bonus loop:

Before:
```dart
for (final suit in Suit.values) {
  if (!suitCounts.containsKey(suit)) score += 0.2;
}
```

After:
```dart
final hasAnyTrump = hand.any((c) =>
    !c.isJoker && trumpSuit != null && c.suit == trumpSuit);

for (final suit in Suit.values) {
  if (!suitCounts.containsKey(suit)) {
    if (suit == trumpSuit) {
      // Void in trump: bad. No bonus.
    } else if (hasAnyTrump) {
      score += 0.3; // ruffing potential
    } else {
      score += 0.1; // void but no trump
    }
  }
}
```

**IMPORTANT**: These changes raise average expectedWinners by ~0.5. Phase 3 (bid thresholds) must recalibrate after this ships. Leave a TODO comment at the top of the file: `// TODO: Phase 2 raised hand values ~0.5. Bid thresholds may need recalibration (Phase 3).`

Create `test/offline/bot/hand_evaluator_test.dart`:
- King in 2-card suit scores 0.6 (not 0.4)
- Queen in 3-card suit scores 0.5 (not 0.15)
- Jack scores 0.2 (not same as Ten at 0.1)
- Trump Ace total = 0.9 + 0.5 = 1.4
- Trump 7 total = 0.0 + 0.3 = 0.3 (unchanged)
- A-K same suit gets +0.3 texture bonus
- A-K-Q same suit gets +0.5 texture bonus
- K-Q without Ace gets +0.2 texture bonus
- Void in trump suit = 0 bonus
- Void in non-trump + has trump = 0.3 bonus
- Void in non-trump + no trump = 0.1 bonus

Run `flutter test test/offline/bot/hand_evaluator_test.dart` and `flutter analyze`.
```

---

## Prompt P3: Bid Strategy Overhaul

```
Modify `lib/offline/bot/bid_strategy.dart`. These are Phase 3 changes from the bot intelligence plan.

The current file has `decideBid(hand, currentHighBid, {isForced, scores, myTeam})` from Tier 1.
Expand it to accept full game context for score/position/partner awareness.

**Updated signature:**
```dart
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'hand_evaluator.dart';

class BidStrategy {
  static GameAction decideBid(
    List<GameCard> hand,
    BidAmount? currentHighBid, {
    bool isForced = false,
    Map<Team, int>? scores,
    Team? myTeam,
    int? mySeat,
    List<({int seat, String action})>? bidHistory,
  }) {
```

**Step 3.1 — Score-aware bidding (corrected formula).** Replace the existing thresholdAdjust block with:

```dart
double thresholdAdjust = 0.0;
if (scores != null && myTeam != null) {
  final my = scores[myTeam] ?? 0;
  final opp = scores[myTeam.opponent] ?? 0;
  if (my + 5 - opp >= 31) {
    thresholdAdjust -= 1.0;  // any bid wins the game
  } else if (my + 5 >= 31) {
    thresholdAdjust -= 0.8;  // Bab alone reaches 31
  } else if (my >= 26) {
    thresholdAdjust -= 0.5;
  } else if (opp >= 26) {
    thresholdAdjust -= 0.5;
  } else if (opp >= 25 && my <= 5) {
    thresholdAdjust -= 0.8;
  }
}
```

**Step 3.2 — Position-aware bidding.** After score adjust, add position awareness based on how many entries are in bidHistory:

```dart
if (bidHistory != null && mySeat != null) {
  final actedBefore = bidHistory.length; // entries before my turn
  if (actedBefore == 0) thresholdAdjust += 0.3;      // first, no info
  else if (actedBefore == 1) { /* no adjustment */ }
  else if (actedBefore == 2) thresholdAdjust -= 0.2;
  else if (actedBefore >= 3) thresholdAdjust -= 0.3;  // last, max info
}
```

**Step 3.3 — Partner inference from bid history.** Add after position awareness:

```dart
if (bidHistory != null && mySeat != null) {
  final partnerSeat = (mySeat + 2) % 4;
  final partnerEntry = bidHistory.where((e) => e.seat == partnerSeat).lastOrNull;
  if (partnerEntry != null && partnerEntry.action != 'pass') {
    thresholdAdjust -= 0.3; // partner bid → reliable
  } else if (partnerEntry?.action == 'pass') {
    thresholdAdjust += 0.3; // partner passed → weak
  }
}
```

**Step 3.4 — Forced bid mode.** The existing `if (isForced)` block already returns BidAction(bab) minimum. Add a comment that `isForcedBid` flag propagates to GameContext for play strategy (Phase 6.6).

**Step 3.5 — Fuzzy thresholds.** Skip for now — requires BotDifficulty (Phase 9). Add a `// TODO: Phase 3.5 — fuzzy thresholds for Aggressive bots (needs BotDifficulty from Phase 9)` comment.

**Step 3.6 — Tactical overbidding.** After threshold adjustment and before the existing outbid logic: if opponent bid and bot's adjusted strength exceeds the next bid level by > 0.3, consider bidding one higher to steal:

```dart
if (currentHighBid != null && bidHistory != null) {
  final lastBidder = bidHistory.lastWhere(
    (e) => e.action != 'pass',
    orElse: () => bidHistory.first,
  );
  // If opponent bid (not partner)
  if (mySeat != null) {
    final isOpponentBid = teamForSeat(lastBidder.seat) != myTeam;
    if (isOpponentBid) {
      final nextBidValue = currentHighBid.value + 1;
      final nextBid = BidAmount.values.where((b) => b.value == nextBidValue).firstOrNull;
      if (nextBid != null) {
        final adjustedStrength = strength.expectedWinners + thresholdAdjust;
        final nextThreshold = _bidThreshold(nextBid);
        if (adjustedStrength > nextThreshold + 0.3) {
          // Comfortable margin — overbid to steal
          return BidAction(nextBid);
        }
      }
    }
  }
}
```

Add helper:
```dart
static double _bidThreshold(BidAmount bid) {
  return switch (bid) {
    BidAmount.bab => 4.5,
    BidAmount.six => 5.5,
    BidAmount.seven => 6.5,
    BidAmount.kout => 7.5,
  };
}
```

**Caller update** in `bot_player_controller.dart`: pass the new params:
```dart
BidContext(:final currentHighBid, :final isForced) =>
  BidStrategy.decideBid(
    state.myHand,
    currentHighBid,
    isForced: isForced,
    scores: state.scores,
    myTeam: teamForSeat(seatIndex),
    mySeat: seatIndex,
    bidHistory: _convertBidHistory(state),
  ),
```

Add a helper method to convert ClientGameState bidHistory (playerUid-based) to seat-based:
```dart
static List<({int seat, String action})> _convertBidHistory(ClientGameState state) {
  return state.bidHistory.map((e) => (
    seat: state.playerUids.indexOf(e.playerUid),
    action: e.action,
  )).toList();
}
```

Bid history format reminder: bids are stored as "5","6","7","8" (the numeric value). Passes are "pass". NOT "BID_BAB" or "PASS".

Create/update `test/offline/bot/bid_strategy_test.dart`:
- At 28-0, bids with 3.5 expectedWinners
- At 0-28, bids aggressively
- At my+5-opp >= 31, bids with anything (threshold -1.0)
- Partner passed → raises threshold by 0.3
- Partner bid → lowers threshold by 0.3
- Position 0 (first) is more conservative than position 3 (last)
- Tactical overbid: opponent bid Bab, bot has 6.0 strength → bids Six
- Forced bid still returns minimum legal bid

Run `flutter test test/offline/bot/bid_strategy_test.dart` and `flutter analyze`.
```

---

## Prompt P4: Trump Strategy Improvements

```
Modify `lib/offline/bot/trump_strategy.dart`. These are Phase 4 changes from the bot intelligence plan.

**Updated signature** to accept bid level and forced flag:
```dart
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';

class TrumpStrategy {
  static Suit selectTrump(
    List<GameCard> hand, {
    BidAmount? bidLevel,
    bool isForcedBid = false,
  }) {
```

**Step 4.1 — Minimum count gate.** Never pick a suit with fewer than 2 cards. Filter candidates first:
```dart
final validSuits = suitCounts.entries
    .where((e) => e.value >= 2)
    .map((e) => e.key)
    .toSet();
// If nothing has 2+ (shouldn't happen in 32-card 4-player), fall back to all
final candidates = validSuits.isNotEmpty ? validSuits : suitCounts.keys.toSet();
```

Only score suits in `candidates`.

**Step 4.2 — Bid-level aware scoring.** Replace the flat `count * 2.0 + strength` formula:
```dart
double trumpScore(int count, double strength, BidAmount? bid) {
  final isKout = bid == BidAmount.kout;
  final lengthWeight = isKout ? 1.5 : 2.0;
  final strengthWeight = isKout ? 2.0 : 1.0;
  return count * lengthWeight + strength * strengthWeight;
}
```

Kout cares more about honors (need to win every trick), less about length. Lower bids benefit more from length (control).

**Step 4.3 — Side suit strength.** For each candidate trump, add strength from non-trump Aces and Kings:
```dart
double sideStrength = 0.0;
for (final card in hand) {
  if (!card.isJoker && card.suit != candidateSuit) {
    if (card.rank == Rank.ace) sideStrength += 0.9;
    else if (card.rank == Rank.king) sideStrength += 0.5;
  }
}
score += sideStrength;
```

**Step 4.4 — Ruff value.** For each candidate trump, add +0.5 per void non-trump suit:
```dart
for (final suit in Suit.values) {
  if (suit != candidateSuit && !suitCounts.containsKey(suit)) {
    score += 0.5;
  }
}
```

**Step 4.5 — Forced-bid defensive trump.** When `isForcedBid == true`: pick longest suit regardless of honor strength. Length = control when you can't win:
```dart
if (isForcedBid) {
  // Just pick longest suit
  Suit? longest;
  int maxCount = 0;
  for (final entry in suitCounts.entries) {
    if (entry.value > maxCount) {
      maxCount = entry.value;
      longest = entry.key;
    }
  }
  return longest ?? Suit.spades;
}
```

Put this at the top of the method, before any scoring.

**Caller update** in `bot_player_controller.dart`:
```dart
TrumpContext() => TrumpAction(TrumpStrategy.selectTrump(
  state.myHand,
  bidLevel: state.currentBid,
  isForcedBid: /* need to track this — for now pass false, Phase 1b wires it via GameContext */,
)),
```

Note: `isForcedBid` tracking requires GameContext from Phase 1b. For now, default to `false`. Add a `// TODO: wire isForcedBid from GameContext (Phase 1b)` comment.

Create/update `test/offline/bot/trump_strategy_test.dart`:
- 1-card suit never selected (when 2+ card alternatives exist)
- Kout prefers A-K-Q in 3 cards over 7-8-9-10 in 4 cards
- Bab prefers 4 low cards over 3 high cards (length wins for low bids)
- Side suit A-K boosts score
- Void non-trump suit adds +0.5
- Forced bid picks longest suit regardless of strength

Run `flutter test test/offline/bot/trump_strategy_test.dart` and `flutter analyze`.
```

---

## Prompt P5: Play Strategy — Leading Improvements

```
Modify `lib/offline/bot/play_strategy.dart`, specifically `_selectLead()`.

Prerequisites: Phase 1 (CardTracker, GameContext) must be merged. Update `selectCard` signature to accept GameContext:
```dart
static PlayCardAction selectCard({
  required List<GameCard> hand,
  required List<({String playerUid, GameCard card})> trickPlays,
  required Suit? trumpSuit,
  required Suit? ledSuit,
  required int mySeat,
  String? partnerUid,
  bool isKout = false,
  bool isFirstTrick = false,
  GameContext? context,  // NEW — null for backward compat
}) {
```

Pass context through to `_selectLead`:
```dart
static GameCard _selectLead(List<GameCard> legalCards, Suit? trumpSuit, {GameContext? context}) {
```

**The Ace-first logic from T1.1 stays.** Add these improvements AFTER Ace-first and BEFORE the fallback longest-suit logic:

**Step 5.2 — Trump leads for bidding team.**
```dart
if (context != null && context.isBiddingTeam && trumpSuit != null) {
  final myTrumps = legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
  if (myTrumps.length >= 3) {
    // Strip opponents' trump — especially important for Kout
    myTrumps.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
    return myTrumps.first; // lead highest trump
  }
}
```

**Step 5.3 — Partner-void leads (requires CardTracker).**
```dart
if (context?.tracker != null) {
  final partnerSeat = context!.partnerSeat;
  final partnerVoids = context.tracker!.knownVoids[partnerSeat] ?? {};
  for (final voidSuit in partnerVoids) {
    if (voidSuit == trumpSuit) continue; // can't ruff trump with trump
    final suitCards = legalCards.where((c) => !c.isJoker && c.suit == voidSuit).toList();
    if (suitCards.isNotEmpty) {
      // Lead into partner's void — they'll ruff with trump
      suitCards.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return suitCards.first; // lead low (partner wins with trump anyway)
    }
  }
}
```

**Step 5.4 — Short-suit leads for defense.**
```dart
if (context != null && !context.isBiddingTeam) {
  // Lead singleton non-trump to create void for future ruffing
  final nonTrumpSingles = legalCards.where((c) {
    if (c.isJoker) return false;
    if (c.suit == trumpSuit) return false;
    return legalCards.where((o) => !o.isJoker && o.suit == c.suit).length == 1;
  }).toList();
  if (nonTrumpSingles.isNotEmpty) {
    return nonTrumpSingles.first;
  }
}
```

**Step 5.5 — Low leads for probing.** Change the fallback longest-suit logic to lead LOW instead of HIGH:
In the existing fallback block, change `bestSuitCards.sort((a, b) => b.rank!.value.compareTo(a.rank!.value))` to:
```dart
bestSuitCards.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
return bestSuitCards.first; // lead LOW — probe cheaply, preserve honors
```

**Step 5.6 — Master card awareness (requires CardTracker).**
Insert BEFORE the Ace-first logic (master cards are even better than Aces):
```dart
if (context?.tracker != null) {
  for (final card in legalCards) {
    if (card.isJoker) continue;
    if (card.suit == trumpSuit) continue; // don't auto-lead trump masters
    if (context!.tracker!.isHighestRemaining(card, context.tracker!.playedCards.toList())) {
      // Wait — isHighestRemaining needs myHand not playedCards.
      // Actually it needs the bot's hand to compute remaining.
    }
  }
}
```

Correction — `isHighestRemaining` takes `myHand` (the full hand, not legalCards):
```dart
if (context?.tracker != null) {
  // Lead master cards — guaranteed winners
  final masters = legalCards.where((c) =>
    !c.isJoker &&
    c.suit != trumpSuit &&
    context!.tracker!.isHighestRemaining(c, /* need hand here */)
  ).toList();
  if (masters.isNotEmpty) {
    return masters.first;
  }
}
```

You'll need to pass `hand` (the full hand) to `_selectLead`. Update the call: `_selectLead(legalCards, trumpSuit, context: context, hand: hand)`.

**Priority order in _selectLead:**
1. Kout first trick (existing — forced to lead trump)
2. Master cards (5.6) — guaranteed winners
3. Aces (T1.1 — near-guaranteed)
4. Trump strip leads (5.2) — for bidding team with 3+ trump
5. Partner-void leads (5.3) — set up ruffs
6. Short-suit leads (5.4) — defense only
7. Low from longest suit (5.5) — probing fallback

Update caller in `selectCard` to pass context.
Update `bot_player_controller.dart` to build and pass GameContext to PlayStrategy.

Run `flutter test` and `flutter analyze`.
```

---

## Prompt P6: Play Strategy — Following Improvements

```
Modify `lib/offline/bot/play_strategy.dart`, specifically `_selectFollow()`.

Prerequisites: Phase 1 (CardTracker, GameContext) and Phase 5 (selectCard accepts GameContext) must be merged.

Add `GameContext? context` param to `_selectFollow`:
```dart
static GameCard _selectFollow({
  required List<GameCard> legalCards,
  required List<GameCard> hand,
  required List<({String playerUid, GameCard card})> trickPlays,
  required Suit? trumpSuit,
  required Suit? ledSuit,
  String? partnerUid,
  GameContext? context,  // NEW
}) {
```

**Step 6.2 — Strategic dumping.** Replace `_lowest(legalCards)` calls (when dumping) with a smarter dump method:

```dart
static GameCard _strategicDump(List<GameCard> legalCards, List<GameCard> hand, Suit? trumpSuit) {
  final dumpable = legalCards.where((c) => !c.isJoker).toList();
  if (dumpable.isEmpty) return legalCards.first;

  // Prefer isolated cards (singleton in a suit) — clears void for future ruffing
  final singletons = dumpable.where((c) {
    final suitCount = hand.where((h) => !h.isJoker && h.suit == c.suit).length;
    return suitCount == 1 && c.suit != trumpSuit;
  }).toList();
  if (singletons.isNotEmpty) {
    singletons.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return singletons.first; // dump lowest singleton
  }

  // Avoid breaking honor combos — don't dump King if we hold Ace of same suit
  final safeToBreak = dumpable.where((c) {
    if (c.suit == trumpSuit) return false; // preserve trump
    // Don't dump King if holding Ace same suit
    if (c.rank == Rank.king && hand.any((h) => h.suit == c.suit && h.rank == Rank.ace)) return false;
    // Don't dump Queen if holding King same suit
    if (c.rank == Rank.queen && hand.any((h) => h.suit == c.suit && h.rank == Rank.king)) return false;
    return true;
  }).toList();

  if (safeToBreak.isNotEmpty) {
    safeToBreak.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return safeToBreak.first;
  }

  // Fallback: lowest non-trump, then lowest anything
  final nonTrump = dumpable.where((c) => c.suit != trumpSuit).toList();
  if (nonTrump.isNotEmpty) {
    nonTrump.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return nonTrump.first;
  }
  dumpable.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
  return dumpable.first;
}
```

Replace `_lowest(legalCards)` calls in dump scenarios with `_strategicDump(legalCards, hand, trumpSuit)`. Keep `_lowest()` for "win cheaply" scenarios (where we're picking from winners).

**Step 6.3 — Trump conservation (requires CardTracker).** Before the "try to trump in" block, add:

```dart
if (context?.tracker != null && trumpSuit != null) {
  final trumpsOut = context!.tracker!.trumpsRemaining(trumpSuit, hand);
  final myTrumps = legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();

  // If 0-1 trumps remain outside hand, our trump is dominant — save for critical tricks
  if (trumpsOut <= 1 && myTrumps.length == 1) {
    // Only trump if trick is high-value or we MUST win
    final trickHasHonor = trickPlays.any((p) =>
      !p.card.isJoker && (p.card.rank == Rank.ace || p.card.rank == Rank.king));
    if (!trickHasHonor && context.tricksNeededForBid > 1) {
      // Save trump, dump instead
      return _strategicDump(legalCards, hand, trumpSuit);
    }
  }
}
```

**Step 6.4 — Overtrump evaluation (requires CardTracker).** In the existing trump-in block, before blindly playing lowest trump:
```dart
// Existing: if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
// Add before that line:
final trickHasValue = trickPlays.any((p) =>
  !p.card.isJoker && (p.card.rank == Rank.ace || p.card.rank == Rank.king));
if (!trickHasValue && context != null && !context.isBiddingTeam) {
  // Low-value trick as defender — save trump, dump instead
  return _strategicDump(legalCards, hand, trumpSuit);
}
```

**Step 6.5 — Defensive play awareness.** At the TOP of `_selectFollow`, add bid-progress awareness:

```dart
if (context != null) {
  final needed = context.tricksNeededForBid;
  if (context.isBiddingTeam && needed <= 0) {
    // Bid already made — dump to end round quickly
    return _strategicDump(legalCards, hand, trumpSuit);
  }
  // Defending and they need exactly 1 more trick: MUST win this one
  if (!context.isBiddingTeam && needed == 1) {
    // Use everything — Joker, trump, whatever wins
    if (hasJoker) return legalCards.firstWhere((c) => c.isJoker);
    // Try trump
    if (trumpSuit != null) {
      final trumpCards = legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
      final winningTrumps = _cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);
      if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
    }
    // Fall through to normal logic
  }
}
```

**Step 6.6 — Forced-bid survival mode.** If `context?.isForcedBid == true`:
```dart
if (context?.isForcedBid == true) {
  // Survival: minimize loss. Don't chase tricks.
  if (followingSuit) {
    // Only win if we have a guaranteed winner (Ace)
    final aces = legalCards.where((c) => c.rank == Rank.ace).toList();
    if (aces.isNotEmpty) return aces.first;
    return _lowest(legalCards);
  }
  // Void: dump, don't trump
  return _strategicDump(legalCards, hand, trumpSuit);
}
```

Put this early in `_selectFollow`, after the `followingSuit` computation but before the main logic blocks.

Run `flutter test` and `flutter analyze`.
```

---

## Prompt P7: Joker Overhaul

```
Modify `lib/offline/bot/play_strategy.dart`, specifically the Joker handling in `_selectFollow()`.

Prerequisites: Phase 1 (CardTracker) and Phase 6 merged.

**Step 7.2 — Joker as strategic weapon.** Replace the current Joker block with context-aware logic:

```dart
if (hasJoker) {
  final nonJoker = legalCards.where((c) => !c.isJoker).toList();

  // 7.3: Poison detection with CardTracker
  bool poisonRisk = false;
  if (nonJoker.isEmpty) {
    poisonRisk = true;
  } else if (nonJoker.length <= 2 && context?.tracker != null) {
    // Check if non-Joker cards' suits are still active
    poisonRisk = nonJoker.any((c) =>
      !context!.tracker!.isSuitExhausted(c.suit!, hand));
  } else if (nonJoker.length <= 1) {
    poisonRisk = true; // fallback without tracker
  }

  if (poisonRisk) {
    return legalCards.firstWhere((c) => c.isJoker); // dump Joker now
  }

  // 7.4: Joker urgency scoring
  double urgency = 0.0;

  // Critical trick: team needs exactly 1 more trick
  if (context != null) {
    final needed = context.isBiddingTeam
      ? context.tricksNeededForBid
      : (8 - (context.currentBid?.value ?? 5) + 1) - context.opponentTricks;
    if (needed == 1) urgency += 0.5;
  }

  // Opponent trumped this trick
  final opponentTrumped = trumpSuit != null &&
      trickPlays.any((p) => !p.card.isJoker && p.card.suit == trumpSuit);
  if (opponentTrumped) urgency += 0.3;

  // Late game (<=3 cards) — higher urgency to avoid poison
  if (hand.length <= 3) urgency += 0.3;

  // Partner winning → don't waste
  if (partnerWinning) urgency -= 0.8;

  if (urgency > 0.3) {
    return legalCards.firstWhere((c) => c.isJoker);
  }

  // Otherwise hold Joker
}
```

**Step 7.5 — Endgame Joker planning.** Add before the Joker block:
```dart
// Endgame: if <=2 cards left, one is Joker, and we might be forced to lead next trick
// with Joker as only option → dump it now while following
if (hand.length <= 2 && hasJoker && hand.where((c) => !c.isJoker).length <= 1) {
  return legalCards.firstWhere((c) => c.isJoker);
}
```

**Also update the partnerWinning block** to use CardTracker-aware poison detection:
```dart
if (partnerWinning) {
  if (hasJoker) {
    bool poisonRisk = false;
    final nonJoker = legalCards.where((c) => !c.isJoker).toList();
    if (nonJoker.length <= 1) {
      poisonRisk = true;
    } else if (context?.tracker != null && nonJoker.length <= 2) {
      poisonRisk = nonJoker.any((c) =>
        !context!.tracker!.isSuitExhausted(c.suit!, hand));
    }
    if (poisonRisk) return legalCards.firstWhere((c) => c.isJoker);
  }
  return _strategicDump(legalCards, hand, trumpSuit);
}
```

Create/update Joker-specific tests:
- Joker NOT dumped when partner winning and no poison risk
- Joker played when team needs exactly 1 trick and urgency > 0.3
- Joker dumped when poison detected via isSuitExhausted
- Joker held when suits are exhausted (no poison risk despite few cards)
- Joker dumped when only 1 non-Joker card and its suit is active
- Endgame: 2 cards (Joker + 1), following → dumps Joker

Run `flutter test` and `flutter analyze`.
```

---

## Prompt P8: Bot Thinking Time

```
Modify `lib/shared/constants/timing.dart` and `lib/offline/local_game_controller.dart`.

Replace the flat bot thinking time with situation-aware delays.

**In timing.dart**, replace:
```dart
static const int botThinkingMinMs = 3000;
static const int botThinkingRangeMs = 2000;
```

With a method (convert to non-const class or add a static method):
```dart
import 'dart:math';

abstract final class GameTiming {
  // ... existing consts unchanged ...

  static final _rng = Random();

  /// Situation-aware bot thinking delay.
  static Duration botThinkingDelay({
    required int legalMoves,
    required int trickNumber,
    bool isBidding = false,
    BidAmount? bidAmount,
    bool isForcedBid = false,
    bool isPassing = false,
  }) {
    int ms;
    if (isBidding) {
      if (isPassing) {
        ms = 800 + _rng.nextInt(400);
      } else if (isForcedBid) {
        ms = 1000 + _rng.nextInt(1000);
      } else if (bidAmount == BidAmount.seven || bidAmount == BidAmount.kout) {
        ms = 2500 + _rng.nextInt(1500);
      } else {
        ms = 1500 + _rng.nextInt(1000);
      }
    } else {
      // Playing
      if (legalMoves == 1) {
        ms = 500 + _rng.nextInt(500);
      } else if (trickNumber >= 7) {
        ms = 2000 + _rng.nextInt(2000); // endgame tension
      } else {
        ms = 1500 + _rng.nextInt(2000);
      }
    }
    return Duration(milliseconds: ms);
  }
}
```

Import BidAmount: `import 'package:koutbh/shared/models/bid.dart';`

**In local_game_controller.dart**, update `_botThinkingDelay` to use the new method. Find the current implementation and replace with context-aware calls. You'll need to pass appropriate parameters based on what phase the game is in.

The existing `_botThinkingDelay` likely just does:
```dart
if (enableDelays && controllers[seat] is BotPlayerController) {
  await Future.delayed(Duration(milliseconds: botThinkingMinMs + Random().nextInt(botThinkingRangeMs)));
}
```

Replace with appropriate `GameTiming.botThinkingDelay(...)` calls in the bidding and playing phases.

No tests needed — verify by playing a game. Obvious moves should feel instant, hard decisions should have longer pauses.

Run `flutter analyze`.
```

---

## Prompt P9: Difficulty / Personality System

```
Create `lib/offline/bot/bot_difficulty.dart`:

```dart
enum BotDifficulty {
  conservative,
  balanced,
  aggressive;

  /// Bid threshold adjustment. Negative = bids more.
  double get bidAdjust => switch (this) {
    conservative => 0.3,
    balanced => 0.0,
    aggressive => -0.3,
  };

  /// Whether to use fuzzy (probabilistic) bidding.
  bool get useFuzzyBid => this == aggressive;

  /// Trump selection: aggressive prefers longer suits, conservative prefers stronger.
  double get trumpLengthWeight => switch (this) {
    conservative => 1.5,
    balanced => 2.0,
    aggressive => 2.5,
  };

  double get trumpStrengthWeight => switch (this) {
    conservative => 2.0,
    balanced => 1.0,
    aggressive => 0.5,
  };

  /// How aggressively to use Joker. Lower = more aggressive.
  double get jokerUrgencyThreshold => switch (this) {
    conservative => 0.6,
    balanced => 0.3,
    aggressive => 0.1,
  };
}
```

**Wire into BotPlayerController:**
```dart
class BotPlayerController implements PlayerController {
  final int seatIndex;
  final BotDifficulty difficulty;

  BotPlayerController({
    required this.seatIndex,
    this.difficulty = BotDifficulty.balanced,
  });
```

Pass `difficulty` into GameContext (add field). Each strategy reads it:
- BidStrategy: add `difficulty.bidAdjust` to thresholdAdjust
- TrumpStrategy: use `difficulty.trumpLengthWeight` and `difficulty.trumpStrengthWeight`
- PlayStrategy: use `difficulty.jokerUrgencyThreshold` for Joker decisions

**Add fuzzy bidding for aggressive bots** (Step 3.5 from plan):
```dart
if (difficulty.useFuzzyBid) {
  final probability = 1.0 / (1.0 + exp(-8.0 * (adjustedStrength - threshold)));
  if (Random().nextDouble() < probability) return BidAction(bid);
}
```

Import `dart:math` for `exp`.

**UI change**: In `lib/app/screens/offline_lobby_screen.dart` (or wherever bot configuration happens), add radio buttons or a dropdown for Conservative / Balanced / Aggressive. Default: Balanced.

When creating BotPlayerControllers in LocalGameController, pass the selected difficulty.

Create/update tests:
- Same hand → conservative passes, balanced bids Bab, aggressive bids Six
- Conservative Joker threshold higher than aggressive
- All three play legal moves (no crashes)

Run `flutter test` and `flutter analyze`.
```

---

## Prompt P10: Testing & Validation

```
This is the final testing pass. Create comprehensive tests and a bot-vs-bot simulation.

**Step 10.1 — Ensure all unit test files exist and pass:**
- `test/offline/bot/hand_evaluator_test.dart`
- `test/offline/bot/bid_strategy_test.dart`
- `test/offline/bot/trump_strategy_test.dart`
- `test/offline/bot/play_strategy_test.dart`
- `test/offline/bot/card_tracker_test.dart`

Each should cover the scenarios listed in their respective prompts above.

**Step 10.2 — Integration test.** Create `test/offline/bot/integration_test.dart`:
- 4 bots play a complete round (deal → bid → trump → 8 tricks → score)
- Verify: all plays are legal (no validation errors), scoring is correct, CardTracker stays in sync
- Run 100 rounds, assert zero crashes

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/local_game_controller.dart';
import 'package:koutbh/offline/bot_player_controller.dart';

void main() {
  test('100 bot-vs-bot rounds complete without errors', () async {
    for (int i = 0; i < 100; i++) {
      final controller = LocalGameController(
        controllers: {
          0: BotPlayerController(seatIndex: 0),
          1: BotPlayerController(seatIndex: 1),
          2: BotPlayerController(seatIndex: 2),
          3: BotPlayerController(seatIndex: 3),
        },
        enableDelays: false,
      );
      // Play one full round
      await controller.playRound();
      // If we get here without throwing, the round was valid
      controller.dispose();
    }
  });
}
```

Adjust the API calls above to match actual LocalGameController constructor/method names.

**Step 10.3 — Bot-vs-bot personality validation.** Create `test/offline/bot/personality_test.dart`:
Run 200 simulated games for each matchup:
- 2 Aggressive vs 2 Conservative → Aggressive should win 55-65%
- 2 Balanced vs 2 Conservative → Balanced should win 52-60%
- 2 Balanced vs 2 Balanced → ~50/50

**Step 10.4 — Regression scenarios.** Create `test/offline/bot/regression_test.dart`:
- Joker + A-K trump + A-A-A sides → bids Kout
- All 7s and 8s → passes
- Defending at trick 7, opponent needs 1 more → bot wins THIS trick
- Joker + 1 non-Joker, suit active → dumps Joker (poison risk)
- Joker + 1 non-Joker, suit exhausted → holds Joker (no risk)
- Forced bid → survival mode (dumps low, doesn't chase)
- Partner winning last position → dumps low (doesn't trump partner)
- Score 30-0 → bids with anything

Run `flutter test` — all tests must pass.
Run `flutter analyze` — zero issues.
```

---

## Quick Reference: File Creation/Modification Map

**New files (create):**
| Prompt | File |
|--------|------|
| P1 | `lib/offline/bot/card_tracker.dart` |
| P1b | `lib/offline/bot/game_context.dart` |
| P9 | `lib/offline/bot/bot_difficulty.dart` |
| P1,P2,P3,P4,P5,P6,P7,P10 | `test/offline/bot/*.dart` (various test files) |

**Modified files:**
| Prompt | File | What changes |
|--------|------|-------------|
| P1b | `lib/offline/player_controller.dart` | Add `CardTracker?` param |
| P1b | `lib/offline/human_player_controller.dart` | Accept + ignore tracker |
| P1b, P3, P4, P5, P9 | `lib/offline/bot_player_controller.dart` | GameContext, bidHistory, difficulty |
| P1, P1b | `lib/offline/local_game_controller.dart` | Create tracker, pass to bots, record plays |
| P2 | `lib/offline/bot/hand_evaluator.dart` | Honor values, texture, trump bonus, voids |
| P3 | `lib/offline/bot/bid_strategy.dart` | Score/position/partner/overbid |
| P4 | `lib/offline/bot/trump_strategy.dart` | Min count, bid-level, side suits, ruff |
| P5, P6, P7 | `lib/offline/bot/play_strategy.dart` | Leading, following, Joker (biggest changes) |
| P8 | `lib/shared/constants/timing.dart` | Situation-aware delays |
| P9 | `lib/app/screens/offline_lobby_screen.dart` | Difficulty selector UI |
