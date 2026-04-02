# Bot Intelligence Overhaul — Full Analysis & Plan

## TL;DR

The bot is stateless and makes predictable mistakes. This plan has two tiers: **Tier 1** (4 tactical fixes, ~100 lines, 1 day) delivers 80% of the improvement. **Tier 2** (CardTracker, GameContext, difficulty levels) is the full architectural overhaul for the remaining 20%. Ship Tier 1 first, playtest, then decide if Tier 2 is worth the 2-week investment.

## Current State Summary

The bot has 4 decision modules: `HandEvaluator`, `BidStrategy`, `TrumpStrategy`, `PlayStrategy`. All are stateless — they receive only the current trick's cards and the bot's hand; they have no memory of previous tricks or game score. The result is a bot that plays legally but never strategically.

Zero test coverage for any bot logic. This must be fixed before changes are made, or regressions will be invisible.

---

## Part 1: Problem Inventory by Component

Each problem links to the phase that fixes it.

### 1.1 Hand Evaluator — Broken Value Model [→ Phase 2]

| Problem | Code | What Happens | Fix |
|---------|------|-------------|-----|
| **King in short suit undervalued** | `count >= 3 ? 0.7 : 0.4` | K-x in a suit scores 0.4 despite being beaten only by Ace. Bot passes on scattered-King hands. | Phase 2.1: raise base to 0.6 |
| **Queen almost worthless** | `count >= 4 ? 0.4 : 0.15` | Queen in a 3-card suit = 0.15. Three scattered Queens = 0.45 < one Ace. | Phase 2.1: raise base to 0.3 |
| **Trump honors get zero bonus** | `rank.value < Rank.jack.value` | Only low trump (7-10) gets +0.3 bonus. Trump Ace (0.9) = non-trump Ace (0.9). Should be ~1.4. | Phase 2.2: tiered trump bonus |
| **Void in trump = +0.2** | Void loop iterates all 4 suits | Void in trump is bad (can't ruff, can't control), but scores same as any void. | Phase 2.4: no bonus for trump voids |
| **No suit texture recognition** | Flat per-card scoring | A-K-Q-J same suit and scattered A-7-8-9 score similarly. Sequential honors are far stronger. | Phase 2.3: texture bonus |
| **J and 10 worth same 0.1** | `rank == Rank.jack \|\| rank == Rank.ten` | Jack is meaningfully stronger; survives more tricks. | Phase 2.1: Jack → 0.2 |
| **Partner contribution hardcoded** | "~1.5 tricks baked into thresholds" | The 1.5-trick partner estimate is never adjusted based on actual partner behavior. | Phase 3.3: partner inference |

### 1.2 Bid Strategy — Mechanical and Exploitable [→ Phase 3]

| Problem | What Happens | Fix |
|---------|-------------|-----|
| **Binary threshold bidding** | 4.49 = pass, 4.50 = Bab. No fuzzy zone. | Phase 3.5: fuzzy thresholds |
| **Score-blind** | Bot at 28 points bids same as bot at 0. | Phase 3.1: score-aware bidding |
| **Position-blind** | First bidder after dealer bids same as last. Late position has massive info advantage. | Phase 3.2: position-aware bidding |
| **Opponent bid history ignored** | Opponent bid Six → their hand is strong. Bot doesn't read this signal. | Phase 3.3: bid history inference |
| **Partner pass = meaningless** | Partner passed? Bot still assumes 1.5 trick contribution. | Phase 3.3: partner inference |
| **Forced bid is suicidal** | Forced-bid bot picks trump and plays as if it chose to bid. No desperation mode. | Phase 3.4: forced bid flag → survival mode |
| **Never bluffs** | Strong hand = high bid, always. Predictable. | Phase 3.5: fuzzy thresholds |
| **Kout threshold too conservative** | 7.5+ for Kout. Joker + A-K trump + A-A sides = ~6.0 by current eval, but is clearly Kout. | Phase 2 fixes cascade here |

### 1.3 Trump Strategy — Naive Formula [→ Phase 4]

| Problem | What Happens | Fix |
|---------|-------------|-----|
| **Length dominates** | `count * 2.0 + strength`. Long weak suit can beat short strong suit. | Phase 4.2: bid-level weighting |
| **1-card suit can be trump** | No minimum count check. | Phase 4.1: min 2-card gate |
| **No bid-level interaction** | Bab can tolerate 3-card trump; Kout needs dominant control. Same formula. | Phase 4.2 |
| **Joker bonus arbitrary** | +1.0 if count >= 3. Joker + 4 weak trumps is strong; not captured. | Phase 4.2 |
| **Ignores side suits** | Doesn't consider: "if spades is trump, my hearts A-K still wins." | Phase 4.3 |
| **No ruff value** | Void in non-trump = ruff opportunity. Not factored. | Phase 4.4 |

