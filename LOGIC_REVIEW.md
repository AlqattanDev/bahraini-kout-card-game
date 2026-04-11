# Koutbh Logic Review — Current State

Extracted from codebase on 2026-04-09. Reflects all recent changes.

---

## 1. CONSTANTS & DOMAIN RULES

### 1.1 Game Constants (Dart + TS)

| Constant | Value | Notes |
|---|---|---|
| Target score | 31 | Tug-of-war, first to 31 wins |
| Tricks per round | 8 | 32 cards / 4 players |
| Player count | 4 | 6-player not implemented |

**Removed**: `poisonJokerPenalty` constant no longer exists in Dart. Poison joker now uses `applyKout` (instant game loss, score set to 31).

**TS still has** `POISON_JOKER_PENALTY = 10` removed from `types.ts` — confirmed removed.

### 1.2 Deck Composition

- **Spades**: A, K, Q, J, 10, 9, 8, 7 (8 cards)
- **Hearts**: A, K, Q, J, 10, 9, 8, 7 (8 cards)
- **Clubs**: A, K, Q, J, 10, 9, 8, 7 (8 cards)
- **Diamonds**: A, K, Q, J, 10, 9, 8 (7 cards — no 7 of diamonds)
- **Joker**: 1 card
- **Total**: 32 cards, 8 per player

### 1.3 Rank Values

| Rank | Value |
|---|---|
| Ace | 14 |
| King | 13 |
| Queen | 12 |
| Jack | 11 |
| Ten | 10 |
| Nine | 9 |
| Eight | 8 |
| Seven | 7 |

### 1.4 Card Encoding

Format: `{suit initial}{rank}`. Joker = `JO`.

S = Spades, H = Hearts, C = Clubs, D = Diamonds. Examples: `SA` = Ace of Spades, `D10` = 10 of Diamonds.

---

## 2. TEAMS & SEATING

- **Team A**: Seats 0, 2 (partners across)
- **Team B**: Seats 1, 3 (partners across)
- Rule: `seatIndex.isEven ? Team.a : Team.b`
- **CCW order**: `nextSeat(i) = (i - 1 + 4) % 4` → 0 → 3 → 2 → 1 → 0
- **Partner**: `partnerSeat = (mySeat + 2) % 4`

---

## 3. DEALER ROTATION

- First round: random dealer (0–3).
- After each round: losing team deals.
  - Current dealer already on losing team → stays.
  - Current dealer on winning team → rotate one CCW to land on losing team.
  - Tied scores → dealer stays.

---

## 4. BIDDING

### 4.1 Bid Amounts

| Bid | Tricks Needed | Success Points | Failure Points |
|---|---|---|---|
| Bab | 5 | +5 | +10 |
| Six | 6 | +6 | +12 |
| Seven | 7 | +7 | +14 |
| Kout | 8 | Score → 31 (instant win) | +16 |

### 4.2 Bidding Flow

1. Start: seat after dealer, going CCW.
2. Single orbit: each player bids or passes exactly once.
3. Must exceed: new bid must be strictly higher than current highest.
4. Pass = permanent: once you pass, you're out.
5. Kout = immediate end: bidding stops instantly.
6. Forced bid: if 3 pass with no bid, last player MUST bid — can choose ANY level (not forced to Bab). If someone already bid, last player CAN pass.
7. No reshuffle.

### 4.3 Bid Validation

```
validateBid:
  - already passed? → invalid
  - bid ≤ current highest? → invalid
  - else → valid

validatePass:
  - already passed? → invalid
  - last bidder AND no current bid? → must-bid error
  - else → valid

isLastBidder:
  - not passed AND only 1 active player remaining

checkBiddingComplete:
  - 3+ passed AND bid exists AND bidder exists → won
  - else → ongoing
```

Dart uses seat indices, TS uses string player IDs. Functionally identical.

---

## 5. TRUMP SELECTION

Winning bidder picks any of the 4 suits. No validation constraints.

Trump timeout auto-pick is planned (not yet implemented in code): auto-select best suit by count + rank strength, with countdown timer.

---

## 6. PLAY VALIDATION

### 6.1 Rules

