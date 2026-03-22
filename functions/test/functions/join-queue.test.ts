import { HttpsError } from 'firebase-functions/v2/https';
import { joinQueueLogic } from '../../src/functions/join-queue';
import { leaveQueueLogic } from '../../src/functions/leave-queue';

/** Minimal Firestore document mock */
function makeDocMock(exists: boolean): { get: jest.Mock; set: jest.Mock; delete: jest.Mock } {
  return {
    get: jest.fn().mockResolvedValue({ exists }),
    set: jest.fn().mockResolvedValue(undefined),
    delete: jest.fn().mockResolvedValue(undefined),
  };
}

function makeDbMock(docExists: boolean) {
  const doc = makeDocMock(docExists);
  const db = {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue(doc),
    }),
    _doc: doc,
  } as unknown as FirebaseFirestore.Firestore;
  return { db, doc };
}

// ─── joinQueue tests ─────────────────────────────────────────────────────────

describe('joinQueueLogic', () => {
  it('adds player to queue and returns { status: "queued" }', async () => {
    const { db, doc } = makeDbMock(false);
    const result = await joinQueueLogic('user-abc', 1200, db);

    expect(result).toEqual({ status: 'queued' });
    expect(doc.set).toHaveBeenCalledWith(
      expect.objectContaining({ uid: 'user-abc', eloRating: 1200 })
    );
    // queuedAt should be a Date
    const setArg = doc.set.mock.calls[0][0];
    expect(setArg.queuedAt).toBeInstanceOf(Date);
  });

  it('rejects when eloRating is not a number', async () => {
    const { db } = makeDbMock(false);
    await expect(joinQueueLogic('user-abc', 'high', db)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });

  it('rejects with already-exists when player is already in queue', async () => {
    const { db } = makeDbMock(true);
    await expect(joinQueueLogic('user-abc', 1200, db)).rejects.toMatchObject({
      code: 'already-exists',
    });
  });

  it('rejects unauthenticated — requireAuth throws HttpsError with unauthenticated code', () => {
    // requireAuth is tested in isolation
    const { requireAuth } = jest.requireActual('../../src/utils/auth') as typeof import('../../src/utils/auth');
    const fakeRequest = { auth: undefined, data: {} } as Parameters<typeof requireAuth>[0];
    expect(() => requireAuth(fakeRequest)).toThrow(HttpsError);
    // HttpsError stores the code in .code, not in the message
    let thrown: HttpsError | undefined;
    try { requireAuth(fakeRequest); } catch (e) { thrown = e as HttpsError; }
    expect(thrown?.code).toBe('unauthenticated');
  });
});

// ─── leaveQueue tests ─────────────────────────────────────────────────────────

describe('leaveQueueLogic', () => {
  it('removes player from queue and returns { status: "dequeued" }', async () => {
    const { db, doc } = makeDbMock(true);
    const result = await leaveQueueLogic('user-abc', db);

    expect(result).toEqual({ status: 'dequeued' });
    expect(doc.delete).toHaveBeenCalled();
  });

  it('throws not-found when player is not in queue', async () => {
    const { db } = makeDbMock(false);
    await expect(leaveQueueLogic('user-abc', db)).rejects.toMatchObject({
      code: 'not-found',
    });
  });
});
