# Bot Strategy Redesign — Design Spec

**Date**: 2026-04-09
**Status**: Approved
**Approach**: Simplification (Approach B) — cleaner rules, fewer stacking adjustments

---

## Context

The current bot strategy has layered adjustments that interact unpredictably. Bots overbid (especially Seven), outbid their own partner, fail to trump when they should, and sometimes overtake their partner's winning trick. This redesign simplifies the system with clear, rule-based logic.

## Changes from Logic Review

These changes were confirmed during the logic review session and affect bot strategy:

- **Joker cannot be led** — not a legal lead card (validator enforces this)
- **Poison joker = instant game loss** — opponent score set to 31, only triggers when player must lead and only card is Joker
- **Forced bid = free choice** — last player must bid but can choose any level
- **Remove bot personas** — always play strongest option in tiebreaks

---

## 1. Hand Evaluation (Redesigned)

**Replace** decimal weight system with suit-based trick potential.

### Per-Card Trick Probability
Each card gets a trick-winning probability (independent of trump — trump bonuses are separate):

| Rank | Probability | Rationale |
|---|---|---|
| Ace | 0.85 | Almost always wins its suit |
| King | 0.65 | Wins if Ace is out or you hold it |
| Queen | 0.35 | Needs favorable conditions |
| Jack | 0.15 | Rarely wins unless trump |
| 10 and below | 0.05 | Almost never wins |

**Trump bonus**: If a card is in the prospective trump suit (strongest suit), add:
- Ace: +0.15 (→ 1.0, guaranteed)
- King: +0.25 (→ 0.9)
- Queen: +0.25 (→ 0.6)
- Jack: +0.25 (→ 0.4)
- 10 and below: +0.30 (→ 0.35, low trump can still ruff)

**Long suit bonus**: If 4+ cards in a suit, add +0.1 per card beyond 3 (length creates tricks through exhaustion).

Sum all card probabilities = personal trick potential.

### Joker
- Scored as 1.0 guaranteed trick, separate from suit scoring

### Void Bonus
- Void in non-trump suit + has trump: +1.0 (ruffing potential = ~1 trick)
- Void in non-trump suit + no trump: +0.1

### Suit Texture Bonus (kept)
- AKQ in same suit: +0.5
- AK in same suit: +0.3
- KQ without A: +0.2

### Partner Contribution Estimate (NEW)
- Partner hasn't bid or passed yet: +1.0 estimated tricks
- Partner bid (any level): +1.5 estimated tricks (they have something)
- Partner passed: +0.5 estimated tricks (weak hand assumed)

### Output
- `effectiveTricks`: personal trick potential + partner estimate (0.0–8.0)
- `strongestSuit`: suit with highest trick potential

---

## 2. Bid Strategy (Simplified)

**Replace** stacking threshold adjustments with clear rules.

### Core Rule
Bid the highest level your `effectiveTricks` can support:
- effectiveTricks >= 5.0 → Bab
- effectiveTricks >= 6.0 → Six
- effectiveTricks >= 7.0 → Seven (with gate)
- effectiveTricks >= 8.0 → Kout (with gate)

### Partner Rule
**Never outbid your own partner unless going Kout.** If partner already bid, pass — unless you have a Kout-worthy hand.

### Seven Gate (NEW)
Only bid Seven if ONE of:
- 6+ cards in strongest suit
- Joker + 5+ cards in a suit with A-K
- 3+ Aces + Joker

Seven is extremely hard to make. This gate prevents reckless Seven bids.

### Kout Gate (kept)
Must pass ONE of:
- Longest suit >= 7
- Joker + 6+ cards + AKQ block
- Joker + 5+ cards + 3 Aces
- effectiveTricks >= 7.6

### Desperation Override
If losing this round means opponent reaches 31: lower all thresholds by 1.0.
(So 4.0 effectiveTricks is enough for Bab in desperation.)

### Opponent Contest
Only outbid an opponent if effectiveTricks >= the new bid level. No margin padding.

### Forced Bid
When forced (everyone else passed), bid the highest level the hand supports. No floor — use normal evaluation. If hand only supports Bab, bid Bab.

### Shape Floors (simplified)
Keep shape floors but remove difficulty-based promotion/demotion:
- 7+ in a suit + Joker → Kout
- 7+ in a suit → Seven
- 6 in a suit + Joker + AKQ → Kout
- 6 in a suit + Joker → Seven
- 6 in a suit → Six
- 5 in a suit + Joker → Six
- 5 in a suit → Bab

Take maximum of shape floor and threshold bid.

---

## 3. Trump Strategy (Cleaned Up)

### Weight Simplification
- Normal mode: lengthWeight = 2.5, strengthWeight = 0.45 (from BotSettings)
- Kout mode: lengthWeight = 1.5, strengthWeight = 2.0 (strength matters more)
- Remove confusing hardcoded defaults

