# Firebase Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Firebase backend — Cloud Functions for game logic, Firestore security rules, matchmaking queue, and ELO system — fully tested with the Firebase Emulator Suite.

**Architecture:** TypeScript Cloud Functions (Firebase Functions v2) as the authoritative game server. Firestore for state persistence. All game mutations are server-side only. Clients interact via callable functions.

**Tech Stack:** TypeScript, Firebase Functions v2, Firestore, Firebase Auth, Firebase Emulator Suite, Jest

**Spec:** `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md`

**Depends on:** Plan 1 (Shared Game Logic) for understanding the game rules. The TypeScript functions reimplement the same logic.

---

## File Structure

```
functions/
  src/
    index.ts                    # Cloud Function exports
    game/
      types.ts                  # TypeScript interfaces matching Firestore schema
      card.ts                   # Card model, encoding/decoding (TS port)
      deck.ts                   # Deck construction and dealing
      trick-resolver.ts         # Trick winner determination
      play-validator.ts         # Suit-following, joker rules, poison joker
      bid-validator.ts          # Bid validation, pass tracking, malzoom
      scorer.ts                 # Round scoring, game-over detection
    functions/
      join-queue.ts             # joinQueue callable
      leave-queue.ts            # leaveQueue callable
      place-bid.ts              # placeBid callable
      select-trump.ts           # selectTrump callable
      play-card.ts              # playCard callable
      get-my-hand.ts            # getMyHand callable
    matchmaking/
      match-players.ts          # onWrite trigger for matchmaking queue
      elo.ts                    # ELO calculation
    presence/
      presence-monitor.ts       # onDelete trigger for presence TTL expiry
      disconnect-handler.ts     # 90-second timer and forfeit logic
    utils/
      auth.ts                   # Auth helper
      rate-limiter.ts           # Per-user rate limiting (2 actions/sec)
  test/
    game/
      card.test.ts
      deck.test.ts
      trick-resolver.test.ts
      play-validator.test.ts
      bid-validator.test.ts
      scorer.test.ts
    functions/
      join-queue.test.ts
      place-bid.test.ts
      select-trump.test.ts
      play-card.test.ts
      get-my-hand.test.ts
    matchmaking/
      match-players.test.ts
      elo.test.ts
    integration/
      full-game.test.ts
  package.json
  tsconfig.json
firestore.rules
firebase.json
```

---

### Task 1: Firebase Project Scaffold

**Files:**
- Create: `firebase.json`
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/src/index.ts`
- Create: `firestore.rules`

- [ ] **Step 1: Initialize Firebase project**

```bash
cd /path/to/project
firebase init functions --typescript
firebase init firestore
firebase init emulators
```

Select: Functions (TypeScript), Firestore, Auth emulator, Functions emulator, Firestore emulator.

- [ ] **Step 2: Install dev dependencies**

```bash
cd functions
npm install --save-dev jest ts-jest @types/jest firebase-functions-test
npm install --save firebase-admin firebase-functions
```

- [ ] **Step 3: Configure Jest**

Add to `functions/package.json`:
```json
{
  "scripts": {
    "test": "jest --forceExit --detectOpenHandles",
    "test:emulator": "firebase emulators:exec --only firestore,auth,functions 'npm test'"
  },
  "jest": {
    "preset": "ts-jest",
    "testEnvironment": "node",
    "testMatch": ["**/test/**/*.test.ts"]
  }
}
```

- [ ] **Step 4: Write Firestore security rules**

```
// firestore.rules
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

- [ ] **Step 5: Create empty index.ts**

```typescript
// functions/src/index.ts
// Cloud Functions will be exported here as they are implemented.
```

- [ ] **Step 6: Verify build**

Run: `cd functions && npm run build`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add firebase.json firestore.rules functions/
git commit -m "feat: scaffold Firebase project with functions, firestore rules, and emulator config"
```

---

### Task 2: TypeScript Game Models (Port from Dart)

**Files:**
- Create: `functions/src/game/types.ts`
- Create: `functions/src/game/card.ts`
- Create: `functions/src/game/deck.ts`
- Create: `functions/test/game/card.test.ts`
- Create: `functions/test/game/deck.test.ts`

- [ ] **Step 1: Write TypeScript type definitions**

```typescript
// functions/src/game/types.ts
export type SuitName = 'spades' | 'hearts' | 'clubs' | 'diamonds';
export type RankName = 'ace' | 'king' | 'queen' | 'jack' | 'ten' | 'nine' | 'eight' | 'seven';