### 1.4 Play Strategy — The Big One [→ Phases 5, 6, 7]

**Leading [→ Phase 5]:**
- Always leads longest non-trump suit, highest card → gives opponents free tricks when holding trash-heavy long suits
- Never leads Aces first → misses guaranteed trick winners
- Never leads trump to strip opponents → critical for Kout bids
- No partner void exploitation → can't set up partner ruffs
- Kout first-trick always leads highest trump → sometimes low trump flush is better

**Following [→ Phase 6]:**
- "Partner winning" check is position-blind → correct for seat 4, wrong for seat 2/3. No "third hand high" principle.
- Always plays lowest winning card → doesn't evaluate if trick is worth the card
- Trump-in with lowest always → no trump conservation, no trick value assessment
- Dumps purely by rank → doesn't clear voids strategically or preserve honor combos

**Joker [→ Phase 7]:**
- Hardcoded thresholds (`trickNumber >= 5`, `>= 7`) → arbitrary, context-free
- Treats Joker as "dump before poison" → never uses it as a weapon to steal critical tricks
- Panic dumps at trick 7+ even when partner is winning and there's no poison risk
- No check for actual poison risk → doesn't verify whether other hand cards can follow future leads

**Card Memory [→ Phase 1]:**
- `trickPlays` only contains current trick. Previous tricks' cards are gone.
- No tracking of played cards, suit exhaustion, player voids, or trump count.

**Score/Situation Awareness [→ Phases 3, 6]:**
- Same play at 30-0 as 0-30. No defensive vs offensive mode. No bid-progress tracking.

### 1.5 Bot Timing [→ Phase 8]

Uniform 3-5s thinking for everything: 1 legal card, forced bid, obvious Ace lead — all same delay. Humans play obvious moves fast and hard decisions slow.

---

## Part 2: Architecture

### 2.1 New: `CardTracker` (round-scoped state)

A class that persists across all 8 tricks within a round. Reset at round start.

```dart
class CardTracker {
  void recordPlay(int seat, GameCard card);       // called after each confirmed play
  Set<GameCard> get playedCards;                    // all cards played so far
  Set<GameCard> remainingCards(List<GameCard> myHand); // 32 - played - myHand
  Map<int, Set<Suit>> get knownVoids;              // suits each seat has shown void in
  int trumpsRemaining(Suit trump, List<GameCard> myHand); // unaccounted trump count
  bool isHighestRemaining(GameCard card, Suit suit, List<GameCard> myHand);
    // true if card.rank > all remaining ranks in suit (excluding played + myHand)
  Set<Rank> remainingRanksInSuit(Suit suit, List<GameCard> myHand);
  bool isSuitExhausted(Suit suit, List<GameCard> myHand);
    // true if all cards of suit are either played or in myHand
}
```

**Void detection**: one-way — once a player discards off-suit, they're marked void in that suit permanently for the round. This is always correct (you can't regain cards in a suit).

**Lifecycle**: `LocalGameController` creates a new `CardTracker` in `_playTricks()` before the trick loop. Calls `tracker.recordPlay(seat, card)` after each card is confirmed played (after line ~331 in `local_game_controller.dart`). Passes tracker to `BotPlayerController` via updated `decideAction` signature.

**Note**: Phases 2-4 (hand eval, bid, trump) do NOT require CardTracker. Phases 5-7 (leading, following, Joker) DO. This means Phases 2-4 can ship independently before CardTracker is built.

### 2.2 New: `GameContext` passed to all strategies

```dart
class GameContext {
  final Map<Team, int> scores;
  final Map<Team, int> tricksThisRound;
  final BidAmount? currentBid;
  final Team? biddingTeam;
  final Team myTeam;
  final bool isBiddingTeam;
  final bool isForcedBid;            // propagates to trump + play strategy
  final int trickNumber;              // 1-8
  final CardTracker? tracker;         // null for Tier 1, present for Tier 2
  final List<({int seat, String action})> bidHistory;

  factory GameContext.fromClientState(
    ClientGameState state,
    int mySeat,
    CardTracker? tracker, {
    bool isForcedBid = false,
  }) {
    final myTeam = teamForSeat(mySeat);
    Team? bidTeam;
    if (state.bidderUid != null) {
      final bidSeat = state.playerUids.indexOf(state.bidderUid!);
      if (bidSeat >= 0) bidTeam = teamForSeat(bidSeat);
    }
    return GameContext(
      scores: state.scores,
      tricksThisRound: state.tricks,
      currentBid: state.currentBid,
      biddingTeam: bidTeam,
      myTeam: myTeam,
      isBiddingTeam: bidTeam == myTeam,
      isForcedBid: isForcedBid,
      trickNumber: 9 - state.myHand.length,
      tracker: tracker,
      bidHistory: state.bidHistory
          .map((e) => (seat: state.playerUids.indexOf(e.playerUid), action: e.action))
          .toList(),
    );
  }
}
```