1. Card must be in hand.
2. **Joker cannot be led** — returns `joker-cannot-lead` error. This is the fundamental rule.
3. **Kout first trick lead**: If Kout AND first trick AND leading → must play trump if you have it. (Since Joker can't lead, this only applies to suited cards.)
4. **Must follow suit**: If not leading and you have cards of the led suit, you must play one. Joker is exempt (playable anytime when following).

### 6.2 Poison Joker

`detectPoisonJoker`: `hand.length == 1 && hand.first.isJoker`

Triggers **only when the player must lead** (checked in controller: `isLead && detectPoisonJoker(hand)`). When following, Joker is a normal legal play.

Result: **instant game loss** — opponent score set to 31 via `Scorer.applyPoisonJoker()` which calls `applyKout()`.

### 6.3 Removed

- `detectJokerLead` — removed entirely. Joker cannot be led, so no separate detection needed.

### 6.4 Playable Cards Helper

`playableForCurrentTrick()` returns the set of legally playable cards. When leading, Joker is excluded by the validator. If only Joker remains, returns empty set — caller checks `detectPoisonJoker`.

---

## 7. TRICK RESOLUTION

### 7.1 Winner Priority

1. **Joker always wins** (only appears when following).
2. **Highest trump** — if any trump was played.
3. **Highest of led suit**.

### 7.2 `beats(a, b)` (Dart only)

Joker > trump > same-suit rank > led-suit over off-suit.

### 7.3 Led Suit

First card determines led suit. Since Joker can't lead, led suit is always defined.

Note: `Trick.ledSuit` getter still returns null if first card is Joker (legacy code path). In practice this never happens since Joker can't lead.

---

## 8. SCORING

### 8.1 Round Result

```
if biddingTeamTricks >= bidValue:
  winner = biddingTeam, points = successPoints
else:
  winner = opponent, points = failurePoints
```

### 8.2 Tug-of-War

```
applyScore(scores, winningTeam, points):
  net = winnerScore + points - loserScore
  if net >= 0: winner = net, loser = 0
  if net < 0:  winner = 0, loser = -net
```

Invariant: only one team ever has non-zero score.

### 8.3 Kout Scoring

- Success: `applyKout(winningTeam)` → score set to 31, opponent to 0.
- Failure: regular `applyScore` with 16 points. NOT instant loss.

### 8.4 Poison Joker Scoring

```dart
Scorer.calculatePoisonJokerResult(jokerHolderTeam):
  winner = jokerHolderTeam.opponent
  pointsAwarded = 0  // unused, applyPoisonJoker handles it

Scorer.applyPoisonJoker(jokerHolderTeam):
  return applyKout(winningTeam: jokerHolderTeam.opponent)
  // → opponent score = 31, joker holder = 0
```

Instant game loss. Same mechanism as Kout success (for the other team).

**TS parity**: `scorer.ts` has matching `calculatePoisonJokerResult` and `applyPoisonJoker` functions. Points field is 0, actual scoring done via `applyKout`.

### 8.5 Game Over

Any team reaching `>= 31` wins.

### 8.6 Early Round Termination

```
isRoundDecided:
  bidderTricks >= bidValue
  OR opponentTricks > 8 - bidValue
```

---

## 9. GAME CONTROLLER FLOW (Offline)

### 9.1 Round Structure

1. Deal (shuffle, 8 cards each)
2. Bidding (single CCW orbit)
3. Trump Selection (bidder picks)
4. Bid Announcement (UI pause)
5. Play 8 Tricks
6. Round Scoring
7. Check game over → new round with updated dealer

### 9.2 Trick Play Flow

- First trick leader: seat after bidder (CCW).
- Subsequent: previous trick winner leads.
- Each trick: 4 cards CCW from leader.
- Poison joker check: **only when leading** (`isLead && detectPoisonJoker`).
- After each play: card tracked, void inferred if off-suit.
- Early termination after each trick.

### 9.3 Controller Scoring Path

```dart
if (poisonJoker):
  scores = Scorer.applyPoisonJoker(jokerHolderTeam)  // instant loss → 31
else if (bid.isKout && winner == bidderTeam):
  scores = Scorer.applyKout(winningTeam)  // instant win → 31
else:
  scores = Scorer.applyScore(scores, winningTeam, points)  // tug-of-war
```

### 9.4 Forced Bid Tracking

`_bidWasForced` tracks if winning bid was forced. Passed to `TrumpContext.isForcedBid` and `PlayContext.isForced`.

---

## 10. BOT STRATEGY (Dart — Offline)

### 10.1 Bot Settings

```
trumpLengthWeight = 2.5
trumpStrengthWeight = 0.45
partnerEstimateDefault = 1.0  (unknown partner)
partnerEstimateBid = 1.5      (partner bid)
partnerEstimatePass = 0.5     (partner passed)
desperationThreshold = 1.0    (lower thresholds when losing)
```

No difficulty tiers. No bot personas (removed).

### 10.2 Hand Evaluator

Returns `HandStrength { personalTricks: 0.0–8.0, strongestSuit }`.

**Step 1**: Find strongest suit by raw trick potential (sum of base probs).

**Per-card base probability (no trump):**

| Rank | Base Prob |
|---|---|
| Ace | 0.85 |
| King | 0.65 |
| Queen | 0.35 |
| Jack | 0.15 |
| 10 and below | 0.05 |
| Joker | 1.0 (flat) |

**Step 2**: Score each card: base + trump bonus if in strongest suit.

**Trump bonus (for strongest suit only):**

| Rank | Bonus |
|---|---|
| Ace | +0.15 |
| King | +0.25 |
| Queen | +0.25 |
| Jack | +0.25 |
| 10 and below | +0.30 |

**Step 3**: Suit texture bonuses:
- AKQ: +0.5
- AK: +0.3
- KQ (no A): +0.2

**Step 4**: Long suit bonus: +0.1 per card beyond 3 (for suits with 4+).

**Step 5**: Void bonuses:
- Void in non-trump with trump in hand: +1.0 (ruffing)
- Void in non-trump without trump: +0.1
- Void in own trump: no bonus

**Effective tricks** = personalTricks + partner estimate:
- Partner unknown: +1.0
- Partner bid: +1.5
- Partner passed: +0.5

### 10.3 Bid Strategy

**Thresholds (effectiveTricks needed):**

| Bid | Threshold |
|---|---|
| Bab (5) | 5.0 |
| Six | 6.0 |
| Seven | 7.0 |
| Kout (8) | 8.0 |

**Desperation offset**: +1.0 if opponent score >= 21 (targetScore - 10).

**Shape floor** (minimum bid from hand shape):

| Shape | Floor |
|---|---|
| 7+ in suit + Joker | Kout |
| 7+ in suit | Seven |
| 6 in suit + Joker + AKQ | Kout |
| 6 in suit + Joker | Seven |
| 6 in suit | Six |
| 5 in suit + Joker | Six |
| 5 in suit | Bab |

Ceiling = max(thresholdBid, shapeFloor), then gated.

**Seven gate** (must pass one):
- 6+ cards in any suit
- Joker + 5+ cards in suit with A-K
- 3+ Aces + Joker

**Kout gate** (must pass one):
- Longest suit >= 7
- Joker + 6+ cards + AKQ block
- Joker + 5+ cards + 3 Aces
- effectiveTricks >= 7.6

**Partner rule**: Never outbid partner unless going Kout.

**Opponent contest**: If opponent placed high bid, only outbid if effectiveTricks (+ desperation) >= new level.

**Forced bid**: Bot picks best bid up to ceiling. If must outbid, tries nextAbove. Forced player can choose any level.

### 10.4 Trump Strategy

**Candidate scoring:**
```
score = count * lengthWeight + strength * strengthWeight
```

Weights from BotSettings: `lengthWeight = 2.5`, `strengthWeight = 0.45` (non-Kout).
Kout: `lengthWeight = 1.5`, `strengthWeight = 2.0`.

**Confirmed**: BotSettings weights ARE wired up — `TrumpStrategy.selectTrump` defaults to `BotSettings.trumpLengthWeight` / `BotSettings.trumpStrengthWeight` when no explicit weights passed.

**Per-rank trump strength weights:**

| Rank | Weight |
|---|---|
| Ace | 3.0 |
| King | 2.0 |
| Queen | 1.5 |
| Jack | 1.0 |
| Others | 0.5 |

**Bonuses:**
- Joker + 3+ cards in suit: +1.0
- Void in other suits: +0.5 each
- Side-suit honors: Ace = +0.9, King = +0.5

**Filters:**
- Prefer suits with >= 2 cards. If none, consider all.
- `isForcedBid` param removed from TrumpStrategy — no longer used.

**Tiebreak (within 0.5 score):**
- Higher AK honor count → then longer suit.

### 10.5 Play Strategy — Leading

Priority order:
1. **Master cards** (highest remaining via tracker): non-trump masters first, highest rank.
2. **Non-trump Aces**: prefer Ace with King in same suit, then any Ace.
3. **Singleton voids**: singleton non-trump card when you have trump (creates void for ruffing).
4. **Trump strip** (bidding team only): 3+ trumps → lead highest trump.
5. **Partner void exploit**: lead into suit partner is void in.
6. **Longest non-trump suit**, lowest card.
7. **Fallback**: highest non-Joker.

Bot never leads Joker (validator prevents it; strategy double-checks).

### 10.6 Play Strategy — Following

**Pre-checks (before suit analysis):**
- **Trick countdown**: If <= 2 tricks remaining and have Joker → play Joker now (avoid poison later).
- **Poison prevention**: If hand <= 2 cards and one is Joker → play Joker immediately.

**Following suit (have cards in led suit):**
- Partner winning + last to play → lowest.
- Partner winning + opponent still to play → lowest.
- Opponent winning + can beat:
  - Last to play → lowest winner (conserve).
  - Not last → highest winner (guarantee).
- Can't beat with suit + last to play + have Joker → play Joker.
- Can't beat → lowest suit card.

**Void in led suit:**
- Partner winning + last to play → dump.
- Partner winning + opponent to play:
  - Have trump + tracker says no outstanding trumps → lowest trump (guarantee).
  - Have trump + highest trump beats all remaining trumps → play it.
  - Otherwise → dump.
- Opponent winning + winning trump available → lowest winning trump.
- Opponent winning + trump but can't beat → lowest trump (still better than nothing).
- No trump can win + have Joker + no non-Joker can win → Joker.
- Nothing wins → dump.

### 10.7 Strategic Dump (3-tier)

1. **Non-trump singletons** (lowest rank) — creates voids.
2. **Safe to break** (non-trump, not breaking AK/KQ combos) — lowest rank.
3. **Non-trump** — lowest rank.
4. If only trump remains: play Joker if available, else lowest trump.

### 10.8 Card Tracker

Per-round state:
- `playedCards` — set of all played cards.
- `knownVoids` — seat → set of void suits.
- `remainingCards(myHand)` — fullDeck - played - myHand.
- `isHighestRemaining(card, hand)` — is card highest unplayed of its suit?
- `trumpsRemaining(trumpSuit, hand)` — unplayed trumps not in my hand.
- `isSuitExhausted(suit, hand)` — no more of this suit in play.

### 10.9 Game Context

From `ClientGameState`:
- `roundControlUrgency`: 0.0–1.0. `need / remaining` where need = bid - bidderTricks.
- `tricksNeededForBid`: bid value - bidding team tricks.
- `partnerLikelyWinningTrick`: partner's card is best in partial trick.
- `partnerNeedsProtection`: partner winning but trump not yet played.
- `opponentLikelyVoidInLedSuit` / `partnerLikelyVoidInLedSuit`: from tracked voids.

**Removed from GameContext**: `persona` field (bot personas removed).

---

## 11. BOT STRATEGY (TypeScript — Workers)

### 11.1 Hand Evaluator (TS)

Same scoring as Dart: base probability + trump bonus + texture + long suit + voids. Identical formula.

### 11.2 Bid Strategy (TS)

**Different thresholds than Dart:**

| Bid | TS Threshold | Dart Threshold |
|---|---|---|
| Bab (5) | 4.5 | 5.0 |
| Six | 5.5 | 6.0 |
| Seven | 6.5 | 7.0 |
| Kout | 7.5 | 8.0 |

**TS threshold adjustments:**
- Score-based: same patterns (+1.0 if can win with Bab, +0.8 if close, etc.)
- Position: first to act = -0.3 (more conservative), 2+ acted = +0.2/+0.3
- Partner bid = +0.3, partner pass = -0.3
- **No shape floor, no gates** in TS version.

**⚠️ PARITY GAP**: TS bid strategy is simpler — no shape floor, no Seven/Kout gates, no partner "never outbid" rule, different thresholds. These should be aligned.

### 11.3 Trump Strategy (TS)

Same structure but **uses hardcoded weights** `lengthWeight = 2.0`, `strengthWeight = 1.0` instead of BotSettings values (2.5 / 0.45).

No forced-bid fast path (just picks longest).

**⚠️ PARITY GAP**: TS trump weights differ from Dart BotSettings.

### 11.4 Play Strategy (TS)

Similar structure: lead priorities (masters, aces, trump strip, singletons, longest suit), follow logic (poison prevention, suit following, void handling, joker urgency, trump, dump).

**Key differences from Dart:**
- No trick countdown check (play Joker with <= 2 tricks remaining).
- Joker urgency uses simple 0.3 threshold (Dart uses more nuanced multi-factor).
- No partner trump guarantee logic in void follow.
- Follow suit: always plays lowest winner (Dart differentiates by position — highest if not last).

**⚠️ PARITY GAP**: TS play strategy is simpler. Missing trick countdown, position-aware follow, partner protection with trump guarantee.

---

## 12. TIMING

| Event | Duration |
|---|---|
| Human turn timeout | 15s |
| Deal animation | 300ms |
| Card play delay | 1500ms |
| Trick resolution | 2s |
| Scoring overlay | 2s |
| Bid announcement | 3s |

**Bot thinking (context-aware):**

| Situation | Range |
|---|---|
| Passing (bid) | 800–1200ms |
| Forced bid | 1000–2000ms |
| High bid (7/Kout) | 2500–4000ms |
| Normal bid | 1500–2500ms |
| 1 legal move (play) | 500–1000ms |
| Late trick (7+) | 2000–4000ms |
| Normal play | 1500–3500ms |

---

## 13. DART ↔ TYPESCRIPT PARITY

| Module | Status | Notes |
|---|---|---|
| Deck | ✅ Match | Both 32 cards, exclude 7♦ |
| Bid Validator | ✅ Match | Dart uses seat indices, TS uses player IDs |
| Play Validator | ✅ Match | Both have joker-cannot-lead, poison joker detection. TS removed detectJokerLead. |
| Trick Resolver | ✅ Match | Same priority: Joker > Trump > Led. TS lacks `beats()` helper (not needed server-side). |
| Scorer | ✅ Match | Both have applyPoisonJoker → applyKout. Both removed old +10 penalty. |
| Hand Evaluator | ✅ Match | Same formula (base + trump bonus + texture + long suit + voids) |
| Bid Strategy | ⚠️ Diverged | TS: lower thresholds (4.5/5.5/6.5/7.5), no shape floor, no gates, no partner rule |
| Trump Strategy | ⚠️ Diverged | TS: hardcoded 2.0/1.0 weights vs Dart 2.5/0.45 |
| Play Strategy | ⚠️ Diverged | TS: simpler follow logic, no trick countdown, no position-aware winners, no partner trump guarantee |

---

## 14. ITEMS FOR REVIEW

1. **TS bid thresholds diverged** — TS uses 4.5/5.5/6.5/7.5, Dart uses 5.0/6.0/7.0/8.0. Which is correct? Should they match?
2. **TS missing shape floor + gates** — Dart has sophisticated hand-shape minimum bids and Seven/Kout gates. TS has none.
3. **TS trump weights hardcoded** — Should use 2.5/0.45 to match Dart BotSettings.
4. **TS play strategy gaps** — Missing: trick countdown (Joker play with ≤2 tricks left), position-aware following (highest vs lowest winner), partner trump guarantee.
5. **Trick.ledSuit still handles Joker-lead case** — Returns null if first card is Joker. Dead code path since Joker can't lead, but still in the model.
6. **Bot personas removed** — GameContext no longer has `persona` field. Play strategy no longer calls `_personaTieBreak`. Confirmed clean.
7. **Void bonus jump** — Dart hand evaluator gives +1.0 for void in non-trump with trump (up from old +0.3). Significant change. TS evaluator still uses +0.3. Parity gap.
