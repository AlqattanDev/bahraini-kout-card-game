# Online Bot Parity — TypeScript Workers vs Dart

## Objective

Bring the TypeScript Workers bot implementation (`workers/src/game/bot/`) and game-room orchestration (`workers/src/game/game-room.ts`) into full functional parity with the Dart offline implementation (`lib/offline/bot/`). Covers 1 critical bug, 5 high-priority bot rewrites, and 4 medium/low flow gaps — 12 items total across ~850 LOC of changes.

---

## Implementation Plan

### Phase 1 — Critical Bug Fix

- [x] **1. Fix poison joker lead-only guard** (`workers/src/game/game-room.ts:583-587`)
  Compute `isLeadPlay` (whether `game.currentTrick.plays.length === 0`) **before** the `detectPoisonJoker` call and add `isLeadPlay &&` as a guard on the condition. The variable is currently computed on line 591, *after* the check. Move it up by ~5 lines. Without this fix, a player whose last card is the Joker while *following* incorrectly triggers a poison-joker resolution instead of a legal follow play.

---

### Phase 2 — CardTracker Void Inference (prerequisite for Phase 3)

- [x] **2. Add seat-aware recording to `CardTracker`** (`workers/src/game/bot/card-tracker.ts`)
  Change `recordPlay(card: string)` to `recordPlay(seat: number, card: string)`. Update `recordTrick(plays)` to pass `play.seat` (already present in `TrickPlay`) into each `recordPlay` call. This is required so void inference can be keyed by seat.

- [x] **3. Wire void inference in `buildTracker`** (`workers/src/game/bot/index.ts:28-37`)
  After rebuilding the tracker from `roundHistory` and `currentTrick` plays, iterate each completed trick and call `tracker.inferVoid(seat, ledSuit)` for every player who did not follow the led suit. The led suit is `currentTrick.plays[0]`'s card suit per trick. This populates `_knownVoids` so play strategy can use it.

---

### Phase 3 — Bot Strategy Rewrites

#### 3a. Hand Evaluator

- [ ] **4. Rewrite `evaluateHand` to match Dart's probability model** (`workers/src/game/bot/hand-evaluator.ts`)
  Replace the current flat-score model with Dart's two-layer approach:
  - Base probability per rank: A=0.85, K=0.65, Q=0.35, J=0.15, all others=0.05. Joker=1.0.
  - Trump bonus (applied only to the suit chosen as trump candidate): A=+0.15, K/Q/J=+0.25, all others=+0.30.
  - Trump bonus selection: evaluate each suit's raw score first, pick the strongest, then apply trump bonus to that suit only — not to whichever suit is passed in.
  - Void bonus: +1.0 (if hand has any trump card) or +0.1 (no trump). Previously +0.3/+0.1.
  - Long suit bonus: +0.1 per card beyond 3 (e.g. 5-card suit = +0.2). Previously flat +0.3.
  - Suit texture bonuses (AKQ/AK/KQ) remain the same.

- [ ] **5. Change `evaluateHand` return type to `HandStrength`** (`workers/src/game/bot/hand-evaluator.ts`, `workers/src/game/bot/types.ts`)
  Define a `HandStrength` interface with fields `personalTricks: number` and `strongestSuit: SuitName`. Return this object instead of a bare number. Update all callers (`bid-strategy.ts`, `trump-strategy.ts`) to access `.personalTricks` and `.strongestSuit` respectively.

- [ ] **6. Implement `effectiveTricks` partner estimate** (`workers/src/game/bot/hand-evaluator.ts`)
  Add a function `effectiveTricks(personalTricks, bidHistory, mySeat)` that adds a partner contribution to `personalTricks`:
  - Partner has bid → +1.5
  - Partner has passed → +0.5
  - Partner has not acted yet → +1.0 (default)
  Export this function for use by `bid-strategy.ts`.

#### 3b. Bid Strategy

- [ ] **7. Rewrite thresholds and gates in `decideBid`** (`workers/src/game/bot/bid-strategy.ts`)
  Replace the 4.5/5.5/6.5/7.5 thresholds with 5.0/6.0/7.0/8.0 matching Dart's `bid_strategy.dart`. These thresholds operate on `effectiveTricks` (from task 6), not raw hand strength.