export interface GameCard {
  suit: SuitName | null;
  rank: RankName | null;
  isJoker: boolean;
  code: string; // encoded string e.g. "SA", "HK", "JO"
}

export type GamePhase = 'WAITING' | 'DEALING' | 'BIDDING' | 'TRUMP_SELECTION' | 'PLAYING' | 'ROUND_SCORING' | 'GAME_OVER';
export type TeamName = 'teamA' | 'teamB';

export interface TrickPlay {
  player: string; // uid
  card: string;   // encoded card
}

export interface BiddingState {
  currentBidder: string;
  highestBid: number | null;
  highestBidder: string | null;
  passed: string[];
}

export interface GameDocument {
  phase: GamePhase;
  players: string[];
  currentTrick: {
    lead: string;
    plays: TrickPlay[];
  } | null;
  tricks: Record<TeamName, number>;
  scores: Record<TeamName, number>;
  bid: { player: string; amount: number } | null;
  biddingState: BiddingState | null;
  trumpSuit: SuitName | null;
  dealer: string;
  currentPlayer: string;
  reshuffleCount: number;
  roundHistory: TrickPlay[][];
  metadata: {
    createdAt: FirebaseFirestore.Timestamp;
    status: string;
  };
}

export const RANK_VALUES: Record<RankName, number> = {
  ace: 14, king: 13, queen: 12, jack: 11, ten: 10, nine: 9, eight: 8, seven: 7,
};

export const BID_SUCCESS_POINTS: Record<number, number> = { 5: 5, 6: 6, 7: 7, 8: 31 };
export const BID_FAILURE_POINTS: Record<number, number> = { 5: 10, 6: 12, 7: 14, 8: 31 };
export const TARGET_SCORE = 31;
export const POISON_JOKER_PENALTY = 10;
```

- [ ] **Step 2: Write card.ts tests**

```typescript
// functions/test/game/card.test.ts
import { encodeCard, decodeCard, makeCard, makeJoker } from '../../src/game/card';

describe('Card encoding', () => {
  test('encodes ace of spades as SA', () => {
    expect(encodeCard(makeCard('spades', 'ace'))).toBe('SA');
  });

  test('encodes 10 of diamonds as D10', () => {
    expect(encodeCard(makeCard('diamonds', 'ten'))).toBe('D10');
  });

  test('encodes joker as JO', () => {
    expect(encodeCard(makeJoker())).toBe('JO');
  });

  test('decodes SA to ace of spades', () => {
    const card = decodeCard('SA');
    expect(card.suit).toBe('spades');
    expect(card.rank).toBe('ace');
    expect(card.isJoker).toBe(false);
  });

  test('decodes JO to joker', () => {
    const card = decodeCard('JO');
    expect(card.isJoker).toBe(true);
  });

  test('decodes D10 to ten of diamonds', () => {
    const card = decodeCard('D10');
    expect(card.suit).toBe('diamonds');
    expect(card.rank).toBe('ten');
  });
});
```

- [ ] **Step 3: Implement card.ts**

```typescript
// functions/src/game/card.ts
import { GameCard, SuitName, RankName } from './types';

const SUIT_TO_INITIAL: Record<SuitName, string> = {
  spades: 'S', hearts: 'H', clubs: 'C', diamonds: 'D',
};
const INITIAL_TO_SUIT: Record<string, SuitName> = {
  S: 'spades', H: 'hearts', C: 'clubs', D: 'diamonds',
};
const RANK_TO_STR: Record<RankName, string> = {
  ace: 'A', king: 'K', queen: 'Q', jack: 'J', ten: '10', nine: '9', eight: '8', seven: '7',
};
const STR_TO_RANK: Record<string, RankName> = {
  A: 'ace', K: 'king', Q: 'queen', J: 'jack', '10': 'ten', '9': 'nine', '8': 'eight', '7': 'seven',
};

export function makeCard(suit: SuitName, rank: RankName): GameCard {
  return { suit, rank, isJoker: false, code: `${SUIT_TO_INITIAL[suit]}${RANK_TO_STR[rank]}` };
}

