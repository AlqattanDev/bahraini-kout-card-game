import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';
import { GameDocument, SuitName } from '../game/types';

export interface SelectTrumpInput {
  gameId: string;
  suit: string;
}

export interface SelectTrumpResult {
  status: string;
}

const VALID_SUITS: SuitName[] = ['spades', 'hearts', 'clubs', 'diamonds'];

/**
 * Returns the UID of the player seated clockwise after the given player.
 */
function nextPlayerClockwise(players: string[], currentUid: string): string {
  const idx = players.indexOf(currentUid);
  return players[(idx + 1) % players.length];
}

/**
 * Core select-trump logic — extracted for testability.
 */
export async function selectTrumpLogic(
  uid: string,
  gameId: string,
  suit: string,
  db: FirebaseFirestore.Firestore
): Promise<SelectTrumpResult> {
  const gameRef = db.collection('games').doc(gameId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Game not found');
    }

    const game = snap.data() as GameDocument;

    if (game.phase !== 'TRUMP_SELECTION') {
      throw new HttpsError('failed-precondition', 'Game is not in TRUMP_SELECTION phase');
    }

    if (!game.bid || game.bid.player !== uid) {
      throw new HttpsError('permission-denied', 'Only the winning bidder can select trump');
    }

    if (!VALID_SUITS.includes(suit as SuitName)) {
      throw new HttpsError('invalid-argument', `Invalid suit: ${suit}`);
    }

    const trumpSuit = suit as SuitName;
    const firstPlayer = nextPlayerClockwise(game.players, uid);

    tx.update(gameRef, {
      phase: 'PLAYING',
      trumpSuit,
      currentPlayer: firstPlayer,
      currentTrick: { lead: firstPlayer, plays: [] },
      tricks: { teamA: 0, teamB: 0 },
    });

    return { status: 'trump-selected' };
  });
}

export const selectTrump = onCall(async (request) => {
  const uid = requireAuth(request);
  const { gameId, suit } = request.data as SelectTrumpInput;
  const db = getFirestore();
  return selectTrumpLogic(uid, gameId, suit, db);
});