- [ ] **8. Add shape floor** (`workers/src/game/bot/bid-strategy.ts`)
  Implement `_shapeFloor(hand)` — minimum bid level derived purely from suit length:
  - 5-card suit → bid at least 5 (Bab)
  - 6-card suit → bid at least 6
  - 7-card suit → bid at least 7
  - 7-card suit + Joker → bid at least 8 (Kout)
  The final bid is `max(strengthBid, shapeFloor)`.

- [ ] **9. Add Seven gate and Kout gate** (`workers/src/game/bot/bid-strategy.ts`)
  Before allowing a bid of 7 or 8, enforce structural gates matching Dart:
  - **Seven gate**: hand must have a 6+ card suit, OR (Joker + 5-card suit + AK), OR (3 Aces + Joker). If gate fails, cap at 6.
  - **Kout gate**: hand must have a 7+ card suit, OR (Joker + 6-card suit + AKQ), OR (Joker + 5-card suit + 3 Aces), OR `effectiveTricks >= 7.6`. If gate fails, cap at 7.

- [ ] **10. Add partner rule** (`workers/src/game/bot/bid-strategy.ts`)
  If the bot's partner has already bid, do not outbid the partner unless the computed bid is 8 (Kout). This prevents partners from driving each other's bids up and matches Dart's rule exactly.

- [ ] **11. Fix desperation offset** (`workers/src/game/bot/bid-strategy.ts`)
  Replace the current multi-condition score adjustments with Dart's single rule: add +1.0 to `effectiveTricks` when `opponentScore >= targetScore - 10` (i.e. ≥21). Remove the current `+0.8 if myScore+5 >= 31` and `+1.0 if opponent ≥25 and myScore ≤5` conditions — they produce different and more erratic behavior.

- [ ] **12. Fix forced bid handling** (`workers/src/game/bot/bid-strategy.ts`)
  When `isForced` is true, the bot must bid. Current code falls back to `5` regardless of existing bids. Instead: compute the ceiling bid from `effectiveTricks` and bid `max(ceilingBid, currentHighBid + 1)`, where `currentHighBid` is the highest bid already placed by any player. This matches Dart's forced path.

#### 3c. Trump Strategy

- [ ] **13. Fix length and strength weights** (`workers/src/game/bot/trump-strategy.ts:39-40`)
  Change `lengthWeight` from `2.0` to `2.5` and `strengthWeight` from `1.0` to `0.45`. These match `BotSettings.trumpLengthWeight` and `BotSettings.trumpStrengthWeight` in Dart and reflect the design intent that suit length is the dominant factor in trump selection.

- [ ] **14. Add honor tiebreaker** (`workers/src/game/bot/trump-strategy.ts`)
  When two suits are within an epsilon of 0.5 in score, break the tie by: (1) highest honor count (A=3, K=2), then (2) suit length. Currently the first-found suit wins ties, which means suits earlier in enumeration order always win.

- [ ] **15. Add Kout weight override** (`workers/src/game/bot/trump-strategy.ts`)
  When `ctx.currentBid?.amount === 8` (Kout), change weights to `length=1.5, strength=2.0`. For Kout, top honors matter more than length since the bidder needs 8 tricks; this is the inverse of normal bidding.

- [ ] **16. Remove the forced bid early-exit shortcut** (`workers/src/game/bot/trump-strategy.ts`)
  The `if (isForcedBid) return longestSuit` early exit on line ~12 does not exist in Dart's current `trump_strategy.dart` (it was removed). Delete this branch; the full scoring algorithm applies regardless of forced status.

#### 3d. Play Strategy — GameContext Signals