export function makeJoker(): GameCard {
  return { suit: null, rank: null, isJoker: true, code: 'JO' };
}

export function encodeCard(card: GameCard): string {
  return card.code;
}

export function decodeCard(code: string): GameCard {
  if (code === 'JO') return makeJoker();
  const suitChar = code[0];
  const rankStr = code.substring(1);
  const suit = INITIAL_TO_SUIT[suitChar];
  const rank = STR_TO_RANK[rankStr];
  if (!suit || !rank) throw new Error(`Invalid card code: ${code}`);
  return makeCard(suit, rank);
}
```

- [ ] **Step 4: Write deck.ts tests and implement**

Tests verify: 32 cards, correct suit distribution, 1 joker, dealing 4 hands of 8.

- [ ] **Step 5: Run tests**

Run: `cd functions && npm test -- --testPathPattern=game`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add functions/src/game/types.ts functions/src/game/card.ts functions/src/game/deck.ts functions/test/game/
git commit -m "feat: add TypeScript game models — card, deck, types (port from Dart)"
```

---

### Task 3: TypeScript Game Logic (Port from Dart)

**Files:**
- Create: `functions/src/game/trick-resolver.ts`
- Create: `functions/src/game/play-validator.ts`
- Create: `functions/src/game/bid-validator.ts`
- Create: `functions/src/game/scorer.ts`
- Create: `functions/test/game/trick-resolver.test.ts`
- Create: `functions/test/game/play-validator.test.ts`
- Create: `functions/test/game/bid-validator.test.ts`
- Create: `functions/test/game/scorer.test.ts`

Same logic as Plan 1 Tasks 3-6 but in TypeScript. Port the exact same test cases.

- [ ] **Step 1: Write trick-resolver tests (same cases as Dart)**
- [ ] **Step 2: Implement trick-resolver.ts**
- [ ] **Step 3: Run tests → PASS**
- [ ] **Step 4: Write play-validator tests**
- [ ] **Step 5: Implement play-validator.ts**
- [ ] **Step 6: Run tests → PASS**
- [ ] **Step 7: Write bid-validator tests**
- [ ] **Step 8: Implement bid-validator.ts**
- [ ] **Step 9: Run tests → PASS**
- [ ] **Step 10: Write scorer tests**
- [ ] **Step 11: Implement scorer.ts**
- [ ] **Step 12: Run tests → PASS**
- [ ] **Step 13: Commit**

```bash
git add functions/src/game/ functions/test/game/
git commit -m "feat: add TypeScript game logic — trick resolver, play validator, bid validator, scorer"
```

---

### Task 4: Cloud Functions — joinQueue & leaveQueue

**Files:**
- Create: `functions/src/functions/join-queue.ts`
- Create: `functions/src/functions/leave-queue.ts`
- Create: `functions/src/utils/auth.ts`
- Create: `functions/test/functions/join-queue.test.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Write auth utility**

```typescript
// functions/src/utils/auth.ts
import { HttpsError, CallableRequest } from 'firebase-functions/v2/https';

export function requireAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated');
  }
  return request.auth.uid;
}
```

- [ ] **Step 2: Write joinQueue tests**

Tests: adds player to queue with ELO and timestamp, rejects unauthenticated, rejects duplicate queue entry.

- [ ] **Step 3: Implement joinQueue**

```typescript
// functions/src/functions/join-queue.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';

export const joinQueue = onCall(async (request) => {
  const uid = requireAuth(request);
  const { eloRating } = request.data;
  if (typeof eloRating !== 'number') {
    throw new HttpsError('invalid-argument', 'eloRating must be a number');
  }

  const db = getFirestore();
  const queueRef = db.collection('matchmaking_queue').doc(uid);

  const existing = await queueRef.get();
  if (existing.exists) {
    throw new HttpsError('already-exists', 'Already in queue');
  }

  await queueRef.set({
    uid,
    eloRating,
    queuedAt: new Date(),
  });

  return { status: 'queued' };
});
```

- [ ] **Step 4: Implement leaveQueue**
- [ ] **Step 5: Export from index.ts**
- [ ] **Step 6: Run tests with emulator**

Run: `cd functions && npm run test:emulator -- --testPathPattern=join-queue`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add functions/src/functions/ functions/src/utils/ functions/src/index.ts functions/test/functions/
git commit -m "feat: add joinQueue and leaveQueue cloud functions"
```

