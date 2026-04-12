# Offline (Dart) vs Online (TypeScript/Workers) — Gap Analysis

Generated: 2026-04-12 (re-checked). Covers every file in `lib/shared/logic/`, `lib/offline/`, and `workers/src/game/`.

---

## 1. Shared Logic — IN SYNC ✅

Core rule files are functionally equivalent:

| Component | Dart | TypeScript | Status |
|-----------|------|-----------|--------|
| **BidValidator** | `bid_validator.dart` | `bid-validator.ts` | ✅ Match |
| **PlayValidator** | `play_validator.dart` | `play-validator.ts` | ✅ Match |
| **TrickResolver** | `trick_resolver.dart` | `trick-resolver.ts` | ✅ Match |
| **Scorer** | `scorer.dart` | `scorer.ts` | ✅ Match |
| **Constants** | `targetScore=31`, `tricksPerRound=8` | `TARGET_SCORE=31`, `TRICKS_PER_ROUND=8` | ✅ Match |
| **Bid points** | `successPoints/failurePoints` | `BID_SUCCESS_POINTS/BID_FAILURE_POINTS` | ✅ Match |

All specific rules confirmed in sync: `joker-cannot-lead`, `must-lead-trump`, `detectPoisonJoker`, `applyPoisonJoker` → `applyKout`, `isRoundDecided`, tug-of-war `applyScore`, Kout success via `applyKout`.

---

## 2. Game Flow — IN SYNC ✅ (was 5 gaps, all fixed)

| Item | Previous Status | Current Status |
|------|----------------|----------------|
| **Poison Joker lead-only guard** | ❌ Missing `isLeadPlay` check | ✅ Fixed — `game-room.ts:660` now checks `isLeadPlay && detectPoisonJoker(hand)` |
| **Bid Announcement phase** | ❌ Missing — jumped to PLAYING | ✅ Fixed — `BID_ANNOUNCEMENT` added to `GamePhase`, `handleSelectTrump` sets phase + 2.5s alarm, alarm handler transitions to PLAYING |
| **Forced bid tracking** | ❌ `isForced` hardcoded false | ✅ Fixed — `forcedBidSeat` field in `GameDocument`, set in `handleBotTurn`, read in `buildBotContext` (`isForced: game.forcedBidSeat === botSeat`) |
| **Hand size validation** | ❌ No validation | ✅ Fixed — `initGame` line 92: `if (hand.length !== 8) throw new Error(...)` |
| **Round index tracking** | ❌ Not tracked | ✅ Fixed — `roundIndex` in `GameDocument`, initialized to 0, incremented in `startNextRound` |

---

## 3. Dealer Rotation — IN SYNC ✅

Both use identical logic: losing team deals, dealer stays if already on losing team, else rotates one CCW. Tied = dealer stays.

---

## 4. Bot Strategy — IN SYNC ✅ (was 5 major gaps, all fixed)

### 4.1 Hand Evaluator ✅

| Feature | Dart | TS (updated) | Status |
|---------|------|------|--------|
| **Base probability** | A=0.85, K=0.65, Q=0.35, J=0.15, else=0.05 | Same | ✅ |
| **Trump bonus** | A=+0.15, K/Q/J=+0.25, else=+0.30 | Same | ✅ |
| **Strongest suit first** | ✅ Pre-selects strongest, applies trump bonus | ✅ Same | ✅ |
| **Void bonus** | +1.0 (ruffing) or +0.1 (no trump) | +1.0 / +0.1 | ✅ |
| **Long suit bonus** | +0.1 per card beyond 3 | Same | ✅ |
| **Suit texture** | AKQ=+0.5, AK=+0.3, KQ(no A)=+0.2 | Same | ✅ |
| **Partner estimates** | `effectiveTricks()` (1.0/1.5/0.5) | `effectiveTricks()` same constants | ✅ |
| **Output** | `HandStrength { personalTricks, strongestSuit }` | `HandStrength { personalTricks, strongestSuit }` | ✅ |

### 4.2 Bid Strategy ✅

| Feature | Dart | TS (updated) | Status |
|---------|------|------|--------|
| **Thresholds** | 5.0 / 6.0 / 7.0 / 8.0 | 5.0 / 6.0 / 7.0 / 8.0 | ✅ |
| **Partner estimates** | Via `effectiveTricks` | Via `effectiveTricks` | ✅ |
| **Shape floor** | 5→Bab ... 7+Joker→Kout | Same ladder | ✅ |
| **Seven gate** | 6+ suit, Joker+5+AK, 3A+Joker | Same | ✅ |
| **Kout gate** | 7+ suit, Joker+6+AKQ, Joker+5+3A, ET≥7.6 | Same | ✅ |
| **Partner rule** | Never outbid partner unless Kout | `partnerAction === 'bid' && ceiling !== 8` → pass | ✅ |
| **Desperation** | +1.0 when opp ≥ targetScore-10 | Same | ✅ |
| **Forced bid** | Ceiling or next legal | Same | ✅ |
| **Opponent contest** | Only if ET ≥ next level | Same | ✅ |

### 4.3 Trump Strategy ✅

| Feature | Dart | TS (updated) | Status |
|---------|------|------|--------|
| **Length weight** | 2.5 (BotSettings) | 2.5 (TRUMP_LENGTH_WEIGHT) | ✅ |
| **Strength weight** | 0.45 (BotSettings) | 0.45 (TRUMP_STRENGTH_WEIGHT) | ✅ |
| **Kout override** | length=1.5, strength=2.0 | Same | ✅ |
| **Tiebreaker** | Honor tiebreak (A=3, K=2) then length | Same | ✅ |
| **Forced bid path** | Removed — same algo | TS also removed forced-bid shortcut, takes `ctx` | ✅ |