- [ ] **17. Define `GameContext` signals in `BotContext`** (`workers/src/game/bot/types.ts`)
  Add five computed fields to `BotContext`:
  - `roundControlUrgency: number` — `tricksNeeded / tricksRemaining`, clamped to `[0.0, 1.0]`
  - `partnerLikelyWinningTrick: boolean` — true if partner played the current highest card in the current trick
  - `partnerNeedsProtection: boolean` — true if partner is currently winning but opponents can still trump
  - `opponentLikelyVoidInLedSuit: boolean` — from `tracker.knownVoids`, either known opponent seat is void in led suit
  - `partnerLikelyVoidInLedSuit: boolean` — from `tracker.knownVoids`, partner seat is void in led suit

- [ ] **18. Populate `GameContext` signals in `buildBotContext`** (`workers/src/game/bot/index.ts`)
  Compute the five fields above using the tracker (now populated with void inference from task 3) and the current trick state. `tricksNeeded` = bid amount − tricks already won by bidding team; `tricksRemaining` = `TRICKS_PER_ROUND − trickWinners.length`.

#### 3e. Play Strategy — Position-Aware Following

- [ ] **19. Add position detection to follow logic** (`workers/src/game/bot/play-strategy.ts`)
  Compute `myPosition = currentTrick.plays.length` (0-indexed position in trick: 0=lead, 1=2nd, 2=3rd, 3=4th). Pass this into `selectFollow`. When following suit with a winning card:
  - 4th position (last to play): play **lowest** winner (trick is won regardless)
  - 2nd/3rd position: play **highest** winner (need to beat future plays)

- [ ] **20. Add trick countdown Joker play to lead logic** (`workers/src/game/bot/play-strategy.ts`)
  In `selectLead`, before the trump-strip check: if `tricksRemaining <= 2` and `roundControlUrgency > 0.7` and the bot holds the Joker, lead the Joker. This ensures the Joker is played before being stranded as a forced lead (which would trigger poison joker). Mirrors Dart's trick-countdown branch in `play_strategy.dart`.

- [ ] **21. Add partner void detection to lead logic** (`workers/src/game/bot/play-strategy.ts`)
  In `selectLead`, when selecting a suit to lead: if `partnerLikelyVoidInLedSuit` is true for the candidate suit, prefer a different suit to lead into. This avoids giving opponent a chance to discard while partner can't ruff.

- [ ] **22. Add partner trump guarantee to follow logic** (`workers/src/game/bot/play-strategy.ts`)
  In `selectFollow` when void (discarding/ruffing): before choosing to dump rather than trump, check if partner is currently winning the trick AND `!opponentLikelyVoidInLedSuit`. If both true, it is safe to dump — opponents are also following, so no trump threat. Otherwise, consider trumping even if partner is ahead.

---

### Phase 4 — Flow Gaps

- [ ] **23. Propagate forced bid flag through game state** (`workers/src/game/types.ts`, `workers/src/game/game-room.ts`, `workers/src/game/bot/index.ts`)
  Add `forcedBidSeat: number | null` to `GameDocument`. In `handleBotTurn`, when the forced bid path is taken (the `isLastBidder` check at line 764), persist `forcedBidSeat = mySeat` to the game document before calling `BotEngine.bid`. In `buildBotContext`, set `isForced: game.forcedBidSeat === mySeat` instead of hardcoding `false`.

- [ ] **24. Add `BID_ANNOUNCEMENT` phase** (`workers/src/game/types.ts`, `workers/src/game/game-room.ts`)
  The `GamePhase` union already contains `'TRUMP_SELECTION'`; insert `'BID_ANNOUNCEMENT'` between `'TRUMP_SELECTION'` and `'PLAYING'` in the union type. In `handleSelectTrump`, after persisting trump suit, set `phase = 'BID_ANNOUNCEMENT'`, broadcast it, then schedule an alarm (2–3 seconds) that transitions to `'PLAYING'` and sets `currentPlayer` and `currentTrick`. This gives the client a window to display the bid/trump overlay before play starts.

- [ ] **25. Add hand size validation after dealing** (`workers/src/game/game-room.ts`)
  In `initGame` and `startNextRound`, after distributing cards into `hands`, add an assertion loop: for each player, throw (or log + forfeit) if `hands[uid].length !== 8`. This catches deck/shuffle bugs before they corrupt a round silently.