### 2.3 `BotDifficulty` — Personality, Not Intelligence

Instead of easy/medium/hard (which conflates intelligence with fun), use personality-based difficulty where all bots play sound moves but differ in risk appetite:

```dart
enum BotDifficulty {
  conservative, // cautious bidding, safe plays, preserves resources
  balanced,     // standard play, score-aware, position-aware
  aggressive,   // overbids, leads trump early, uses Joker as weapon
}
```

All levels use the improved strategies. The difference is threshold tuning, not separate code paths. This avoids maintaining 3 forks and maps better to what players actually want.

### 2.4 Interface Changes

```dart
// Updated PlayerController
abstract class PlayerController {
  Future<GameAction> decideAction(
    ClientGameState state,
    ActionContext context,
    CardTracker? tracker,  // null for human
  );
}
```

`HumanPlayerController` ignores tracker (null). `BotPlayerController` constructs `GameContext` from state + tracker, passes to all strategies.

---

## Part 3: Tier 1 — Ship in 1 Day (~100 lines)

**Goal**: Fix the 4 most visible dumb plays. No new files, no architecture changes. Modify `play_strategy.dart` and `bid_strategy.dart` only.

### T1.1: Ace-first leading

In `_selectLead()`, before the longest-suit logic:

```dart
// Lead Aces first — guaranteed winners unless trumped/Jokered
final aces = legalCards.where((c) => c.rank == Rank.ace).toList();
if (aces.isNotEmpty) {
  // Prefer Ace where we also hold King (cash both)
  for (final ace in aces) {
    if (legalCards.any((c) => c.suit == ace.suit && c.rank == Rank.king)) {
      return ace;
    }
  }
  // Singleton Ace (win + create void)
  final singleton = aces.where((a) =>
    legalCards.where((c) => c.suit == a.suit).length == 1).toList();
  if (singleton.isNotEmpty) return singleton.first;
  // Any Ace
  return aces.first;
}
// ... fall through to existing longest-suit logic
```

### T1.2: Position-aware following

In `_selectFollow()`, replace the flat `partnerWinning` check with position awareness:

```dart
final myPosition = trickPlays.length; // 0=lead, 1=2nd, 2=3rd, 3=4th (last)

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

### T1.3: Simple Joker logic (kill hardcoded thresholds)

Replace the void-in-led-suit section (lines 127–161 in current `_selectFollow`). **Critical**: the `partnerWinning` guard BEFORE the Joker block must be preserved — it handles partner-winning + no Joker (dump low) and partner-winning + poison risk (dump Joker). Without it, the bot would trump over its own partner's winning trick.

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

### T1.4: Score-aware bidding

Add optional `scores` and `myTeam` params to `decideBid()` (no new classes needed):

```dart
static GameAction decideBid(
  List<GameCard> hand,
  BidAmount? currentHighBid, {
  bool isForced = false,
  Map<Team, int>? scores,
  Team? myTeam,
}) {
  final strength = HandEvaluator.evaluate(hand);

  // Score awareness: adjust threshold based on game position
  double thresholdAdjust = 0.0;
  if (scores != null && myTeam != null) {
    final myScore = scores[myTeam] ?? 0;
    final oppScore = scores[myTeam.opponent] ?? 0;

    // Close to winning: bid aggressively (any win ends it)
    if (myScore >= 26) thresholdAdjust -= 0.5;
    // Opponent close to winning: passing = losing slowly
    if (oppScore >= 26) thresholdAdjust -= 0.5;
    // Desperate: opponent about to win and we have nothing
    if (oppScore >= 25 && myScore <= 5) thresholdAdjust -= 0.8;
  }

  final maxBid = _strengthToBid(strength.expectedWinners + thresholdAdjust);
  // ... rest of existing logic unchanged
```

**Caller change** in `BotPlayerController` / `LocalGameController`: pass `state.scores` and `teamForSeat(seatIndex)` when calling `decideBid`.

### T1 Decision Gate

After shipping Tier 1: **play 10 games yourself.** Ask:

- Did the bot make any obviously dumb moves? (Leading 7 over Ace, panic Joker dump, etc.)
- Does the bot feel competent?
- Do you want to invest 2 weeks in Tier 2, or move to online multiplayer?

If the bot feels good enough → move to backend/online priorities from CLAUDE.md.
If still noticeably dumb → proceed to Tier 2.

---

## Part 4: Tier 2 — Full Overhaul (2 weeks)

### Phase 1: Foundation (must do first for Phases 5-7)

**Note**: Phases 2-4 (hand eval, bid, trump) can ship WITHOUT Phase 1. Phase 1 is only a prerequisite for Phases 5-7 (leading/following/Joker with card memory).

#### Step 1.1: `CardTracker` class
Create `lib/offline/bot/card_tracker.dart` (~180 lines). API defined in Part 2.1.

**Wiring in `LocalGameController._playTricks()`:**
```dart
// Before trick loop (after line 232):
final tracker = CardTracker();

// After each confirmed card play (after line 336):
tracker.recordPlay(seat, action.card);

// Pass to bot controller (update all controller calls):
controllers[seat]!.decideAction(clientState, context, tracker);
```

#### Step 1.2: `GameContext` class
Create `lib/offline/bot/game_context.dart`. Factory constructor defined in Part 2.2.

#### Step 1.3: Refactor `BotPlayerController`
Update `PlayerController` interface to accept `CardTracker?`. `BotPlayerController` constructs `GameContext.fromClientState()` and passes to all strategies. `HumanPlayerController` ignores tracker.

#### Step 1.4: Test infrastructure
Create `test/offline/bot/` directory:
- `fixtures.dart` — hand definitions (`allTrash`, `allHonors`, `voidTrump`, `koutHand`, etc.) + `GameContext` mock builder
- `{hand_evaluator,bid_strategy,trump_strategy,play_strategy,card_tracker}_test.dart`

**Acceptance**: all test files compile, fixtures build valid hands, CardTracker passes basic play/void/remaining tests.

---

### Phase 2: Hand Evaluation Fixes [no CardTracker needed]

**Interaction warning**: Phase 2 raises average hand values by ~0.5 expectedWinners. After implementing, re-calibrate Phase 3 bid thresholds. Run 1,000 simulated deals to check bid frequency stays around 50% for borderline hands.

#### Step 2.1: Fix honor valuation
```dart
// Before:
if (rank == Rank.ace) cardScore = 0.9;
else if (rank == Rank.king) cardScore = count >= 3 ? 0.7 : 0.4;
else if (rank == Rank.queen) cardScore = count >= 4 ? 0.4 : 0.15;
else if (rank == Rank.jack || rank == Rank.ten) cardScore = 0.1;

// After:
if (rank == Rank.ace) cardScore = 0.9;
else if (rank == Rank.king) cardScore = count >= 3 ? 0.8 : 0.6;
else if (rank == Rank.queen) cardScore = count >= 3 ? 0.5 : 0.3;
else if (rank == Rank.jack) cardScore = 0.2;
else if (rank == Rank.ten) cardScore = 0.1;
```

**Impact**: Scattered-King hands now score ~1.8 instead of ~1.2, shifting borderline hands into bid territory.

#### Step 2.2: Trump honor bonus
```dart
// Before: bonus only for rank < Jack
if (trumpSuit != null && suit == trumpSuit && rank.value < Rank.jack.value) {
  cardScore += 0.3;
}

// After: tiered bonus for all trump cards
if (trumpSuit != null && suit == trumpSuit) {
  if (rank == Rank.ace) cardScore += 0.5;       // 0.9 + 0.5 = 1.4
  else if (rank == Rank.king) cardScore += 0.4;
  else if (rank == Rank.queen) cardScore += 0.3;
  else if (rank == Rank.jack) cardScore += 0.2;
  else cardScore += 0.3;                         // 7-10 unchanged
}
```

#### Step 2.3: Suit texture scoring
New method `_suitTextureBonus(hand)`:
- A-K same suit: +0.3 (both are near-guaranteed winners together)
- A-K-Q same suit: +0.5 (3 near-guaranteed tricks from one suit)
- K-Q same suit without Ace: +0.2 (Queen protects King from being stranded)

Applied once per suit, added to total score after individual card scoring.

#### Step 2.4 + 2.5: Void and ruffing potential (consolidated)

Single rule replaces both old void bonuses:
```dart
final hasAnyTrump = hand.any((c) =>
    !c.isJoker && trumpSuit != null && c.suit == trumpSuit);

for (final suit in Suit.values) {
  if (!suitCounts.containsKey(suit)) {
    if (suit == trumpSuit) {
      // Void in trump: bad. No bonus.
    } else if (hasAnyTrump) {
      score += 0.3;  // ruffing potential: void + trump to ruff with
    } else {
      score += 0.1;  // void but no trump = minor flexibility
    }
  }
}
```

**Acceptance**: hand_evaluator_test passes: 'King in 2-card suit = 0.6', 'Trump Ace = 1.4', 'A-K-Q same suit gets +0.5 texture', 'void in trump = no bonus'.

---

### Phase 3: Bid Strategy Overhaul [no CardTracker needed]

#### Step 3.1: Score-aware bidding (corrected formula)

The old placeholder formula (`tricksNeededToWin = pointsNeeded / bid.successPoints`) was wrong — it mixed units.

Correct logic: **"Given current scores and a bid level, does winning this bid end the game?"**

```dart
// Tug-of-war scoring: points reduce opponent first, then go to winner.
// At score 28-0, Bab success (+5) → we reach 33 → game over. Bid aggressively.
// At score 0-28, opponent needs any bid to potentially win. We MUST bid to have a chance.

double scoreAdjust(Map<Team, int> scores, Team myTeam) {
  final my = scores[myTeam] ?? 0;
  final opp = scores[myTeam.opponent] ?? 0;

  // Can Bab win the game? (+5 points, applied via tug-of-war)
  // net = my + 5 - opp. If net >= 31, game over.
  if (my + 5 - opp >= 31) return -1.0;  // any bid wins, go for it
  if (my + 5 >= 31) return -0.8;         // Bab alone reaches 31 (opponent at 0)
  if (my >= 26) return -0.5;             // close to winning
  if (opp >= 26) return -0.5;            // opponent close, can't afford to pass
  if (opp >= 25 && my <= 5) return -0.8; // desperate
  return 0.0;
}
```

#### Step 3.2: Position-aware bidding
Adjust threshold based on bidding position (derived from how many players have acted in bidHistory):
- 0 players acted before me: +0.3 (conservative, no info)
- 1 player acted: +0.0
- 2 players acted: -0.2
- 3 players acted (last non-forced): -0.3

#### Step 3.3: Partner inference from bid history
Parse `GameContext.bidHistory` to find partner's action:
```dart
final partnerSeat = (mySeat + 2) % 4;
final partnerEntry = bidHistory.where((e) => e.seat == partnerSeat).lastOrNull;

if (partnerEntry != null && partnerEntry.action != 'pass') {
  threshold -= 0.3; // partner bid (action is "5","6","7","8") → reliable, lower my bar
} else if (partnerEntry?.action == 'pass') {
  threshold += 0.3; // partner passed → weak, raise my bar
}
// If partner hasn't acted yet: no adjustment
```

#### Step 3.4: Forced bid mode
When `isForced == true`:
- Always bid Bab (minimum legal bid above current)
- Set `GameContext.isForcedBid = true`
- Trump strategy → Phase 4.5: pick longest suit (defensive)
- Play strategy → **survival mode**: don't chase tricks aggressively; dump low cards; save Aces/trump for defense; goal is minimize points lost, not make the bid

#### Step 3.5: Fuzzy thresholds (Hard/Aggressive bots only)

For balanced/conservative bots: keep deterministic thresholds (predictable, sound play).
For aggressive bots: use logistic sigmoid:

```dart
double bidProbability(double strength, double threshold) =>
    1.0 / (1.0 + exp(-8.0 * (strength - threshold)));
// At threshold: 50%. At threshold + 0.3: ~90%. At threshold - 0.3: ~10%.

final roll = Random().nextDouble();
if (roll < bidProbability(strength, threshold)) return bid;
```

#### Step 3.6: Tactical overbidding
If opponent bid X and bot's hand supports X+1 with >0.3 margin above threshold: bid X+1 to steal.

**Acceptance**: bid_strategy_test: 'at 28-0 bids with 3.5 expectedWinners', 'at 0-28 bids aggressively', 'partner passed raises threshold', 'position 4 is more aggressive than position 1'.

---

### Phase 4: Trump Strategy Improvements [no CardTracker needed]

#### Step 4.1: Minimum count gate
Never pick a suit with fewer than 2 cards. If all suits have ≤1 card (impossible in 32-card 4-player, but defensive): fall back to highest individual card's suit.

#### Step 4.2: Bid-level aware scoring
```dart
double trumpScore(int count, double strength, BidAmount bid) {
  final lengthWeight = bid.isKout ? 1.5 : 2.0;  // Kout cares less about length
  final strengthWeight = bid.isKout ? 2.0 : 1.0; // Kout cares more about honors
  return count * lengthWeight + strength * strengthWeight;
}
```

#### Step 4.3: Side suit strength consideration
For each candidate trump, add the strength of non-trump, non-Joker Aces/Kings:
```dart
for (final card in hand) {
  if (!card.isJoker && card.suit != candidateTrump) {
    if (card.rank == Rank.ace) sideStrength += 0.9;
    else if (card.rank == Rank.king) sideStrength += 0.5;
  }
}
candidateScore += sideStrength;
```

#### Step 4.4: Ruff value
For each candidate trump, add +0.5 per void non-trump suit (ruffing opportunity).

#### Step 4.5: Forced-bid defensive trump
When `isForcedBid`: pick the longest suit regardless of honor content. Length = control when you can't win.

**Acceptance**: trump_strategy_test: 'Kout prefers A-K-Q over 7-8-9-10', '1-card suit never selected', 'forced bid picks longest'.

---

### Phase 5: Play Strategy — Leading [needs CardTracker for 5.3, 5.6]

#### Step 5.1: Ace-first leading
Already implemented in Tier 1 (T1.1). Tier 2 refines with master card awareness (5.6).

Priority order:
1. Ace-King same suit → lead Ace (set up King)
2. Singleton Ace → lead it (win + create void for ruffing)
3. Ace of longest suit → establish the suit
4. Fallback: lead from longest non-trump suit (current logic, but lead LOW for probing per 5.5)

#### Step 5.2: Trump leads for bidding team
If `context.isBiddingTeam` and bot has 3+ trump in hand: consider leading trump to strip opponents. Especially for Kout bids — strip trump early, then side-suit Aces become unbeatable.

#### Step 5.3: Partner-void leads [requires CardTracker]
If `tracker.knownVoids[partnerSeat]?.contains(suit)` for a NON-TRUMP suit and bot has cards in that suit: lead it. Partner will ruff with trump → free trick. Only works if suit is not trump (can't ruff trump with trump).

#### Step 5.4: Short-suit leads for defense
If defending and holding a singleton in a non-trump suit: lead it. When that suit comes back, bot is void and can ruff.

#### Step 5.5: Low leads for probing
When no Ace, no master card, no tactical lead: lead LOW from longest suit (not highest). Probes cheaply, preserves honors.

#### Step 5.6: Master card awareness [requires CardTracker]
If `tracker.isHighestRemaining(card, suit, hand)` → card is guaranteed winner. Lead it. Example: Ace of hearts was played trick 2, bot's King of hearts is now master.

**Acceptance**: play_strategy_test: 'leads Ace over 10 of longer suit', 'leads trump when bidding Kout with 3+ trump', 'leads low from weak long suit'.

---

### Phase 6: Play Strategy — Following [needs CardTracker for 6.3, 6.4]

#### Step 6.1: Position-aware partner support
Already implemented in Tier 1 (T1.2). Tier 2 refines with position-aware overtrump:
- **Seat 2 (after leader)**: overtrump opponent's trump aggressively (protect from further overtrump)
- **Seat 4 (last)**: see all cards → win cheaply if possible, don't overpay

#### Step 6.2: Strategic dumping
When void and can't win:
- Dump isolated cards (1 card in a suit) → clears void for future ruffing
- Preserve honor combos (A-K, K-Q in same suit)
- If all else equal: dump from longest non-trump suit

#### Step 6.3: Trump conservation [requires CardTracker]
Before ruffing: check `tracker.trumpsRemaining(trumpSuit, hand)`.
- 0-1 trumps remaining outside hand → your trump is dominant, save for critical trick
- 3+ trumps still out → ruff freely

#### Step 6.4: Overtrump evaluation [requires CardTracker]
If opponent already trumped: evaluate trick value before overtrumping.
- Trick contains Ace/King → worth overtrumping
- Trick is all low cards → save trump, dump instead
- Defending and need to block bid → overtrump aggressively regardless

#### Step 6.5: Defensive play awareness
Track `context.tricksThisRound` vs `context.currentBid`:
- If defending and they need 1 more trick: MUST win. Use all resources.
- If defending and they already made bid: dump freely, save for next round.
- If bidding team and bid is made: stop trying, dump to end round.
- If bidding team and behind: escalate — use trump/Joker aggressively.

#### Step 6.6: Forced-bid survival mode
When `context.isForcedBid`:
- Don't chase tricks aggressively
- Dump low cards to minimize trick count
- Save Aces and trump for situations where they can block an opponent trick (not for winning)
- Goal: lose by the smallest margin possible (e.g., lose Bab by 1 trick → only 10 penalty vs losing by 5)

**Acceptance**: play_strategy_test: 'seat 2 plays high when following', 'seat 4 wins cheaply', 'dumps singleton before honor-suit card', 'stops trying after bid is made'.

---

### Phase 7: Joker Overhaul [needs CardTracker for 7.3]

#### Step 7.1: Kill hardcoded thresholds
Already done in Tier 1 (T1.3). Tier 2 refines with CardTracker-aware poison detection.

#### Step 7.2: Joker as strategic weapon
Play Joker when:
- Trick is critical (makes/breaks bid per `context.tricksThisRound`)
- Opponent played high trump and trick is worth stealing
- Team needs exactly 1 more trick → safest win

#### Step 7.3: Joker poison avoidance with CardTracker

Replace the simple "nonJoker.length <= 1" check with actual analysis:

```dart
bool isJokerPoisonRisk(List<GameCard> hand, CardTracker tracker) {
  final nonJoker = hand.where((c) => !c.isJoker).toList();
  if (nonJoker.isEmpty) return true;  // only Joker left → already poisoned
  if (nonJoker.length >= 3) return false;  // safe — 2+ non-Joker cards buffer

  // 1-2 non-Joker cards left: check if they can follow future leads
  // If all non-Joker suits are exhausted (tracker says no remaining cards of that suit),
  // those cards can't be forced out by a lead, so Joker poison is less likely.
  // But if a suit still has outstanding cards, opponents might lead it, forcing our
  // non-Joker card out and stranding the Joker.
  for (final card in nonJoker) {
    if (!tracker.isSuitExhausted(card.suit!, hand)) {
      // This suit is still active — card could be forced out
      return true;  // poison risk: Joker could become last card
    }
  }
  return false;  // all non-Joker suits are exhausted, cards won't be forced
}
```

#### Step 7.4: Joker timing (contextual, not threshold-based)
```dart
double jokerUrgency(GameContext ctx, List<GameCard> hand, List<TrickPlay> plays) {
  double urgency = 0.0;

  // Poison risk (from 7.3)
  if (isJokerPoisonRisk(hand, ctx.tracker!)) urgency += 0.8;

  // Critical trick: team needs exactly 1 more trick
  final myTricks = ctx.tricksThisRound[ctx.myTeam] ?? 0;
  final needed = ctx.isBiddingTeam
    ? (ctx.currentBid?.value ?? 5) - myTricks
    : (9 - (ctx.currentBid?.value ?? 5)) - myTricks; // tricks to break bid
  if (needed == 1) urgency += 0.5;

  // Opponent played trump (Joker beats it)
  final oppTrumped = plays.any((p) => !p.card.isJoker && p.card.suit == ctx.trumpSuit);
  if (oppTrumped) urgency += 0.3;

  // Partner already winning → don't waste
  if (partnerWinning) urgency -= 0.8;

  return urgency; // play if > 0.5
}
```

#### Step 7.5: Endgame Joker planning
If hand has ≤3 cards and one is Joker: check if any future trick will force bot to lead. If bot would lead with Joker as only non-following-suit card → dump Joker now.

**Acceptance**: play_strategy_test: 'Joker not dumped when partner winning at trick 7', 'Joker played when team needs exactly 1 trick', 'Joker dumped when poison risk detected via suit exhaustion'.

---

### Phase 8: Bot Thinking Time

#### Step 8.1: Situation-aware play delays
```dart
int thinkingMs(int legalMoves, int trickNumber, bool isForcedBid) {
  if (legalMoves == 1) return 500 + Random().nextInt(500);
  if (isForcedBid) return 1000 + Random().nextInt(1000);
  if (trickNumber >= 7) return 2000 + Random().nextInt(2000);
  return 1500 + Random().nextInt(2000);
}
```

#### Step 8.2: Bid thinking variance
- Passing: 800 + random(400)ms
- Bidding Bab: 1500 + random(1000)ms
- Bidding Seven/Kout: 2500 + random(1500)ms
- Forced bid: 1000 + random(1000)ms

**Acceptance**: No test needed — verify by feel during playtest.

---

### Phase 9: Difficulty / Personality

All bots use the same improved strategies. Personality controls threshold tuning:

| Personality | Bid Threshold Adjust | Trump Selection | Play Style | Joker |
|-------------|---------------------|-----------------|------------|-------|
| **Conservative** | +0.3 (bids less) | Prefers strong short suits | Preserves trump, dumps early | Holds Joker for defense |
| **Balanced** | 0.0 (standard) | Standard formula | Position-aware, score-aware | Contextual timing |
| **Aggressive** | -0.3 (bids more) | Prefers long suits | Leads trump early, overtrumps often | Uses Joker as weapon |

Implementation: `BotDifficulty` enum passed to `BotPlayerController` constructor. Each strategy reads it from `GameContext` to adjust thresholds.

**UI**: Offline lobby radio buttons: Conservative / Balanced / Aggressive. Default: Balanced.

**Acceptance**: Same hand → conservative bot passes, balanced bot bids Bab, aggressive bot bids Six. All play sound moves.

---

### Phase 10: Testing & Validation

#### Step 10.1: Unit tests per strategy
- `hand_evaluator_test.dart` — honor values, texture bonus, trump bonus, void logic
- `bid_strategy_test.dart` — score awareness, position awareness, forced bid, partner inference
- `trump_strategy_test.dart` — min count, bid-level, side suits, forced bid
- `play_strategy_test.dart` — leading (Ace-first, trump, master), following (position, dump, trump conservation), Joker (poison, weapon, timing)
- `card_tracker_test.dart` — play recording, void detection, remaining cards, master card, suit exhaustion

#### Step 10.2: Integration tests
Full round simulations: 4 bots play a complete round, verify all plays are legal, scoring is correct, and CardTracker stays in sync with actual game state.

#### Step 10.3: Bot-vs-bot validation
Run 1,000 simulated games (not 10,000 — start smaller, scale if needed):
- Aggressive vs Conservative: Aggressive wins 55-65% (95% CI)
- Balanced vs Conservative: Balanced wins 52-60%

**Also**: play 10 games yourself against each personality. Success criteria:
- Zero obviously dumb moves (leading trash over Ace, panic Joker dump, passing at 28 points)
- You can win ~50% of games with good play
- Losing to the bot feels fair, not random

#### Step 10.4: Specific regression scenarios
- Joker + A-K trump + A-A-A side suits → should bid Kout
- All 7s and 8s → should pass
- Defending at trick 7, opponent needs 1 more trick → bot must play to win THIS trick
- Joker + one non-Joker card, non-Joker suit still active → poison risk, dump Joker
- Joker + one non-Joker card, non-Joker suit exhausted → NO poison risk, hold Joker
- Forced bid → survival mode plays (minimize loss, not chase tricks)

---

## Execution Order

**Tier 1 (Day 1):**

| Step | Change | Lines | Impact |
|------|--------|-------|--------|
| T1.1 | Ace-first leading | ~20 | Stops leading trash |
| T1.2 | Position-aware following | ~30 | Stops dumping when shouldn't |
| T1.3 | Simple Joker logic | ~25 | Kills the most visible dumb plays |
| T1.4 | Score-aware bidding | ~15 | Endgame becomes rational |

**→ Decision Gate: playtest 10 games. Continue to Tier 2?**

**Tier 2 (2 weeks):**

| Priority | Phase | Effort | Impact | CardTracker? |
|----------|-------|--------|--------|-------------|
| 1 | Phase 2: Hand eval fixes | 2-3h | Fixes cascading bid/trump errors | No |
| 2 | Phase 3: Bid strategy | 3-4h | Score/position/partner awareness | No |
| 3 | Phase 4: Trump strategy | 2-3h | Bid-level, side suits, ruff value | No |
| 4 | Phase 1: Foundation (CardTracker, GameContext) | 4-6h | Unlocks Phases 5-7 | Yes (creates it) |
| 5 | Phase 5: Leading improvements | 3-4h | Master cards, partner voids, trump strip | Yes |
| 6 | Phase 6: Following improvements | 4-5h | Trump conservation, overtrump, defense | Yes |
| 7 | Phase 7: Joker overhaul | 3-4h | Poison detection, strategic timing | Yes |
| 8 | Phase 8: Thinking time | 1h | Polish — removes bot tells | No |
| 9 | Phase 9: Personality system | 3-4h | Replayability | No |
| 10 | Phase 10: Testing | Ongoing | Confidence in every change | Both |

**Key dependency**: Phases 2-4 and 8-9 can ship without CardTracker. Phase 1 (CardTracker) only blocks Phases 5-7. This means you can parallelize: do Phases 2-4 while building Phase 1, then do Phases 5-7.

**Total Tier 2 estimate**: ~30-40 hours.

---

## Files Touched

**New files:**
- `lib/offline/bot/card_tracker.dart`
- `lib/offline/bot/game_context.dart`
- `test/offline/bot/fixtures.dart`
- `test/offline/bot/hand_evaluator_test.dart`
- `test/offline/bot/bid_strategy_test.dart`
- `test/offline/bot/trump_strategy_test.dart`
- `test/offline/bot/play_strategy_test.dart`
- `test/offline/bot/card_tracker_test.dart`

**Modified files:**
- `lib/offline/bot/hand_evaluator.dart` — honor values, texture, trump bonus, void logic
- `lib/offline/bot/bid_strategy.dart` — score/position/partner/forced awareness
- `lib/offline/bot/trump_strategy.dart` — bid-level, side-suit, ruff value, min count
- `lib/offline/bot/play_strategy.dart` — biggest rewrite: leading, following, Joker
- `lib/offline/bot_player_controller.dart` — holds CardTracker ref, builds GameContext
- `lib/offline/local_game_controller.dart` — creates tracker, feeds plays, passes to bots
- `lib/offline/player_controller.dart` — updated interface (CardTracker? parameter)
- `lib/shared/constants/timing.dart` — situation-aware bot thinking times