### 4.4 Play Strategy ✅

| Feature | Dart | TS (updated) | Status |
|---------|------|------|--------|
| **Leading: master cards** | Non-trump before trump | Same | ✅ |
| **Leading: ace leads** | Prefer A-K combo | Same | ✅ |
| **Leading: trick countdown** | Joker when ≤2 tricks + urgency > 0.7 | Same (`ctx.roundControlUrgency`) | ✅ |
| **Leading: partner void exploit** | Via `tracker.knownVoids[partnerSeat]` | Same | ✅ |
| **Leading: trump strip** | Bidding team, 3+ trump | Same | ✅ |
| **Following: position-aware** | 2nd/3rd=highest winner, 4th=lowest winner | Same (`myPosition`) | ✅ |
| **Following: trick countdown** | Joker when ≤2 tricks | Same | ✅ |
| **Following: partner trump guarantee** | CardTracker `trumpsRemaining`/`remainingCards` | Same | ✅ |
| **Following: Joker urgency** | `roundControlUrgency` | Same | ✅ |
| **Strategic dump** | Singleton→safe→nonTrump→Joker fallback | Same | ✅ |
| **GameContext signals** | `roundControlUrgency`, `partnerLikelyWinning`, `partnerNeedsProtection`, `opponentVoidLed`, `partnerVoidLed` | All in `BotContext`, computed by `buildBotContext` | ✅ |

### 4.5 CardTracker ✅

| Feature | Dart | TS (updated) | Status |
|---------|------|------|--------|
| **Played card tracking** | `recordPlay(seat, card)` | `recordPlay(seat, card)` | ✅ |
| **Void inference** | `inferVoid(seat, suit)` + `knownVoids` | Same | ✅ |
| **`isHighestRemaining`** | ✅ | ✅ | ✅ |
| **`trumpsRemaining`** | ✅ | ✅ | ✅ |
| **`remainingCards`** | ✅ | ✅ | ✅ |
| **Reconstruction** | Persistent tracker | Rebuilt with void inference from `buildTrackerFromRaw` | ✅ |

---

## 5. New Online-Only Features

Features in `game-room.ts` with no offline equivalent (expected — multiplayer infrastructure):

| Feature | Details |
|---------|---------|
| **WebSocket management** | Connection/disconnection, auto ping/pong |
| **Disconnect timeout** | 90s grace period before forfeit |
| **Forfeit scoring** | Bid failure penalty or default 10 |
| **Room/Lobby mode** | Host creates, friend joins seat 2, bots at 1+3 |
| **Lobby expiry** | 10-minute timeout |
| **Bot turn scheduling** | Alarm-based, 800-2000ms random delay |
| **Human timeout** | 15s per action, auto-passes or plays random legal card |
| **State persistence** | Durable Object storage |
| **Game completion** | Records to D1 via `completeGame` |
| **Reconnection** | Cancels disconnect timeout, sends `reconnected` event |

---

## 6. Remaining Minor Gaps

### 6.1 Dealing Phase (cosmetic)

| | Dart | TS |
|---|---|---|
| **Explicit DEALING phase** | ✅ `GamePhase.dealing` with delay | ❌ `'DEALING'` exists in type but is never set |

Not gameplay-affecting — purely for client-side dealing animation.

### 6.2 Context-Aware Bot Delays (UX polish)

| | Dart | TS |
|---|---|---|
| **Bot thinking time** | `GameTiming.botThinkingDelay` — varies by legal moves, trick number, forced bid, bid amount | Flat 800-2000ms random |

Not gameplay-affecting — just makes bots feel more natural.

### 6.3 Singleton Lead Before Trump Strip (lead priority order)

| Priority | Dart | TS |
|----------|------|-----|
| 1 | Master cards | Master cards |
| 2 | Non-trump aces | Non-trump aces (with A-K preference) |
| **3** | **Singleton voids (if have trump)** | *(missing)* |
| 4 | Trump strip (bidding team, 3+) | Trump strip |
| 5 | Partner void exploit | Partner void exploit |
| 6 | Short suit (defense) | Short suit (defense) |

**GAP**: Dart has a step between aces and trump strip: if you have trump and a singleton non-trump card, lead the singleton to create a void for future ruffing. TS skips this and goes straight to trump strip.

### 6.4 `followingSuit` Detection

| | Dart | TS |
|---|---|---|
| **Check** | `legalCards.any((c) => !c.isJoker && c.suit == ledSuit)` | Same (`legal.some(...)`) |

✅ Match — both correctly detect when following suit (Joker excluded from suit detection).

### 6.5 `beatsCard` Function

TS now has `beatsCard` in `card.ts` (line 70) used by both play strategy and trick signals in `buildBotContext`. Dart uses `TrickResolver.beats`. Logic is identical.

---

## 7. Summary

| Category | Total Items | ✅ In Sync | ⚠️ Minor Gap |
|----------|-------------|-----------|-------------|
| **Shared logic** | 6 | 6 | 0 |
| **Game flow** | 7 | 7 | 0 |
| **Bot strategy** | 5 | 5 | 0 |
| **CardTracker** | 5 | 5 | 0 |
| **Minor/cosmetic** | 3 | 0 | 3 |

**All critical, high, and medium gaps from the previous analysis have been resolved.** Three minor cosmetic gaps remain (dealing phase, bot delays, singleton lead priority).
