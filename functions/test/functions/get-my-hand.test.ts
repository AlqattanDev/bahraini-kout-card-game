import { getMyHandLogic } from '../../src/functions/get-my-hand';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeDbMock(hand: string[] | null) {
  const handSnap = hand === null
    ? { exists: false, data: () => undefined }
    : { exists: true, data: () => ({ hand }) };

  const handDocMock = {
    get: jest.fn().mockResolvedValue(handSnap),
  };

  const privateCollectionMock = {
    doc: jest.fn().mockReturnValue(handDocMock),
  };

  const gameDocMock = {
    collection: jest.fn().mockReturnValue(privateCollectionMock),
  };

  const db = {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue(gameDocMock),
    }),
  } as unknown as FirebaseFirestore.Firestore;

  return { db, handDocMock };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('getMyHandLogic', () => {
  it('returns hand for authenticated player', async () => {
    const expectedHand = ['SA', 'HK', 'CQ', 'DJ', 'S10'];
    const { db } = makeDbMock(expectedHand);

    const result = await getMyHandLogic('user-uid', 'game1', db);

    expect(result).toEqual({ hand: expectedHand });
  });

  it('returns empty array when hand is empty', async () => {
    const { db } = makeDbMock([]);

    const result = await getMyHandLogic('user-uid', 'game1', db);

    expect(result).toEqual({ hand: [] });
  });

  it('throws not-found when hand document does not exist', async () => {
    const { db } = makeDbMock(null);

    await expect(getMyHandLogic('user-uid', 'game1', db)).rejects.toMatchObject({
      code: 'not-found',
    });
  });

  it('queries the correct game and player document', async () => {
    const { db, handDocMock } = makeDbMock(['SA']);

    await getMyHandLogic('test-uid', 'game-abc', db);

    expect(db.collection).toHaveBeenCalledWith('games');
    expect(handDocMock.get).toHaveBeenCalled();
  });
});