---

### Task 5: Matchmaking Trigger

**Files:**
- Create: `functions/src/matchmaking/match-players.ts`
- Create: `functions/src/matchmaking/elo.ts`
- Create: `functions/test/matchmaking/match-players.test.ts`
- Create: `functions/test/matchmaking/elo.test.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Write ELO tests**

Tests: standard Elo formula, K=32, team average calculation, individual update from team result.

- [ ] **Step 2: Implement elo.ts**

```typescript
// functions/src/matchmaking/elo.ts
const K = 32;

export function expectedScore(playerElo: number, opponentElo: number): number {
  return 1 / (1 + Math.pow(10, (opponentElo - playerElo) / 400));
}

export function newElo(oldElo: number, expected: number, actual: number): number {
  return Math.round(oldElo + K * (actual - expected));
}

export function teamAverageElo(elos: number[]): number {
  return elos.reduce((a, b) => a + b, 0) / elos.length;
}
```

- [ ] **Step 3: Write matchmaking trigger tests**

Tests: 4 players queued → game created, seats assigned, queue cleared. Fewer than 4 → no match. ELO bracket matching.

- [ ] **Step 4: Implement match-players.ts**

Firestore `onWrite` trigger on `matchmaking_queue`. When doc count >= 4, pull closest-ELO group, create game doc, deal cards to `private/{uid}` subcollections, remove from queue.

- [ ] **Step 5: Run tests with emulator**
- [ ] **Step 6: Commit**

```bash
git add functions/src/matchmaking/ functions/test/matchmaking/ functions/src/index.ts
git commit -m "feat: add matchmaking trigger with ELO bracket matching and game creation"
```

---

### Task 6: Cloud Functions — placeBid & selectTrump

**Files:**
- Create: `functions/src/functions/place-bid.ts`
- Create: `functions/src/functions/select-trump.ts`
- Create: `functions/test/functions/place-bid.test.ts`
- Create: `functions/test/functions/select-trump.test.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Write placeBid tests**

Tests: valid bid accepted, bid not higher rejected, pass recorded permanently, 3 passes → bidding complete, all 4 pass → reshuffle, double all-pass → Malzoom forced bid, player not in game rejected, wrong turn rejected.

- [ ] **Step 2: Implement placeBid**

Uses Firestore transaction: read game doc, validate with bid-validator, update biddingState, check completion/malzoom, write atomically.

- [ ] **Step 3: Write selectTrump tests**

Tests: valid suit accepted, non-bidder rejected, invalid suit rejected, transitions to PLAYING, sets currentPlayer to seat after bid winner.

- [ ] **Step 4: Implement selectTrump**
- [ ] **Step 5: Run tests with emulator**
- [ ] **Step 6: Commit**

```bash
git add functions/src/functions/place-bid.ts functions/src/functions/select-trump.ts functions/test/functions/ functions/src/index.ts
git commit -m "feat: add placeBid and selectTrump cloud functions with full validation"
```

---

### Task 7: Cloud Functions — playCard & getMyHand

**Files:**
- Create: `functions/src/functions/play-card.ts`
- Create: `functions/src/functions/get-my-hand.ts`
- Create: `functions/test/functions/play-card.test.ts`
- Create: `functions/test/functions/get-my-hand.test.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Write playCard tests**

Tests: valid play accepted and card removed from hand, suit-following enforced, joker cannot lead, poison joker pre-check triggers round end with +10, trick resolution after 4 plays, trick winner becomes next leader, after 8 tricks → ROUND_SCORING with correct score, Kout success → GAME_OVER.

- [ ] **Step 2: Implement playCard**

Transaction: read game doc + `private/{uid}`, poison joker pre-check, validate play, remove card from hand, add to currentTrick, if 4 plays → resolve trick → update tricks count → if 8 tricks → score round → check game over.

- [ ] **Step 3: Write getMyHand tests**
- [ ] **Step 4: Implement getMyHand**
- [ ] **Step 5: Run tests with emulator**
- [ ] **Step 6: Commit**

```bash
git add functions/src/functions/ functions/test/functions/ functions/src/index.ts
git commit -m "feat: add playCard and getMyHand cloud functions with trick resolution and scoring"
```

---

### Task 8: Full Game Integration Test

**Files:**
- Create: `functions/test/integration/full-game.test.ts`

- [ ] **Step 1: Write full game E2E test**

Uses Firebase Emulator: 4 authenticated users → join queue → matchmaking creates game → all 4 retrieve hands → bidding round (player bids 5, others pass) → trump selection → play 8 tricks → round scored → verify scores.

- [ ] **Step 2: Write edge case tests**

Malzoom flow, Poison Joker mid-game, Kout instant win, disconnection forfeit.

- [ ] **Step 3: Run full test suite**

Run: `cd functions && npm run test:emulator`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add functions/test/integration/
git commit -m "test: add full game integration test with emulator covering matchmaking through scoring"
```

