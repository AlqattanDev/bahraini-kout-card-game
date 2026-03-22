import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';
import { GameDocument, BiddingState } from '../game/types';
import {
  validateBid,
  validatePass,
  checkBiddingComplete,
  checkMalzoom,
} from '../game/bid-validator';

export interface PlaceBidInput {
  gameId: string;
  bidAmount: number;
}

export interface PlaceBidResult {
  status: string;
}

/**
 * Returns the next player clockwise from currentIndex, skipping passed players.
 */
function nextBidder(players: string[], currentIndex: number, passed: string[]): string {
  const total = players.length;
  for (let i = 1; i < total; i++) {
    const idx = (currentIndex + i) % total;
    if (!passed.includes(players[idx])) {
      return players[idx];
    }
  }
  // Fallback — should not happen in normal flow
  return players[(currentIndex + 1) % total];
}

/**
 * Core bidding logic — extracted for testability.
 */
export async function placeBidLogic(
  uid: string,
  gameId: string,
  bidAmount: number,
  db: FirebaseFirestore.Firestore
): Promise<PlaceBidResult> {
  const gameRef = db.collection('games').doc(gameId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(gameRef);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Game not found');
    }

    const game = snap.data() as GameDocument;

    if (game.phase !== 'BIDDING') {
      throw new HttpsError('failed-precondition', 'Game is not in BIDDING phase');
    }

    const biddingState = game.biddingState as BiddingState;

    if (biddingState.currentBidder !== uid) {
      throw new HttpsError('failed-precondition', 'Not your turn to bid');
    }

    const isPass = bidAmount === 0;

    if (isPass) {
      const validation = validatePass(biddingState.passed, uid);
      if (!validation.valid) {
        throw new HttpsError('failed-precondition', validation.error ?? 'Cannot pass');
      }

      const newPassed = [...biddingState.passed, uid];

      // Check malzoom (all 4 passed)
      const malzoomOutcome = checkMalzoom(newPassed, game.reshuffleCount);

      if (malzoomOutcome === 'reshuffle') {
        // Reshuffle: reset to DEALING phase
        tx.update(gameRef, {
          phase: 'DEALING',
          reshuffleCount: game.reshuffleCount + 1,
          biddingState: null,
          bid: null,
          trumpSuit: null,
          currentTrick: null,
          tricks: { teamA: 0, teamB: 0 },
        });
        return { status: 'reshuffle' };
      }

      if (malzoomOutcome === 'forcedBid') {
        // Malzoom forced bid: dealer must bid 5
        tx.update(gameRef, {
          phase: 'TRUMP_SELECTION',
          bid: { player: game.dealer, amount: 5 },
          biddingState: {
            ...biddingState,
            passed: newPassed,
            highestBid: 5,
            highestBidder: game.dealer,
          },
        });
        return { status: 'forced-bid' };
      }

      // Check bidding complete (3 passes with a winner)
      const complete = checkBiddingComplete(
        newPassed,
        biddingState.highestBid,
        biddingState.highestBidder
      );

      if (complete.complete) {
        tx.update(gameRef, {
          phase: 'TRUMP_SELECTION',
          bid: { player: complete.winner, amount: complete.bid },
          biddingState: {
            ...biddingState,
            passed: newPassed,
          },
        });
        return { status: 'bidding-complete' };
      }

      // Advance currentBidder clockwise, skipping passed players
      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = nextBidder(game.players, currentIndex, newPassed);

      tx.update(gameRef, {
        biddingState: {
          ...biddingState,
          passed: newPassed,
          currentBidder: nextPlayer,
        },
      });

      return { status: 'passed' };
    } else {
      // Placing a bid
      const validation = validateBid(
        bidAmount,
        biddingState.highestBid,
        biddingState.passed,
        uid
      );
      if (!validation.valid) {
        throw new HttpsError('failed-precondition', validation.error ?? 'Invalid bid');
      }

      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = nextBidder(game.players, currentIndex, biddingState.passed);

      tx.update(gameRef, {
        biddingState: {
          ...biddingState,
          highestBid: bidAmount,
          highestBidder: uid,
          currentBidder: nextPlayer,
        },
      });

      return { status: 'bid-placed' };
    }
  });
}

export const placeBid = onCall(async (request) => {
  const uid = requireAuth(request);
  const { gameId, bidAmount } = request.data as PlaceBidInput;
  const db = getFirestore();
  return placeBidLogic(uid, gameId, bidAmount, db);
});
