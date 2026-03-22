import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';

/** Business logic extracted for testability */
export async function leaveQueueLogic(
  uid: string,
  db: FirebaseFirestore.Firestore
): Promise<{ status: string }> {
  const queueRef = db.collection('matchmaking_queue').doc(uid);
  const existing = await queueRef.get();
  if (!existing.exists) {
    throw new HttpsError('not-found', 'Not in queue');
  }
  await queueRef.delete();
  return { status: 'dequeued' };
}

export const leaveQueue = onCall(async (request) => {
  const uid = requireAuth(request);
  const db = getFirestore();
  return leaveQueueLogic(uid, db);
});