- [ ] **26. Add `roundIndex` to `GameDocument`** (`workers/src/game/types.ts`, `workers/src/game/game-room.ts`)
  Add `roundIndex: number` (default `0`) to `GameDocument`. Increment in `startNextRound`. Broadcast the value in game state messages. This allows the client to display "Round N" and helps debug game logs.

---

## Verification Criteria

- A player with a lone Joker as their last card who is *following* (not leading a trick) completes the play normally — no poison joker resolution fires.
- Bot bidding: in a test hand where one bot holds 4 spades + AK of hearts + Joker, the bot does not bid 8 (Kout gate blocks it unless `effectiveTricks >= 7.6`).
- Bot bidding: a bot never outbids its partner's bid unless its own computed bid is 8 (Kout).
- Bot trump selection: for two suits with equal length, the suit with higher honors wins; for borderline hands, length-dominant suit is selected over strength-dominant suit (weight ratio 2.5 : 0.45).
- Bot play: in the 4th position of a trick already won by a teammate, the bot plays its **lowest** winning card rather than highest.
- Bot play: when ≤2 tricks remain and `roundControlUrgency > 0.7`, the bot leads the Joker rather than holding it.
- `CardTracker.knownVoids` is non-empty after a trick where any player discards off-suit.
- `isForced: true` is present in the bot context when the last-to-bid bot is forced.
- Game state broadcasts a `BID_ANNOUNCEMENT` phase between trump selection and the first play.
- `game.roundIndex` increments correctly across rounds.
- `game.forcedBidSeat` is `null` outside the bidding phase and set correctly during forced-bid bot turns.

---

## Potential Risks and Mitigations

1. **`HandStrength` type change breaks callers**
   Mitigation: Tasks 4 and 5 are a single atomic change — update the return type and all callers (`bid-strategy.ts`, `trump-strategy.ts`) in the same commit. No other files reference `evaluateHand` directly.

2. **Void inference correctness depends on trick reconstruction order**
   Mitigation: In `buildTracker`, process `roundHistory` tricks in order, then the `currentTrick` plays in order. The led suit is always `plays[0]`'s card suit. Verify with a unit test: play a 4-player trick where seat 2 plays a different suit, confirm `tracker.knownVoids` contains `(seat=2, ledSuit)`.

3. **`BID_ANNOUNCEMENT` alarm conflicts with existing alarm logic**
   Mitigation: The Durable Object uses a single alarm slot. The existing alarm handler (`alarm()`) dispatches on `phase`. Add a `BID_ANNOUNCEMENT` case that transitions to `PLAYING` and reschedules bot turn. Do not nest alarms — always clear and reset.

4. **Removing forced-bid trump shortcut changes bot behavior in edge cases**
   Mitigation: Task 16 only removes the early-exit shortcut. The full algorithm already handles forced bids correctly (it will select the longest/strongest suit). Test with a hand where the forced bot has no 2-card suits — the fallback to "all suits as candidates" should still produce a valid selection.

5. **`GameContext` signal computation adds latency to `buildBotContext`**
   Mitigation: All five signals are O(n) over the current trick (≤4 plays) and `knownVoids` map (≤4×4 entries). No material latency impact in a Durable Object context.

---

## Alternative Approaches

1. **Incremental threshold migration instead of full bid strategy rewrite**: Raise thresholds from 4.5/5.5/6.5/7.5 to 5.0/6.0/7.0/8.0 and add the partner rule first, deferring shape floor and gates to a follow-up. Faster to ship but leaves the bot over-bidding on shape hands until gates are added.

2. **Skip `BID_ANNOUNCEMENT` phase, use client-side timer instead**: The client already receives `trumpSuit` in the `TRUMP_SELECTION` → `PLAYING` transition. A client timer (no server change) could show the overlay before enabling play input. This avoids server-side alarm complexity but means the bot can play before the human has seen the announcement.

3. **Port Dart `GameContext` as a standalone module** instead of embedding signals in `BotContext`: Creates `workers/src/game/bot/game-context.ts` mirroring `lib/offline/bot/game_context.dart` exactly, then pass it as a separate arg to `decidePlay`. Cleaner separation but requires updating the `BotEngine` API signature and all callers.