---

### Task 9: Rate Limiting Middleware

**Files:**
- Create: `functions/src/utils/rate-limiter.ts`
- Modify: `functions/src/utils/auth.ts`

- [ ] **Step 1: Implement rate limiter**

```typescript
// functions/src/utils/rate-limiter.ts
const userActionTimestamps = new Map<string, number[]>();

const MAX_ACTIONS_PER_SECOND = 2;
const WINDOW_MS = 1000;

export function checkRateLimit(uid: string): void {
  const now = Date.now();
  const timestamps = userActionTimestamps.get(uid) ?? [];

  // Remove entries outside the window
  const recent = timestamps.filter((t) => now - t < WINDOW_MS);

  if (recent.length >= MAX_ACTIONS_PER_SECOND) {
    throw new HttpsError('resource-exhausted', 'Rate limit exceeded: max 2 actions per second');
  }

  recent.push(now);
  userActionTimestamps.set(uid, recent);
}
```

- [ ] **Step 2: Integrate into all mutation functions**

Add `checkRateLimit(uid)` call at the top of `placeBid`, `selectTrump`, and `playCard` (after auth check, before game logic).

- [ ] **Step 3: Write rate limiter tests**

Tests: allows 2 actions in 1 second, rejects 3rd action within 1 second, allows actions after window expires.

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

```bash
git add functions/src/utils/rate-limiter.ts functions/test/
git commit -m "feat: add per-user rate limiting middleware (2 actions/sec)"
```

---

### Task 10: Presence Monitoring & Disconnect Handling

**Files:**
- Create: `functions/src/presence/presence-monitor.ts`
- Create: `functions/src/presence/disconnect-handler.ts`
- Create: `functions/test/presence/presence-monitor.test.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Implement presence monitor trigger**

```typescript
// functions/src/presence/presence-monitor.ts
import { onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Triggered when a presence doc is deleted (TTL expiry or manual delete)
export const onPresenceExpired = onDocumentDeleted(
  'games/{gameId}/presence/{uid}',
  async (event) => {
    const { gameId, uid } = event.params;
    const db = getFirestore();
    const gameRef = db.collection('games').doc(gameId);

    // Set a disconnect timer doc — if not cancelled within 90s, forfeit
    await db.collection('games').doc(gameId).collection('disconnect_timers').doc(uid).set({
      uid,
      disconnectedAt: FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 90_000),
    });
  }
);
```

- [ ] **Step 2: Implement disconnect handler (scheduled check)**

Uses a Cloud Function that checks `disconnect_timers` subcollection. If a timer has expired (90s passed) and the player hasn't reconnected (no presence doc), forfeit the game for their team.

```typescript
// functions/src/presence/disconnect-handler.ts
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore } from 'firebase-admin/firestore';
import { BID_FAILURE_POINTS, POISON_JOKER_PENALTY } from '../game/types';

