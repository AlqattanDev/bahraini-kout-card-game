# Bahraini Kout Card Game — Design Spec

## Overview

A mobile-only (iOS/Android) multiplayer Bahraini Kout card game built with Flutter/Flame. Online multiplayer with auto-matchmaking, Firebase/Firestore backend, 4-player mode (2v2 teams), Diwaniya-themed aesthetic.

## Game Rules Summary

### Deck Configuration (4-Player Mode)

- 32 cards total
- Spades, Hearts, Clubs: 8 cards each (A, K, Q, J, 10, 9, 8, 7)
- Diamonds: 7 cards (A, K, Q, J, 10, 9, 8)
- 1 Joker (Khallou)
- Each player receives 8 cards (entire deck is dealt)

### Teams

- Players sit in a virtual table with 4 seats (0–3)
- Teams: seats 0 & 2 (Team A) vs seats 1 & 3 (Team B)
- Partners sit across from each other (traditional Diwaniya seating)

### Scoring

- Target score: 31 points
- Only the winning team gains points; the losing team's score is unchanged
- Scores cannot go below 0

| Bid | Name  | Success (bidding team gets) | Failure (opponent gets) |
|-----|-------|-----------------------------|------------------------|
| 5   | Bab   | +5                          | +10                    |
| 6   | —     | +6                          | +12                    |
| 7   | —     | +7                          | +14                    |
| 8   | Kout  | +31 (instant win)           | +31 (instant loss)     |

- Round outcome: the bidding team must win at least N tricks (where N = bid amount) out of 8 to succeed. If they win fewer than N tricks, the bid fails and the opponent gets the failure penalty.

### Bidding Rules

- Bidding proceeds clockwise starting from the player after the dealer (seat after dealer)
- Each player can bid higher than the current bid or pass
- **A pass is permanent** — once a player passes, they cannot bid again in the same round
- Bidding ends when three consecutive players have passed (one bidder remains)
- Valid bids: 5 (Bab), 6, 7, 8 (Kout). Each bid must be higher than the current highest bid.

### Trick-Taking Rules

- Must follow suit if holding a card of the led suit
- Bidding winner picks trump suit after winning the bid (any suit is valid — no requirement to hold a card of that suit)
- The player seated after the bid winner leads the first trick
- Trick winner leads subsequent tricks
- Card ranking (high to low): A, K, Q, J, 10, 9, 8, 7

### Trick Resolution Order

1. If the Joker was played → Joker's player wins (always wins)
2. If any trump cards were played → highest trump wins
3. Otherwise → highest card of the led suit wins

### Joker (Khallou) Rules

- Cannot be led (played first in a trick)
- Always wins the trick when played (not as lead)
- **Poison Joker:** If it is a player's turn and their only remaining card is the Joker, the Poison Joker triggers immediately — their team loses the round automatically (+10 penalty to opponent). The trick is not played out. This check happens before the player attempts to play, so the illegal-lead situation never arises.

### Malzoom Rule

- If all 4 players pass during bidding → reshuffle the entire deck and re-deal fresh 8-card hands, bidding restarts from player after dealer
- If all 4 players pass a second time → dealer is forced to bid 5 (Malzoom). The dealer then selects trump as normal.
- Tracked via `reshuffleCount` field (0 or 1)

### Scoring Examples

**Example 1 — Bid 5 success:** Team A bids 5. Team A wins 6 tricks, Team B wins 2. Team A succeeds (won ≥ 5 tricks). Team A gets +5. Scores: Team A 5, Team B 0.

**Example 2 — Bid 6 failure:** Team A bids 6. Team A wins 4 tricks, Team B wins 4. Team A fails (won < 6 tricks). Team B gets +12 (double penalty). Scores: Team A 5, Team B 12.

**Example 3 — Score clamping:** Team B has 2 points. Team B bids 5 and fails. Team A gets +10. Team A's score increases by 10. Team B's score stays at 2 (not deducted).

**Example 4 — Kout:** Team A bids 8 (Kout) and wins all 8 tricks. Team A gets +31 → instant win regardless of current scores.

---

## Architecture

### Approach: Authoritative Firestore

All game state lives in a single Firestore document per match (plus subcollections for private data). Cloud Functions validate every move server-side before writing state. Clients subscribe to the document for realtime updates. No direct client writes to game state.

