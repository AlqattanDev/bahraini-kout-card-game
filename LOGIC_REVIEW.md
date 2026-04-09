# Koutbh Logic Review

Everything extracted from the codebase. Reviewed with owner — decisions marked below.

---

## CONFIRMED CHANGES (from review session)

1. **Poison joker = instant game loss** — opponent score set to 31, not +10. Triggers only when player must LEAD and only card is Joker (not when following).
2. **Remove "Khallou" name** — Joker is just "Joker" everywhere.
3. **Joker cannot be led** — not a legal lead card. Remove the old "joker lead = round loss" code path entirely.
4. **Forced bid = free choice** — last player must bid but can choose ANY level (not forced to Bab).
5. **Trump timeout auto-pick** — auto-select best suit (count + rank strength). Add countdown timer + visual warning. Both offline and online modes.
6. **Remove bot personas** — no Methodical/Pressure/Resource styles. Always play strongest option in tiebreaks.
7. **Bot strategy needs brainstorm** — bidding thresholds too aggressive (especially Seven), play priorities, following logic, hand evaluation all need tuning session.
8. **Check trump weight wiring** — verify BotSettings 2.5/0.45 weights are actually passed to TrumpStrategy.
9. **Bot partner awareness bug** — bots sometimes overtake their own partner's winning trick. Investigate and fix.

---

## 1. CONSTANTS & DOMAIN RULES

### 1.1 Game Constants (Dart + TS)

| Constant | Value | Notes |
|---|---|---|
| Target score | 31 | Tug-of-war, first to 31 wins |
| Tricks per round | 8 | 32 cards / 4 players |
| Player count | 4 | 6-player not implemented |
| Poison joker penalty | **INSTANT GAME LOSS** | ~~+10~~ → opponent score set to 31 **(CHANGED)** |

### 1.2 Deck Composition

- **Spades**: A, K, Q, J, 10, 9, 8, 7 (8 cards)
- **Hearts**: A, K, Q, J, 10, 9, 8, 7 (8 cards)
- **Clubs**: A, K, Q, J, 10, 9, 8, 7 (8 cards)
- **Diamonds**: A, K, Q, J, 10, 9, 8 (7 cards — **no 7 of diamonds**)
- **Joker**: 1 card **(renamed — removed "Khallou")**
- **Total**: 32 cards, 8 per player

### 1.3 Rank Values (for comparison)

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

| Suit | Initial |
|---|---|
| Spades | S |
| Hearts | H |
| Clubs | C |
| Diamonds | D |

Examples: `SA` = Ace of Spades, `D10` = 10 of Diamonds, `HK` = King of Hearts.

---

## 2. TEAMS & SEATING

### 2.1 Teams

- **Team A**: Seats 0, 2 (partners across)
- **Team B**: Seats 1, 3 (partners across)
- Rule: `seatIndex.isEven ? Team.a : Team.b`

### 2.2 Counter-Clockwise Seating

```
nextSeat(i) = (i - 1 + 4) % 4
```

Order: 0 → 3 → 2 → 1 → 0

### 2.3 Partner Seat

```
partnerSeat = (mySeat + 2) % 4
```

---

## 3. DEALER ROTATION

- **First round**: Random dealer (0–3).
- **After each round**: Losing team deals.
  - If current dealer is already on the losing team → dealer stays.
  - If current dealer is on the winning team → rotate one step CCW to land on losing team.
  - If tied (both scores equal) → dealer stays.

```dart
int nextDealerSeat(int currentDealer, Map<Team, int> scores) {
  if (scoreA == scoreB) return currentDealer;          // tie = stay
  final losingTeam = scoreA < scoreB ? Team.a : Team.b;
  if (teamForSeat(currentDealer) == losingTeam) return currentDealer;  // already on losing team
  return nextSeat(currentDealer);                      // rotate CCW once
}
```

**✅ CONFIRMED**: Losing team = lower score. Correct for tug-of-war.

---

## 4. BIDDING

### 4.1 Bid Amounts

| Bid | Value (tricks needed) | Success Points | Failure Points |
|---|---|---|---|
| Bab | 5 | +5 | +10 (to opponent) |
| Six | 6 | +6 | +12 |
| Seven | 7 | +7 | +14 |
| Kout | 8 | Score set to 31 (instant win) | +16 (to opponent) |

Note: `BidAmount.nextAbove(current)` returns the next higher bid. `nextAbove(null)` = Bab.

### 4.2 Bidding Flow

