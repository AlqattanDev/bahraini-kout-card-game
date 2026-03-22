import { placeBidLogic } from '../../src/functions/place-bid';
import { GameDocument, BiddingState } from '../../src/game/types';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeGame(overrides: Partial<GameDocument> = {}): GameDocument {
  const players = ['p0', 'p1', 'p2', 'p3'];
  const defaultBiddingState: BiddingState = {
    currentBidder: 'p0',
    highestBid: null,
    highestBidder: null,
    passed: [],
  };
  return {
    phase: 'BIDDING',
    players,
    currentTrick: null,
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: null,
    biddingState: defaultBiddingState,
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

describe('placeBidLogic', () => {
  it('valid bid accepted (updates biddingState with new highest bid)', async () => {
    const game = makeGame();
    const { db, tx } = makeDbMock(game);

    const result = await placeBidLogic('p0', 'game1', 5, db);

    expect(result.status).toBe('bid-placed');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        biddingState: expect.objectContaining({
          highestBid: 5,
          highestBidder: 'p0',
        }),
      })
    );
  });

  it('bid not higher than current highest is rejected', async () => {
    const game = makeGame({
      biddingState: {
        currentBidder: 'p1',
        highestBid: 6,
        highestBidder: 'p0',
        passed: [],
      },
    });
    const { db } = makeDbMock(game);

    await expect(placeBidLogic('p1', 'game1', 5, db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('bid equal to current highest is rejected', async () => {
    const game = makeGame({
      biddingState: {
        currentBidder: 'p1',
        highestBid: 6,
        highestBidder: 'p0',
        passed: [],
      },
    });
    const { db } = makeDbMock(game);

    await expect(placeBidLogic('p1', 'game1', 6, db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('pass is recorded permanently (added to passed array)', async () => {
    const game = makeGame({
      biddingState: {
        currentBidder: 'p0',
        highestBid: 5,
        highestBidder: 'p1',
        passed: [],
      },
    });
    const { db, tx } = makeDbMock(game);

    const result = await placeBidLogic('p0', 'game1', 0, db);

    expect(result.status).toBe('passed');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        biddingState: expect.objectContaining({
          passed: ['p0'],
        }),
      })
    );
  });

  it('3 passes transitions to TRUMP_SELECTION', async () => {
    // p0 bid 5, p1 p2 p3 pass → bidding complete
    const game = makeGame({
      biddingState: {
        currentBidder: 'p3',
        highestBid: 5,
        highestBidder: 'p0',
        passed: ['p1', 'p2'],
      },
    });
    const { db, tx } = makeDbMock(game);

    const result = await placeBidLogic('p3', 'game1', 0, db);

    expect(result.status).toBe('bidding-complete');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        phase: 'TRUMP_SELECTION',
        bid: { player: 'p0', amount: 5 },
      })
    );
  });

  it('all 4 pass → reshuffle (phase to DEALING, reshuffleCount++)', async () => {
    // p0, p1, p2 already passed, p3 passes now
    const game = makeGame({
      biddingState: {
        currentBidder: 'p3',
        highestBid: null,
        highestBidder: null,
        passed: ['p0', 'p1', 'p2'],
      },
      reshuffleCount: 0,
    });
    const { db, tx } = makeDbMock(game);

    const result = await placeBidLogic('p3', 'game1', 0, db);

    expect(result.status).toBe('reshuffle');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        phase: 'DEALING',
        reshuffleCount: 1,
      })
    );
  });

  it('double all-pass → Malzoom forced bid (dealer bids 5, phase to TRUMP_SELECTION)', async () => {
    // reshuffleCount >= 1 → forcedBid
    const game = makeGame({
      biddingState: {
        currentBidder: 'p3',
        highestBid: null,
        highestBidder: null,
        passed: ['p0', 'p1', 'p2'],
      },
      reshuffleCount: 1,
      dealer: 'p3',
    });
    const { db, tx } = makeDbMock(game);

    const result = await placeBidLogic('p3', 'game1', 0, db);

    expect(result.status).toBe('forced-bid');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        phase: 'TRUMP_SELECTION',
        bid: { player: 'p3', amount: 5 },
      })
    );
  });

  it('wrong turn is rejected', async () => {
    const game = makeGame({
      biddingState: {
        currentBidder: 'p0',
        highestBid: null,
        highestBidder: null,
        passed: [],
      },
    });
    const { db } = makeDbMock(game);

    await expect(placeBidLogic('p1', 'game1', 5, db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('player already passed cannot bid again', async () => {
    const game = makeGame({
      biddingState: {
        currentBidder: 'p0',
        highestBid: 5,
        highestBidder: 'p1',
        passed: ['p0'],
      },
    });
    // We override currentBidder to p0 to simulate wrong state (already passed)
    const { db } = makeDbMock(game);

    await expect(placeBidLogic('p0', 'game1', 6, db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('rejects bid when game phase is not BIDDING', async () => {
    const game = makeGame({ phase: 'PLAYING' });
    const { db } = makeDbMock(game);

    await expect(placeBidLogic('p0', 'game1', 5, db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('next bidder advances clockwise', async () => {
    const game = makeGame({
      biddingState: {
        currentBidder: 'p0',
        highestBid: null,
        highestBidder: null,
        passed: [],
      },
    });
    const { db, tx } = makeDbMock(game);

    await placeBidLogic('p0', 'game1', 5, db);

    const updateArg = tx.update.mock.calls[0][1] as { biddingState: BiddingState };
    expect(updateArg.biddingState.currentBidder).toBe('p1');
  });
});
