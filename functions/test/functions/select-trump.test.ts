import { selectTrumpLogic } from '../../src/functions/select-trump';
import { GameDocument } from '../../src/game/types';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeGame(overrides: Partial<GameDocument> = {}): GameDocument {
  const players = ['p0', 'p1', 'p2', 'p3'];
  return {
    phase: 'TRUMP_SELECTION',
    players,
    currentTrick: null,
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: { player: 'p0', amount: 5 },
    biddingState: null,
    trumpSuit: null,
    dealer: 'p3',
    currentPlayer: 'p0',
    reshuffleCount: 0,
    roundHistory: [],
    metadata: { createdAt: {} as any, status: 'active' },
    ...overrides,
  };
}

type UpdateData = Record<string, unknown>;

function makeDbMock(game: GameDocument) {
  const updates: UpdateData[] = [];
  const gameSnap = { exists: true, data: () => ({ ...game }) };

  const transactionMock = {
    get: jest.fn().mockResolvedValue(gameSnap),
    update: jest.fn((_ref: unknown, data: UpdateData) => {
      updates.push(data);
    }),
  };

  const gameRef = { id: 'game1' };

  const db = {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue(gameRef),
    }),
    runTransaction: jest.fn().mockImplementation(async (fn: (tx: typeof transactionMock) => Promise<unknown>) => {
      return fn(transactionMock);
    }),
    _updates: updates,
    _tx: transactionMock,
  } as unknown as FirebaseFirestore.Firestore;

  return { db, updates, tx: transactionMock };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('selectTrumpLogic', () => {
  it('valid suit accepted and transitions to PLAYING', async () => {
    const game = makeGame();
    const { db, tx } = makeDbMock(game);

    const result = await selectTrumpLogic('p0', 'game1', 'spades', db);

    expect(result.status).toBe('trump-selected');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        phase: 'PLAYING',
        trumpSuit: 'spades',
      })
    );
  });

  it('non-bidder is rejected', async () => {
    const game = makeGame({ bid: { player: 'p0', amount: 5 } });
    const { db } = makeDbMock(game);

    await expect(selectTrumpLogic('p1', 'game1', 'hearts', db)).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  it('invalid suit is rejected', async () => {
    const game = makeGame();
    const { db } = makeDbMock(game);

    await expect(selectTrumpLogic('p0', 'game1', 'jokers', db)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });

  it('sets currentPlayer to seat after bid winner (clockwise)', async () => {
    // p0 is bid winner → next clockwise is p1
    const game = makeGame({ bid: { player: 'p0', amount: 5 }, players: ['p0', 'p1', 'p2', 'p3'] });
    const { db, tx } = makeDbMock(game);

    await selectTrumpLogic('p0', 'game1', 'hearts', db);

    const updateArg = tx.update.mock.calls[0][1] as UpdateData;
    expect(updateArg.currentPlayer).toBe('p1');
  });

  it('sets currentPlayer correctly when bid winner is the last player (wraps around)', async () => {
    // p3 is bid winner → next clockwise is p0
    const game = makeGame({ bid: { player: 'p3', amount: 5 }, players: ['p0', 'p1', 'p2', 'p3'] });
    const { db, tx } = makeDbMock(game);

    await selectTrumpLogic('p3', 'game1', 'clubs', db);

    const updateArg = tx.update.mock.calls[0][1] as UpdateData;
    expect(updateArg.currentPlayer).toBe('p0');
  });

  it('rejects when phase is not TRUMP_SELECTION', async () => {
    const game = makeGame({ phase: 'PLAYING' });
    const { db } = makeDbMock(game);

    await expect(selectTrumpLogic('p0', 'game1', 'diamonds', db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('accepts all valid suits', async () => {
    for (const suit of ['spades', 'hearts', 'clubs', 'diamonds']) {
      const game = makeGame();
      const { db } = makeDbMock(game);
      const result = await selectTrumpLogic('p0', 'game1', suit, db);
      expect(result.status).toBe('trump-selected');
    }
  });
});