1. **Start**: Seat after dealer, going CCW.
2. **Single orbit**: Each player bids or passes exactly once.
3. **Must exceed**: New bid must be strictly higher than current highest.
4. **Pass = permanent**: Once you pass, you're out.
5. **Kout = immediate end**: If someone bids 8 (Kout), bidding ends instantly.
6. **Forced bid**: If 3 players pass with NO bid on the table, the last player MUST bid — but can choose ANY bid level, not just Bab **(CHANGED)**. If someone already bid, the last player CAN pass.
7. **No malzoom/reshuffle**: No redeal mechanism.

### 4.3 Bid Validation (Dart)

```
validateBid:
  - already passed? → invalid
  - bid not higher than current? → invalid
  - else → valid

validatePass:
  - already passed? → invalid
  - last bidder AND no current bid? → must-bid error
  - else → valid

isLastBidder:
  - not in passed list AND only 1 active player remaining

checkBiddingComplete:
  - 3+ passed AND current bid exists AND bidder exists → won
  - else → ongoing
```

### 4.4 Bid Validation (TypeScript — Workers)

Same logic, uses string player IDs instead of seat indices. Functionally identical.

**⚠️ REVIEW**: Dart uses `passedPlayers.length >= 3` and TS uses the same. Both check `>= 3` which is correct for 4 players (3 passed = 1 winner).

---

## 5. TRUMP SELECTION

After bidding, the winning bidder picks a trump suit.

No validation constraints — any of the 4 suits is valid. The bidder's hand composition influences the choice but it's a free pick.

**Timeout behavior (NEW):** If player doesn't pick in time, auto-select the best suit based on card count + rank strength. Show countdown timer and visual warning as time runs low. Applies to both offline and online modes.

---

## 6. PLAY VALIDATION

### 6.1 Rules

1. **Card must be in hand.**
2. **Kout first trick lead**: If bid is Kout AND it's the first trick AND you're leading, you MUST play trump if you have it. (Joker is exempt — you CAN play Joker instead of trump.)
3. **Must follow suit**: If not leading and you have cards of the led suit, you must play one. Joker is exempt (playable anytime regardless of led suit).
4. **Joker CANNOT be led** — it is not a legal lead card **(CHANGED)**. This is why poison joker exists: if your only card is the Joker and you must lead, you can't play — instant game loss.

### 6.2 Playable Cards Helper

`playableForCurrentTrick()` combines all rules into a single filter. Takes:
- hand, trickHasNoPlaysYet (= leading), ledSuit, trumpSuit, bidIsKout, noTricksCompletedYet

Returns the set of legally playable cards.

### 6.3 Special Detections

- **Poison Joker**: Player must lead but only card is Joker → **instant game loss**, opponent score set to 31 **(CHANGED)**. Only triggers when leading, not when following.
- ~~**Joker Lead**~~: **REMOVED** — Joker simply cannot be led. No separate penalty path needed.

**✅ RESOLVED**: Joker lead code path removed. Poison joker is the only special Joker detection, and it now causes instant game loss.

### 6.4 Dart vs TypeScript Parity

Both implementations have identical validation logic. TS version works with string card codes, Dart with GameCard objects.

---

## 7. TRICK RESOLUTION

### 7.1 Winner Priority

1. **Joker always wins** — first joker found in plays wins the trick.
2. **Highest trump** — if any trump was played, highest trump rank wins.
3. **Highest of led suit** — among cards that followed the led suit, highest rank wins.

### 7.2 `beats(a, b)` comparison

Used by bot play strategy to compare individual cards:
- Joker beats everything.
- Trump beats non-trump.
- Same suit: higher rank wins.
- Led suit beats off-suit non-trump.

### 7.3 Led Suit

- First card played in a trick determines led suit.
- ~~If first card is Joker → led suit is `null`~~ — **N/A, Joker cannot lead anymore.**

**✅ RESOLVED**: Since Joker can't be led, led suit is always defined. Remove null-ledSuit handling from PlayValidator.

---

## 8. SCORING

### 8.1 Round Result

```
if biddingTeamTricks >= bidValue:
  winner = biddingTeam, points = successPoints
else:
  winner = opponent, points = failurePoints
```

### 8.2 Tug-of-War Application

```
applyScore(scores, winningTeam, points):
  net = winnerScore + points - loserScore
  if net >= 0: winner = net, loser = 0
  if net < 0:  winner = 0, loser = -net
```

**Invariant**: Only one team ever has a non-zero score.

Example: Team A has 5. Team B wins 10 points. Net = 0 + 10 - 5 = 5. Result: Team A = 0, Team B = 5.

### 8.3 Kout Scoring