export const checkDisconnectTimers = onSchedule('every 1 minutes', async () => {
  const db = getFirestore();
  const now = new Date();

  // Find all expired disconnect timers
  const expired = await db.collectionGroup('disconnect_timers')
    .where('expiresAt', '<=', now)
    .get();

  for (const timerDoc of expired.docs) {
    const { uid } = timerDoc.data();
    const gameId = timerDoc.ref.parent.parent!.id;
    const gameRef = db.collection('games').doc(gameId);

    await db.runTransaction(async (txn) => {
      const gameDoc = await txn.get(gameRef);
      if (!gameDoc.exists) return;
      const game = gameDoc.data()!;

      // Check if player reconnected (presence doc exists again)
      const presenceDoc = await txn.get(
        gameRef.collection('presence').doc(uid)
      );
      if (presenceDoc.exists) {
        // Player reconnected — cancel timer
        txn.delete(timerDoc.ref);
        return;
      }

      // Player still disconnected — forfeit
      const playerIndex = (game.players as string[]).indexOf(uid);
      const disconnectedTeam = playerIndex % 2 === 0 ? 'teamA' : 'teamB';
      const opponentTeam = disconnectedTeam === 'teamA' ? 'teamB' : 'teamA';

      // Determine penalty based on phase
      let penalty = 10; // default: equivalent to bid-5 failure
      if (game.bid?.amount) {
        penalty = BID_FAILURE_POINTS[game.bid.amount] ?? 10;
      }

      const newScores = { ...game.scores };
      newScores[opponentTeam] = (newScores[opponentTeam] ?? 0) + penalty;

      txn.update(gameRef, {
        phase: 'GAME_OVER',
        scores: newScores,
        'metadata.status': 'forfeited',
        'metadata.disconnectedPlayer': uid,
      });

      txn.delete(timerDoc.ref);
    });
  }
});
```

- [ ] **Step 3: Write presence monitor tests**

Tests: presence doc deleted → disconnect timer created, reconnection within 90s → timer cancelled, no reconnection after 90s → game forfeited with correct penalty (bidding phase vs playing phase).

- [ ] **Step 4: Export from index.ts**
- [ ] **Step 5: Run tests with emulator**
- [ ] **Step 6: Commit**

```bash
git add functions/src/presence/ functions/test/presence/ functions/src/index.ts
git commit -m "feat: add presence monitoring with disconnect detection and 90-second forfeit timer"
```

---

### Task 11: Matchmaking Bracket Expansion

**Files:**
- Modify: `functions/src/matchmaking/match-players.ts`

- [ ] **Step 1: Update matchmaking with time-based bracket expansion**

```typescript
// In match-players.ts — bracket expansion logic
function calculateBracket(queuedAt: Date): number {
  const waitTimeMs = Date.now() - queuedAt.getTime();
  const waitTimeSec = waitTimeMs / 1000;

  // Start at ±200, expand by 100 every 15 seconds, cap at ±500
  const expansions = Math.floor(waitTimeSec / 15);
  return Math.min(200 + (expansions * 100), 500);
}

function findBestMatch(queuedPlayers: QueueEntry[]): QueueEntry[] | null {
  // Sort by queue time (oldest first get priority)
  const sorted = [...queuedPlayers].sort((a, b) =>
    a.queuedAt.getTime() - b.queuedAt.getTime()
  );

  for (const anchor of sorted) {
    const bracket = calculateBracket(anchor.queuedAt);
    const candidates = sorted.filter(
      (p) => p.uid !== anchor.uid &&
             Math.abs(p.eloRating - anchor.eloRating) <= bracket
    );

    if (candidates.length >= 3) {
      // Pick the 3 closest ELO to anchor
      candidates.sort((a, b) =>
        Math.abs(a.eloRating - anchor.eloRating) -
        Math.abs(b.eloRating - anchor.eloRating)
      );
      return [anchor, ...candidates.slice(0, 3)];
    }
  }

  return null; // Not enough players in any bracket
}
```

- [ ] **Step 2: Write bracket expansion tests**

Tests: 4 players within ±200 match immediately, players outside ±200 don't match until wait time expands bracket, bracket caps at ±500, oldest player gets priority for bracket expansion.

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add functions/src/matchmaking/match-players.ts functions/test/matchmaking/
git commit -m "feat: add time-based ELO bracket expansion to matchmaking (±200 to ±500)"
```

---

## Summary

11 tasks. Produces:
- Complete TypeScript Cloud Functions backend (6 callables + 1 trigger)
- Firestore security rules
- ELO system
- Matchmaking with bracket expansion
- Full emulator test suite
- Depends on Plan 1 for rule understanding (logic is reimplemented in TS)