### Game State Machine

```
WAITING → DEALING → BIDDING → TRUMP_SELECTION → PLAYING → ROUND_SCORING → GAME_OVER
```

Special transitions:
- `BIDDING → DEALING`: All players pass, reshuffle (reshuffleCount < 1)
- `BIDDING → TRUMP_SELECTION`: All players pass second time, dealer forced to bid 5 (Malzoom)
- `BIDDING → TRUMP_SELECTION`: Normal bidding concludes (one bidder remains)
- `PLAYING → ROUND_SCORING`: After 8 tricks complete, or Poison Joker trigger
- `ROUND_SCORING → DEALING`: If no team has reached 31, start new round (rotate dealer clockwise)
- `ROUND_SCORING → GAME_OVER`: If a team has reached 31

### Firestore Data Model

#### Game Document (`games/{gameId}`)

```json
{
  "phase": "BIDDING",
  "players": ["uid1", "uid2", "uid3", "uid4"],
  "currentTrick": {
    "lead": "uid2",
    "plays": [
      {"player": "uid2", "card": "HK"},
      {"player": "uid3", "card": "H9"}
    ]
  },
  "tricks": {
    "teamA": 3,
    "teamB": 2
  },
  "scores": {"teamA": 12, "teamB": 8},
  "bid": {"player": "uid1", "amount": 6},
  "biddingState": {
    "currentBidder": "uid2",
    "highestBid": 6,
    "highestBidder": "uid1",
    "passed": ["uid3", "uid4"]
  },
  "trumpSuit": "hearts",
  "dealer": "uid3",
  "currentPlayer": "uid4",
  "reshuffleCount": 0,
  "roundHistory": [],
  "metadata": {
    "createdAt": "timestamp",
    "status": "active"
  }
}
```

**Hands are NOT stored in the main game document.** They are stored in a private subcollection (see below).

Card encoding: 2-character strings — suit initial + rank. `SA` = Ace of Spades, `HK` = King of Hearts, `JO` = Joker. Exception: 10s use 3 characters (`S10`, `H10`, `C10`, `D10`).

#### Private Hands (`games/{gameId}/private/{uid}`)

Each player's hand is stored in a separate subcollection document that only they can read:

```json
{
  "cards": ["SA", "HK", "C10", "D9", "H7", "CJ", "S8", "JO"]
}
```

This replaces the previous `hands` field on the main game doc. Cloud Functions read/write these subcollection docs during dealing and card play. Clients subscribe to their own `private/{uid}` doc for hand updates.

---

## Matchmaking

### Queue System

- Players write a doc to `matchmaking_queue/{uid}` containing ELO rating and timestamp
- A Cloud Function `onWrite` trigger watches the collection
- When 4 players are queued, the function:
  1. Pulls the 4 closest-ELO players
  2. Randomly assigns seats (0–3), locking teams as 0&2 vs 1&3
  3. Creates the `games/{gameId}` document in `WAITING` state
  4. Removes all 4 from the queue
  5. Sends FCM push to all 4 players with the `gameId`

### ELO System

- Starting rating: 1000
- Standard Elo formula: `new_elo = old_elo + K * (actual - expected)` where `expected = 1 / (1 + 10^((opponent_elo - player_elo) / 400))`
- K-factor: 32
- For 2v2: each team's rating is the average of its two players' ELO. After the game, each player's individual ELO is updated based on their team's result vs the opposing team's average.
- Stored in `users/{uid}/stats/elo`
- No floor or ceiling on ratings
- ELO updated immediately after `GAME_OVER` phase is written
- Matchmaking brackets: ±200 ELO, expanding by 100 every 15 seconds of wait time, up to ±500
- If no match found after 75 seconds (±500 bracket), keep waiting indefinitely at ±500 (no timeout — player can leave queue manually)

### Disconnect Handling

- Each player writes a heartbeat to `games/{gameId}/presence/{uid}` using Firestore TTL (60s)
- If a player's presence doc expires, a Cloud Function starts a 90-second reconnection timer
- If the player doesn't return within 90 seconds:
  - The game is forfeited — the disconnected player's team loses the entire game
  - If currently in BIDDING phase with no bid placed: opponent gets +10 (equivalent to bid-5 failure)
  - If a bid is active: opponent gets the failure penalty for the current bid
  - If in PLAYING phase: opponent gets the failure penalty for the current bid
  - Remaining players see a "player disconnected" screen and can return to matchmaking