- **Kout success**: Winning team score set to 31 (instant game win), loser set to 0.
- **Kout failure**: Regular scoring with failurePoints = 16. NOT instant loss — just a big penalty.

**✅ CONFIRMED**: Kout failure = +16 via tug-of-war, NOT instant loss. Correct as-is.

### 8.4 Poison Joker Scoring

```
calculatePoisonJokerResult(jokerHolderTeam):
  winner = jokerHolderTeam.opponent
  winner.score = 31  // instant game loss for joker holder
```

**✅ CONFIRMED + CHANGED**: Poison joker = instant game loss (score 31), not +10. Winner is always the team opposing the joker holder. The unused `biddingTeam` param can be removed.

### 8.5 Game Over Check

Any team reaching `>= 31` wins.

### 8.6 Early Round Termination

```
isRoundDecided:
  bidderTricks >= bidValue  (bidder already made it)
  OR opponentTricks > 8 - bidValue  (opponent blocked it)
```

Example: Bid is 6. If opponent has 3 tricks (> 8-6 = 2), bidder can't reach 6 in remaining tricks.

---

## 9. GAME CONTROLLER FLOW (Offline)

### 9.1 Round Structure

```
1. Deal (shuffle, 8 cards each)
2. Bidding (single CCW orbit)
3. Trump Selection (bidder picks)
4. Bid Announcement (pause for UI)
5. Play 8 Tricks
6. Round Scoring
7. Check game over → if not, new round with updated dealer
```

### 9.2 Trick Play Flow

