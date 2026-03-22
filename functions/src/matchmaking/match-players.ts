import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { buildFourPlayerDeck, dealHands } from '../game/deck';
import { GameDocument } from '../game/types';

export interface QueuedPlayer {
  uid: string;
  eloRating: number;
  queuedAt: { toDate(): Date } | Date;
}

/**
 * Find the group of 4 closest-ELO players among candidates.
 * Candidates must be sorted by queuedAt ascending before calling this.
 * Returns the 4 players from the window of 4 consecutive players
 * (sorted by ELO) with the smallest ELO spread.
 */
export function findBestGroup(players: QueuedPlayer[]): QueuedPlayer[] | null {
  if (players.length < 4) return null;

  const sorted = [...players].sort((a, b) => a.eloRating - b.eloRating);

  let bestWindow: QueuedPlayer[] = sorted.slice(0, 4);
  let bestSpread = sorted[3].eloRating - sorted[0].eloRating;

  for (let i = 1; i <= sorted.length - 4; i++) {
    const window = sorted.slice(i, i + 4);
    const spread = window[3].eloRating - window[0].eloRating;
    if (spread < bestSpread) {
      bestSpread = spread;
      bestWindow = window;
    }
  }

  return bestWindow;
}

/**
 * Calculate the ELO bracket half-width for a player based on how long they
 * have been waiting in the queue.
 *
 * Starts at ±200, expands by ±100 every 15 seconds, capped at ±500.
 * Examples:
 *   0–14s  → 200
 *   15–29s → 300
 *   30–44s → 400
 *   45+s   → 500 (cap)
 */
export function calculateBracket(queuedAt: Date): number {
  const waitTimeMs = Date.now() - queuedAt.getTime();
  const waitTimeSec = waitTimeMs / 1000;
  const expansions = Math.floor(waitTimeSec / 15);
  return Math.min(200 + expansions * 100, 500);
}

/**
 * Find the best group of 4 players using time-based ELO bracket expansion.
 *
 * A group is valid when all 4 players' ELO ratings fall within the bracket
 * of the player who has waited the longest (i.e. who has the widest bracket).
 *
 * Algorithm:
 * 1. Sort by ELO.
 * 2. For each window of 4 consecutive ELO-sorted players, check whether the
 *    ELO spread is within the widest bracket among those 4 players.
 * 3. Among all valid windows, return the one with the smallest spread.
 *
 * Returns null if no valid group of 4 exists.
 */
export function findBestMatch(players: QueuedPlayer[]): QueuedPlayer[] | null {
  if (players.length < 4) return null;

  const sorted = [...players].sort((a, b) => a.eloRating - b.eloRating);

  let bestWindow: QueuedPlayer[] | null = null;
  let bestSpread = Infinity;

  for (let i = 0; i <= sorted.length - 4; i++) {
    const window = sorted.slice(i, i + 4);
    const spread = window[3].eloRating - window[0].eloRating;

    // The effective bracket is the largest bracket among the 4 candidates
    const maxBracket = Math.max(
      ...window.map((p) => {
        const queuedAt = p.queuedAt instanceof Date ? p.queuedAt : p.queuedAt.toDate();
        return calculateBracket(queuedAt);
      })
    );

    // The group is compatible if the ELO spread fits within the widest bracket
    if (spread <= maxBracket * 2 && spread < bestSpread) {
      bestSpread = spread;
      bestWindow = window;
    }
  }

  return bestWindow;
}

/**
 * Shuffle an array of seats [0,1,2,3] and assign to players.
 * Returns a record of uid -> seat index.
 */
export function assignSeats(players: QueuedPlayer[]): Record<string, number> {
  const seats = [0, 1, 2, 3];
  // Fisher-Yates shuffle
  for (let i = seats.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [seats[i], seats[j]] = [seats[j], seats[i]];
  }
  const assignment: Record<string, number> = {};
  players.forEach((p, idx) => {
    assignment[p.uid] = seats[idx];
  });
  return assignment;
}

/**
 * Build a GameDocument for a new game given 4 players in seat order.
 * playersInSeatOrder[seat] = uid
 */
export function buildGameDocument(playersInSeatOrder: string[]): GameDocument {
  const dealer = playersInSeatOrder[0];
  const firstBidder = playersInSeatOrder[1];
  return {
    phase: 'WAITING',
    players: playersInSeatOrder,
    currentTrick: null,
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: null,
    biddingState: {
      currentBidder: firstBidder,
      highestBid: null,
      highestBidder: null,
      passed: [],
    },
    trumpSuit: null,
    dealer,
    currentPlayer: firstBidder,
    reshuffleCount: 0,
    roundHistory: [],
    metadata: {
      createdAt: FieldValue.serverTimestamp() as unknown as import('firebase-admin/firestore').Timestamp,
      status: 'active',
    },
  };
}

/**
 * Core matchmaking logic — extracted for unit testing.
 * Takes an array of all queued players, returns the match data to create
 * (game doc + hands + uids to remove from queue), or null if no match possible.
 */
export function computeMatch(allPlayers: QueuedPlayer[]): {
  group: QueuedPlayer[];
  seatAssignment: Record<string, number>;
  playersInSeatOrder: string[];
  hands: ReturnType<typeof dealHands>;
} | null {
  // Sort by queue time so oldest waiters get priority
  const byTime = [...allPlayers].sort((a, b) => {
    const aTime = a.queuedAt instanceof Date ? a.queuedAt : a.queuedAt.toDate();
    const bTime = b.queuedAt instanceof Date ? b.queuedAt : b.queuedAt.toDate();
    return aTime.getTime() - bTime.getTime();
  });

  const group = findBestMatch(byTime);
  if (!group) return null;

  const seatAssignment = assignSeats(group);

  // Build seat-ordered player list
  const playersInSeatOrder = new Array<string>(4);
  for (const [uid, seat] of Object.entries(seatAssignment)) {
    playersInSeatOrder[seat] = uid;
  }

  const deck = buildFourPlayerDeck();
  const hands = dealHands(deck);

  return { group, seatAssignment, playersInSeatOrder, hands };
}

/** Cloud Function trigger */
export const matchPlayers = onDocumentCreated(
  'matchmaking_queue/{uid}',
  async (_event) => {
    const db = getFirestore();
    const snapshot = await db.collection('matchmaking_queue').get();
    const allPlayers: QueuedPlayer[] = snapshot.docs.map((doc) => doc.data() as QueuedPlayer);

    const result = computeMatch(allPlayers);
    if (!result) return;

    const { group, playersInSeatOrder, hands } = result;

    // Write everything in a batch
    const batch = db.batch();

    // Create game document
    const gameRef = db.collection('games').doc();
    const gameDoc = buildGameDocument(playersInSeatOrder);
    batch.set(gameRef, gameDoc);

    // Deal cards to private subcollections
    playersInSeatOrder.forEach((uid, seat) => {
      const handRef = gameRef.collection('private').doc(uid);
      batch.set(handRef, {
        hand: hands[seat].map((c) => c.code),
      });
    });

    // Remove matched players from queue
    for (const player of group) {
      const queueRef = db.collection('matchmaking_queue').doc(player.uid);
      batch.delete(queueRef);
    }

    await batch.commit();
  }
);