---

## Cloud Functions

Six callable functions (TypeScript, Firebase Functions v2):

### 1. `joinQueue(eloRating)`
Adds the authenticated player to the matchmaking queue.

### 2. `leaveQueue()`
Removes the authenticated player from the queue.

### 3. `placeBid(gameId, bidAmount)`
- Validates: correct player's turn, bid higher than current highest, value in [5, 6, 7, 8], player is not in `passed` list
- `bidAmount = 0` represents a pass (adds player to `passed` list permanently for this round)
- When 3 players have passed: remaining player wins the bid, transition to `TRUMP_SELECTION`
- Handles Malzoom: when all 4 pass and `reshuffleCount < 1`, transition to `DEALING` with `reshuffleCount++`. When all 4 pass and `reshuffleCount == 1`, force dealer to bid 5 and transition to `TRUMP_SELECTION`.

### 4. `selectTrump(gameId, suit)`
- Validates: caller is the winning bidder, suit is one of [spades, hearts, clubs, diamonds]
- No requirement for bidder to hold a card of the chosen suit
- Writes `trumpSuit`, transitions phase to `PLAYING`, sets `currentPlayer` to player after bid winner

### 5. `playCard(gameId, card)`
- **Poison Joker pre-check:** Before validating the play, check if the player's only remaining card is the Joker. If so, trigger Poison Joker immediately (+10 to opponent, transition to `ROUND_SCORING`). No card is played.
- Validates: correct player's turn, card is in their hand (from `private/{uid}`), suit-following rules, Joker cannot be led
- Removes card from player's `private/{uid}` doc
- After 4 plays: resolves trick winner per resolution order, updates trick counts, advances `currentPlayer` to trick winner
- After 8 tricks: transition to `ROUND_SCORING`, calculate outcome (tricks won vs bid), apply scoring, check for game end

### 6. `getMyHand(gameId)`
- Returns the caller's hand from `private/{uid}`
- Convenience function — clients can also subscribe directly to their `private/{uid}` doc via security rules

### Validation Pattern

Every mutation function follows:
1. Authenticate caller via `context.auth.uid`
2. Read game doc (and private docs if needed) inside a Firestore transaction
3. Validate the action against current game state
4. Write updated state atomically
5. On failure: throw `HttpsError` with descriptive code (`not-your-turn`, `must-follow-suit`, `cannot-lead-joker`, `poison-joker`)

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /games/{gameId} {
      allow read: if request.auth.uid in resource.data.players;
      allow write: if false;
    }
    match /games/{gameId}/private/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if false;
    }
    match /games/{gameId}/presence/{uid} {
      allow write: if request.auth.uid == uid;
      allow read: if request.auth.uid in get(/databases/$(database)/documents/games/$(gameId)).data.players;
    }
    match /matchmaking_queue/{uid} {
      allow write: if request.auth.uid == uid;
      allow read: if false;
    }
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

---

## Client Architecture (Flutter/Flame)

### Project Structure

```
lib/
  app/
    screens/
      home_screen.dart
      matchmaking_screen.dart
      game_screen.dart          # hosts the Flame GameWidget
    services/
      auth_service.dart         # Firebase Auth
      matchmaking_service.dart
      game_service.dart         # Firestore game doc + private hand subscription
    models/
      player.dart
      game_state.dart           # client-side mirror of Firestore doc
  game/
    kout_game.dart              # main FlameGame class
    components/
      card_component.dart
      hand_component.dart
      trick_area.dart
      player_seat.dart
      bid_overlay.dart
      trump_selector.dart
      score_display.dart
    managers/
      animation_manager.dart
      input_manager.dart
  shared/
    constants.dart              # card encodings, suit enums, bid values
    card_utils.dart             # trick resolution, validation helpers
```

### Data Flow

1. `GameService` subscribes to two Firestore paths: `games/{gameId}` (public state) and `games/{gameId}/private/{myUid}` (own hand)
2. On each snapshot, maps Firestore data into a `GameState` object
3. Pushes `GameState` to `KoutGame` via a stream
4. Flame components react to state changes (animations, UI updates)
5. Player actions (play card, bid, select trump) call `GameService.sendAction()` which invokes the appropriate Cloud Function

