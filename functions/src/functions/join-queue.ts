import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';

export interface JoinQueueData {
  uid: string;
  eloRating: number;
  queuedAt: Date;
}

/** Business logic extracted for testability */
export async function joinQueueLogic(
  uid: string,
  eloRating: unknown,
  db: FirebaseFirestore.Firestore
): Promise<{ status: string }> {
  if (typeof eloRating !== 'number') {
    throw new HttpsError('invalid-argument', 'eloRating must be a number');
  }
  const queueRef = db.collection('matchmaking_queue').doc(uid);
  const existing = await queueRef.get();
  if (existing.exists) {
    throw new HttpsError('already-exists', 'Already in queue');
  }
  await queueRef.set({ uid, eloRating, queuedAt: new Date() });
  return { status: 'queued' };
}

export const joinQueue = onCall(async (request) => {
  const uid = requireAuth(request);
  const { eloRating } = request.data;
  const db = getFirestore();
  return joinQueueLogic(uid, eloRating, db);
});