- **First trick leader**: Seat after bidder (CCW).
- **Subsequent trick leader**: Previous trick winner.
- Each trick: 4 cards played CCW from leader.
- After each play: card tracked, voids inferred if off-suit.
- Poison joker check only when player must LEAD and only card is Joker **(CHANGED)**.
- ~~Joker lead check~~ — **REMOVED** (Joker can't be led).
- Early termination check after each trick resolution.

### 9.3 Card Tracking (in-trick)

The controller creates one `CardTracker` per round. After each card:
- `recordPlay(seat, card)` — adds to played set.
- If following and played off-suit → `inferVoid(seat, ledSuit)`.

### 9.4 Forced Bid Tracking

`_bidWasForced` boolean tracks if the winning bid was a forced bid. Passed to `TrumpContext.isForcedBid` and `PlayContext.isForced` so bots can adjust strategy.

### 9.5 Kout Scoring Path in Controller

```dart
if (!poisonJoker && bid.isKout && result.winningTeam == bidderTeam):
  scores = Scorer.applyKout(winningTeam)  // instant 31
else:
  scores = Scorer.applyScore(scores, winningTeam, points)  // normal tug-of-war
```

So Kout failure goes through normal `applyScore` with 16 points penalty.

---

## 10. BOT STRATEGY

### 10.1 Bot Settings (Single Difficulty)

```
bidAdjust = 1.1           (positive = bids more readily)
trumpLengthWeight = 2.5
trumpStrengthWeight = 0.45
jokerUrgencyThreshold = 0.08  (lower = use joker sooner)
```

No difficulty tiers — one strong profile.

### ~~10.2 Bot Persona (Style Variation)~~ — **REMOVED**

~~Three styles~~ → Always play strongest option in tiebreaks. Simplification — personas added unnecessary complexity for marginal variety.

### 10.3 Hand Evaluator

Produces `HandStrength { expectedWinners: 0.0–8.0, strongestSuit }`.

**Per-card scoring:**

| Rank | Base Value | With ≥3 in suit | Trump Bonus |
|---|---|---|---|
| Ace | 0.9 | 0.9 | +0.5 |
| King | 0.6 | 0.8 | +0.4 |
| Queen | 0.3 | 0.5 | +0.3 |
| Jack | 0.2 | 0.2 | +0.2 |
| Ten | 0.1 | 0.1 | +0.3 |
| 9/8/7 | 0.0 | 0.0 | +0.3 |
| Joker | 1.0 (flat) | — | — |

**Suit texture bonuses:**
- AKQ in same suit: +0.5
- AK in same suit: +0.3
- KQ (no A) in same suit: +0.2

**Distribution bonuses:**
- 4+ cards in a suit: +0.3
- Void in non-trump suit (with trump in hand): +0.3 (ruffing potential)
- Void in non-trump suit (no trump): +0.1
- Void in trump suit: +0.0 (bad)

### 10.4 Bid Strategy

**Threshold-based bidding:**

| Bid | Strength Threshold |
|---|---|
| Bab (5) | 3.7 |
| Six | 4.3 |
| Seven | 5.0 |
| Kout (8) | 5.8 |

**Threshold adjustments (cumulative):**

| Condition | Adjustment |
|---|---|
| My team can win with Bab (+5 minus opp) | +1.0 |
| My team score + 5 ≥ 31 | +0.8 |
| Opponent ≥ 25 and I ≤ 5 (desperate) | +1.0 |
| My team ≥ 26 (close to winning) | +0.5 |
| Opponent ≥ 26 (must contest) | +0.5 |
| First to act (position 0) | +0.2 |
| Third to act (position 2) | +0.2 |
| Fourth to act (position 3+) | +0.3 |
| Partner bid (not pass) | +0.5 |
| Partner passed | -0.1 |
| BotSettings.bidAdjust | +1.1 |

**Shape boost (on top of threshold):**
- Longest suit ≥ 7: +0.8
- Longest suit = 6 + Joker: +0.5

**Power card boost:**
- Per Ace: +0.35
- Per King: +0.25
- Per Queen: +0.12
- Joker: +1.0

**Shape floor bids** (minimum bid regardless of strength score):

| Hand Shape | Floor Bid |
|---|---|
| 7+ in a suit + Joker | Kout |
| 7+ in a suit | Seven |
| 6 in a suit + Joker + AKQ | Kout |
| 6 in a suit + Joker | Seven |
| 6 in a suit + off-suit A + off-suit K | Seven |
| 6 in a suit | Six |
| 5 in a suit + Joker | Six |
| 5 in a suit + off-suit A | Six |
| 5 in a suit | Bab |
| 4 in a suit + Joker | Bab |
| 4 in a suit + (off-suit A or K) | Bab |
| AKQ in 3-card suit + Joker + off-suit A | Bab |

**Kout gate** (even if strength says Kout, must pass one of):
- Longest suit ≥ 7
- Joker + longest suit ≥ 6 + AKQ block in some suit
- Joker + longest suit ≥ 5 + 3 Aces
- Adjusted strength ≥ 7.6

**Opponent contest**: If opponent placed the current high bid, bot will bid one higher IF strength exceeds that bid's threshold by +0.3.

**Forced bid**: If forced (last player, no bids), plays best possible bid up to ceiling. If someone already bid higher, tries next above. Fallback: Bab.

### 10.5 Trump Strategy

**Candidate scoring:**
```
score = count * lengthWeight + strength * strengthWeight
```

Default weights: `lengthWeight = 2.0`, `strengthWeight = 1.0`.
Kout weights: `lengthWeight = 1.5`, `strengthWeight = 2.0`.
BotSettings overrides: `lengthWeight = 2.5`, `strengthWeight = 0.45`.

**⚠️ REVIEW**: BotSettings defines `trumpLengthWeight = 2.5` and `trumpStrengthWeight = 0.45`, but `TrumpStrategy.selectTrump` uses default values `2.0` / `1.0` unless explicitly passed. The BotPlayerController would need to pass these. Check if BotSettings values are actually used or dead code.

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
- Prefer suits with ≥ 2 cards.
- If no suit has 2+, consider all.
- For forced bids: just pick longest suit (honor tiebreak).

**Tiebreak (within 0.5 score):**
- Higher AK honor tiebreak → then longer suit.

### 10.6 Play Strategy — Leading

Priority order:
1. **Master cards** (highest remaining in suit, tracked): Play non-trump masters first, highest rank.
2. **Off-trump Aces**: Prefer ace with a king in same suit (sets up next trick). Then singleton aces. Then any ace.
3. **Trump strip** (bidding team only): If 3+ trumps, lead highest trump to strip opponents.
4. **Partner void exploit**: Lead into a suit partner is void in (they can trump).
5. **Non-trump singletons** (defending team): Create void for future ruffing.
6. **Longest non-trump suit**, lowest card.
7. **Fallback**: Highest available non-joker. Last resort: joker.

**Bot never leads Joker** (filtered out unless it's the only legal play).

### 10.7 Play Strategy — Following

**Pre-checks:**
- If bidding team already made their bid → dump mode (play low).
- If defending and bidder already made bid → dump mode.
- If defending and bidder already mathematically lost → dump mode.
- If defending and bidder needs exactly 1 more trick → play Joker if available, else winning trump.

**Partner interactions:**
- Partner led low + partner currently winning → play low (support).
- Forced bid context → play aces if following suit, else dump.
- If only 2 cards left and one is Joker → play Joker immediately (avoid poison).

**Following same suit:**
- Partner winning + early position + low urgency → play lowest (let partner keep it).
- Partner winning + high urgency + can beat → overtake to secure.
- Partner winning + last to play → play lowest.
- Last to play + partner not winning → play winning card if possible, else lowest.
- Otherwise → try to beat, else play lowest.

**Off-suit (void in led suit):**
- Partner winning → dump (strategic dump, avoid joker poison risk).
- Joker logic:
  - Can't win without joker + partner not winning → play joker.
  - Poison risk (≤ 1–2 non-joker cards, suits not exhausted) → play joker.
  - Urgency threshold (needs 1 trick, opponent trumped, few cards left) → play joker if urgency ≥ 0.08.
- Trump conservation: If only 1 trump left and ≤ 1 trump outstanding, don't trump low tricks (save for later).
- Has trump → play lowest winning trump. Can't win with trump → dump.
- No trump → dump.

### 10.8 Strategic Dump Logic

Priority:
1. **Non-trump singletons** (lowest rank) — creates void for future ruffing.
2. **Safe to break** (not trumps, not breaking AK/KQ combos) — lowest rank.
3. **Non-trump** — lowest rank.
4. **Anything** — lowest rank.

### 10.9 Joker Poison Risk Detection

```
jokerPoisonRisk(nonJokerLegal, hand, tracker):
  - 0 non-joker legal cards → true
  - ≤ 1 non-joker legal cards → true
  - ≤ 2 non-joker legal + tracker shows suit not exhausted → true
```

### 10.10 Card Tracker

Maintained per round:
- `playedCards` — set of all cards played this round.
- `knownVoids` — map of seat → set of suits they've shown void in.
- `remainingCards(myHand)` — fullDeck - played - myHand.
- `isHighestRemaining(card, hand)` — is this card the highest unplayed of its suit?
- `trumpsRemaining(trumpSuit, hand)` — count of unplayed trumps not in my hand.
- `isSuitExhausted(suit, hand)` — no more cards of this suit in play.

### 10.11 Game Context

Computed from `ClientGameState`:

- `roundControlUrgency`: 0.0–1.0. `need / remaining` where need = bid - bidderTricks, remaining = 8 - tricksPlayed. 0 if bid already made, 1.0 if need > remaining (impossible).
- `tricksNeededForBid`: bid value - bidding team tricks.
- `partnerLikelyWinningTrick`: Is partner's card currently the best in the partial trick?
- `partnerNeedsProtection`: Partner winning but trump hasn't been played yet (could be stolen).
- `opponentLikelyVoidInLedSuit` / `partnerLikelyVoidInLedSuit`: Based on tracked voids.

---

## 11. TIMING

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

## 12. DART ↔ TYPESCRIPT PARITY CHECK

| Module | Dart | TypeScript | Notes |
|---|---|---|---|
| Bid Validator | ✅ seat indices | ✅ player IDs | Functionally identical |
| Play Validator | ✅ GameCard objects | ✅ string codes | Functionally identical |
| Trick Resolver | ✅ returns seat index | ✅ returns player ID | Same priority: Joker > Trump > Led |
| Scorer | ✅ full (tug-of-war, kout, poison, early term) | ✅ full | Same formulas |
| Deck | ✅ 32 cards | ✅ 32 cards | Both exclude 7♦ |

**⚠️ REVIEW**: The TS `trick-resolver.ts` does NOT have a `beats()` helper — only the full `resolveTrick()`. The Dart version has both. Not a bug, just asymmetry.

---

## 13. ITEMS FLAGGED FOR REVIEW

1. ✅ **Dealer rotation logic**: Confirmed correct — losing team = lower score.
2. ✅ **Joker lead → ledSuit null**: RESOLVED — Joker can't lead, so this never happens. Remove null handling.
3. ✅ **Kout failure = 16 via tug-of-war**: Confirmed correct — not instant loss.
4. ✅ **Poison joker ignores biddingTeam param**: Confirmed correct — remove unused param.
5. 🔍 **BotSettings trump weights possibly unused**: TODO — check if 2.5/0.45 are wired up.
6. ✅ **Bot never leads Joker**: Now a hard rule — Joker cannot be led at all.
7. ✅ **Bot persona deterministic**: RESOLVED — personas removed entirely.
8. 🧠 **Forced bid escalation**: CHANGED — forced player can choose any bid level. Needs code update.
9. 🧠 **Hand evaluator trump bonus**: Flagged for brainstorm — evaluate if current system or rank sums work better.
10. 🧠 **Score-based bid aggression**: Flagged for brainstorm — thresholds too aggressive, especially for Seven.