### Scoring Formula (kept)
```
score = count * lengthWeight + suitStrength * strengthWeight + bonuses
```

### Bonuses (kept)
- Joker + 3+ cards in suit: +1.0
- Void in other suits: +0.5 each
- Side-suit Ace: +0.9, King: +0.5

### Forced Bid Trump
No special case. Use normal selection — forced bidders now choose any level, so they should pick trump normally.

### Tiebreak (kept)
Within 0.5 score: prefer suit with more A/K honors, then longer suit.

---

## 4. Play Strategy — Leading (Updated)

Priority order:

1. **Master cards** — highest remaining card of any suit (tracked via CardTracker). Non-trump masters first.
2. **Aces** — non-trump aces. Prefer ace with king in same suit (sets up king for next trick).
3. **Singleton voids** (NEW position) — lead a singleton non-trump card when you have trump in hand. Creates void for future ruffing.
4. **Trump strip** — bidding team with 3+ trumps: lead highest trump to pull opponents' trumps.
5. **Partner void exploit** — lead into a suit partner is void in (they can trump it).
6. **Longest non-trump suit** — lead lowest card to develop the suit.
7. **Fallback** — highest non-Joker card. Joker can never be led.

### Removed
- Bot persona tiebreaks (always play strongest)
- Defender-specific singleton logic (merged into #3)

---

## 5. Play Strategy — Following (Simplified)

### Following Suit

| Situation | Action |
|---|---|
| Partner winning + trick is safe (no opponent can beat) | Play lowest |
| Partner winning + opponent still to play | Play lowest winner if possible, else play low and hope |
| Opponent winning + I can beat | Play lowest card that wins |
| Opponent winning + I can't beat | Play lowest (dump) |
| Last to play + can win | Play lowest winner |
| Last to play + can't win | Play lowest |

### Void in Led Suit

| Situation | Action |
|---|---|
| Opponent winning + I have trump | **Always trump** (no conservation) |
| Partner winning safely | Dump strategically |
| Partner winning + opponent still to play + I have trump higher than any remaining trump | Trump to guarantee the trick |
| Partner winning + opponent still to play + I can't guarantee | Dump strategically (don't waste trump) |
| Can't win any other way + need the trick | Play Joker |
| 2 or fewer cards left + one is Joker | Play Joker NOW (poison prevention) |
| No trump, can't win | Dump strategically |

### Removed
- Trump conservation logic (always trump when opponent winning)
- Urgency threshold system for Joker
- Bot persona tiebreaks
- Complex pre-check dump modes

---

## 6. Joker Management (New Rules)

1. **Never lead** — enforced by validator, not strategy
2. **Poison prevention** — if hand has <= 2 cards and one is Joker, play Joker immediately when following
3. **Last resort winner** — use Joker when no other card can win a needed trick
4. **Forced bid early use** — when bid was forced, use Joker early rather than saving for perfect moment
5. **Trick countdown** — if 2 tricks remain and bot still has Joker, must use it this trick (next trick = must lead = poison)

### Removed
- Urgency threshold (0.08) and urgency score calculation
- Complex poison risk detection with suit exhaustion checks
- `jokerUrgencyThreshold` from BotSettings

---

## 7. Strategic Dump Logic (Simplified)

Priority when dumping:
1. Singletons in non-trump suits (lowest rank) — creates voids
2. Lowest card from weakest non-trump suit — don't break AK/KQ combos
3. Lowest trump if only trump remains

### Removed
- "Safe to break" intermediate category (merged into #2)
- Persona-based tiebreaks (always lowest)

---

## 8. Removed Components

- **BotPersona** — entire file removed. No more Methodical/Pressure/Resource styles.
- **Stacking adjustments** — replaced with clear rules
- **Urgency threshold** — replaced with rule-based Joker management
- **Trump conservation** — removed entirely
- **Difficulty adjustment on shape floors** — removed (single difficulty level)

---

## 9. BotSettings Update

```dart
// Removed:
// bidAdjust = 1.1  (no longer used — clear rules instead)
// jokerUrgencyThreshold = 0.08  (no longer used — rule-based)

// Kept:
trumpLengthWeight = 2.5
trumpStrengthWeight = 0.45

// New:
partnerEstimateDefault = 1.0    // estimated partner tricks (no info)
partnerEstimateBid = 1.5        // partner placed a bid
partnerEstimatePass = 0.5       // partner passed
desperationThreshold = 1.0      // threshold reduction when survival bid needed
```

---

## 10. Testing Strategy

- Unit tests for each strategy function with known hands
- Regression tests: record current bot decisions on specific hands, verify new system makes equal or better choices
- Integration test: simulate 100 games, verify no crashes, no poison joker deaths from bad planning, no illegal plays
- Manual playtesting: verify bots feel smart, don't overbid, protect partner tricks