### Table Layout (Portrait)

- Bottom: Human player's hand (fan layout, tappable cards)
- Top: Partner's seat (card backs, avatar)
- Left/Right: Opponents' seats (card backs, avatars)
- Center: Trick area (cards played this trick)
- Bidding and trump selection: modal overlays

### Animations

- Card play: arc from hand to center with shadow offset
- Trick collection: sweep cards to winning team's side
- Dealing: fan cards out from deck position with staggered delay
- Powered by Flame's `MoveEffect` and `ScaleEffect`

---

## UI/UX — Diwaniya Aesthetic

### Color Palette

| Role       | Color                  | Hex       |
|------------|------------------------|-----------|
| Primary    | Deep burgundy/maroon   | `#5C1A1B` |
| Accent     | Warm gold              | `#C9A84C` |
| Table      | Dark walnut brown      | `#3B2314` |
| Text       | Cream/off-white        | `#F5ECD7` |
| Secondary  | Muted copper           | `#8B5E3C` |

### Visual Design

- **Table surface:** Rich wood grain texture, dark walnut with subtle radial gradient toward center
- **Card backs:** Islamic geometric tiling pattern in burgundy and gold, thick white borders
- **Card faces:** Traditional playing card design with Arabic-influenced geometric border patterns
- **Player seats:** Circular avatar frames with gold rope borders; active player gets a gold glow pulse
- **Typography:** Arabic-friendly typefaces, bilingual support (Arabic + English) from day one, optional Eastern Arabic numerals
- **Ambient details:** Subtle tea glass/coffee cup decorations near each seat (cosmetic), faint geometric pattern overlay on background
- **No gradients, no rounded candy colors** — brutalist clarity with traditional warmth

---

## Anti-Cheat

- All game logic runs server-side in Cloud Functions
- Client is purely a renderer + input collector
- No card data available client-side except the player's own hand (via private subcollection)
- Firebase App Check enabled; Cloud Functions reject calls without valid attestation tokens
- Per-user rate limiting: max 2 actions/second via in-memory counter

---

## Testing Strategy

### Unit Tests (Dart)

Pure game logic in `shared/card_utils.dart`:
- Trick resolution (Joker > trump > led suit)
- Suit-following validation
- Poison Joker detection
- Scoring math (additive scoring, clamping at 0, Kout instant win/loss)
- Malzoom triggering (single and double all-pass)
- Bid validation (higher than current, permanent pass)
- Round outcome (tricks won vs bid amount)
- No Firebase or Flame dependencies

### Cloud Function Integration Tests (TypeScript)

Using Firebase Emulator Suite:
- Full game flow: create game → deal → bid → select trump → play 8 tricks → score
- Edge cases: Malzoom (double pass), Poison Joker, Kout win/loss, score clamping at 0
- Bidding edge cases: all pass once (reshuffle), all pass twice (Malzoom), permanent pass enforcement
- Disconnect mid-game handling (during bidding, during play)
- Security rule tests: clients can't read other players' hands, can't write to game docs, can't read matchmaking queue

### Widget/Flame Tests (Flutter)

- Flame components react to state changes correctly
- Card animations trigger on new trick plays
- Bid overlay appears during BIDDING phase
- Trump selector appears for winning bidder only
- Score display updates on ROUND_SCORING
- Using `testWidgets` + Flame's `FlameTester`

### E2E Test

Scripted 4-client test using Firebase Emulator:
- Four mock players run through a complete game
- Verifies full loop from matchmaking to GAME_OVER

---

## Scope Boundaries

### In Scope (MVP)

- 4-player online multiplayer
- Auto-matchmaking with ELO
- Complete Kout ruleset (bidding, trick-taking, Malzoom, Poison Joker, Kout)
- Firebase Auth (anonymous + Google Sign-In)
- Diwaniya-themed UI
- iOS + Android

### Out of Scope (Future)

- 6-player mode (48-card deck)
- Room codes / private games
- Friends list
- Chat / emotes in-game
- Spectator mode
- Leaderboards
- AI opponents (offline play)
- Desktop / web builds
