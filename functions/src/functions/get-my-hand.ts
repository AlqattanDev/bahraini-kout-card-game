import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';

export interface GetMyHandResult {
  hand: string[];
}

/**
 * Core get-my-hand logic — extracted for testability.
 */
export async function getMyHandLogic(
  uid: string,
  gameId: string,
  db: FirebaseFirestore.Firestore
): Promise<GetMyHandResult> {
  const handRef = db
    .collection('games')
    .doc(gameId)
    .collection('private')
    .doc(uid);

  const snap = await handRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Hand not found');
  }

  const data = snap.data() as { hand: string[] };
  return { hand: data.hand ?? [] };
}

export const getMyHand = onCall(async (request) => {
  const uid = requireAuth(request);
  const { gameId } = request.data as { gameId: string };
  const db = getFirestore();
  return getMyHandLogic(uid, gameId, db);
});
