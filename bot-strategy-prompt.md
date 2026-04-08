# Bot Strategy Improvements — koutbh

Improve the bot AI in `lib/offline/bot/` to play competitively against humans. The existing infrastructure (`BidStrategy`, `TrumpStrategy`, `PlayStrategy`, `HandEvaluator`, `CardTracker`, `GameContext`) is already in place — this is about making the decision logic smarter, not restructuring.

Read `CLAUDE.md` for full game rules. Key reminder: 32-card deck (S/H/C × 8, D × 7, 1 Joker). 4 players, teams of 2 (seats 0,2 vs 1,3). CCW play. Bids: 5 (Bab), 6, 7, 8 (Kout). Must follow led suit. Joker is always playable and always wins.

---

## 1. BidStrategy — smarter bid evaluation

Current thresholds use `HandEvaluator.expectedWinners` which is too abstract. Add concrete hand-shape rules that fire BEFORE the numeric threshold check:

### Shape-based bid triggers

| Hand shape | Minimum bid | Notes |
|---|---|---|
| 5+ cards of one suit | Bab (5) | Long suit = probable trump suit, expect to win most trump tricks |
| 6+ of one suit | Six (6) | |
| 7+ of one suit | Seven (7) | |
| 7+ of one suit AND Joker | Kout (8) | Near-guaranteed sweep |
| 4 of one suit + Joker | Bab (5) | Joker covers the gap |
| 4 of one suit + off-suit Ace or King | Bab (5) | Side winner covers the gap |
| 5 of one suit + Joker | Six (6) | Extrapolate same pattern upward |
| 5 of one suit + off-suit Ace | Six (6) | |
| AKQ of one suit + Joker + off-suit Ace | Bab (5) | Top-heavy hand, short but strong |

Scale these upward logically — e.g. 6 of a suit + Joker → Seven, 6 of a suit + off-suit Ace + off-suit King → Seven, etc.

These shape rules set a **floor**. The existing `expectedWinners` threshold can still push the bid higher. The bot should bid the **max** of (shape-based floor, threshold-based bid).

### Anti-passive behavior

The current logic allows bots to pass too freely. Fix:

- If a bot has ANY shape trigger above, it MUST bid (not pass) unless the current high bid already exceeds its floor.
- When forced to bid (3 passes, no prior bid), the forced-bid logic is already handled — but make sure the forced bidder still uses shape rules to pick the right level, not just default to Bab.
- Partner inference: if partner bid, be more willing to overbid opponents (lower thresholds by ~0.5 winners).

---

## 2. TrumpStrategy — forced/fallback selection

Current implementation is decent. One fix for the forced-bid / weak-hand case:

- **Forced bid with no clear suit:** pick the suit where the bot holds the most cards. Tiebreak by highest card strength. This is already roughly what happens but make sure it's the explicit path when `isForcedBid == true` and no suit scores above a minimum threshold.
- **General:** when 3+ suits are close in score, prefer the suit where the bot holds top honors (A, K) even if it's shorter by 1 card. Strength > length for tight decisions.

---

## 3. PlayStrategy — situational awareness

These are the biggest gaps. The bot needs to reason about **position** (am I first/last to play this trick?) and **partner state**.

### 3a. Last-to-play optimization (4th seat)

When the bot plays last in a trick, it has perfect information:

- **Partner is currently winning the trick:** play the **lowest legal card**. Do NOT waste a high card or trump. Dump garbage — prefer off-suit low cards, or lowest of led suit if must follow.
- **Opponent is currently winning:** play the minimum card needed to win. Don't over-commit (e.g. don't play Ace when Queen beats the current winner). If you can't beat it, dump the lowest card.

### 3b. Trump conservation

When void in the led suit and considering trumping:

- **Partner is winning:** do NOT trump. Dump a low card from your weakest side suit instead.
- **Opponent is winning with a non-trump card:** trump with the **lowest trump** that wins, not the highest. Preserve high trumps for later.
- **Opponent is winning with a trump card:** only overtrump if you can. If you can't overtrump, dump a low side-suit card. Never waste a lower trump that doesn't win.
- **Trick has low value (no Aces/Kings played, early in round):** consider NOT trumping even if you can, especially as defender. Save trump for high-value tricks.

### 3c. Leading strategy improvements

When the bot leads a trick:

- **Has master cards** (highest remaining in a suit, tracked via `CardTracker`): lead those first — guaranteed winners.
- **Bidding team with trump majority:** lead high trump to strip opponents' trumps. Once opponents are void in trump, side-suit Aces become safe winners.
- **Defending team:** lead short suits to create voids for trumping opportunities. Lead low from long suits to probe.
- **Avoid leading Joker** (existing rule — leading Joker = instant round loss).

### 3d. Endgame awareness

When ≤3 cards remain:

- Count remaining trumps via `CardTracker`. If opponents are out of trump, side-suit honors are safe leads.
- **Joker poison check:** if Joker is your last card, you auto-lose. When you're down to 2 cards and one is the Joker, play the Joker NOW (don't wait to be forced). Existing `_jokerPoisonRisk()` should trigger this — make sure it does.
- If the bidding team has already made their bid, switch to dump mode — play low, don't fight for tricks. If defending and bid is already lost, same thing.

### 3e. Team coordination signals

- **Leading a low card in a suit:** signals to partner that you want them to win this trick (you're probing or setting up a void).
- **Leading an Ace:** signals strength in that suit. Partner should dump low in response if they follow.
- When partner leads low, don't compete — let them manage the trick unless an opponent is about to win.

---

## Implementation notes

- All changes go in `lib/offline/bot/` — `bid_strategy.dart`, `trump_strategy.dart`, `play_strategy.dart`.
- `HandEvaluator` may need a new method like `suitDistribution(hand)` → `Map<Suit, List<GameCard>>` to support shape-based bid rules (or use existing grouping if present).
- `CardTracker` integration in `PlayStrategy` is already optional but should be used for all "master card" and "remaining trump" logic. Make sure `GameContext.tracker` is populated.
- Keep `BotDifficulty` modulation — these improvements should be the `balanced` baseline. `conservative` can dampen (higher thresholds, less aggressive trumping), `aggressive` can amplify.
- Write or update Vitest/Flutter tests for new bid triggers and play scenarios.
- Card encoding: "SA" = Ace of Spades, "HK" = King of Hearts, "JO" = Joker.
