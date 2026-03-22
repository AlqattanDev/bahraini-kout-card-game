import { playCardLogic } from '../../src/functions/play-card';
import { GameDocument, TrickPlay } from '../../src/game/types';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeGame(overrides: Partial<GameDocument> = {}): GameDocument {
  const players = ['p0', 'p1', 'p2', 'p3'];
  return {
    phase: 'PLAYING',
    players,
    currentTrick: { lead: 'p0', plays: [] },
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: { player: 'p0', amount: 5 },
    biddingState: null,
    trumpSuit: 'spades',
    dealer: 'p3',
    currentPlayer: 'p0',
    reshuffleCount: 0,
    roundHistory: [],
    metadata: { createdAt: {} as any, status: 'active' },
    ...overrides,
  };
}

type UpdateData = Record<string, unknown>;

function makeDbMock(game: GameDocument, hand: string[]) {
  const updates: Map<unknown, UpdateData> = new Map();

  const gameRef = { _id: 'game', _type: 'game' };
  const handRef = { _id: 'hand', _type: 'hand' };

  const gameSnap = { exists: true, data: () => ({ ...game }) };
  const handSnap = { exists: true, data: () => ({ hand: [...hand] }) };

  const transactionMock = {
    get: jest.fn().mockImplementation((ref: typeof gameRef | typeof handRef) => {
      if ((ref as typeof gameRef)._type === 'hand') return Promise.resolve(handSnap);
      return Promise.resolve(gameSnap);
    }),
    update: jest.fn((_ref: unknown, data: UpdateData) => {
      updates.set(_ref, data);
    }),
  };

  // A subcollection mock: collection('private').doc(uid) returns handRef
  const privateCollection = {
    doc: jest.fn().mockReturnValue(handRef),
  };

  const gameDocRef = {
    ...gameRef,
    collection: jest.fn().mockReturnValue(privateCollection),
  };

  const db = {
    collection: jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue(gameDocRef),
    }),
    runTransaction: jest.fn().mockImplementation(
      async (fn: (tx: typeof transactionMock) => Promise<unknown>) => fn(transactionMock)
    ),
    _updates: updates,
    _tx: transactionMock,
  } as unknown as FirebaseFirestore.Firestore;

  return { db, updates, tx: transactionMock };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('playCardLogic', () => {
  it('valid play accepted, card removed from hand', async () => {
    const game = makeGame({ currentPlayer: 'p0' });
    const hand = ['SA', 'HK', 'CQ'];
    const { db, tx } = makeDbMock(game, hand);

    const result = await playCardLogic('p0', 'game1', 'SA', db);

    expect(result.status).toBe('card-played');
    // Hand update should exclude 'SA'
    const handUpdateCalls = tx.update.mock.calls.filter((c: unknown[]) => {
      const data = c[1] as UpdateData;
      return 'hand' in data;
    });
    expect(handUpdateCalls.length).toBe(1);
    expect((handUpdateCalls[0][1] as { hand: string[] }).hand).not.toContain('SA');
    expect((handUpdateCalls[0][1] as { hand: string[] }).hand).toContain('HK');
  });

  it('suit-following enforced — must follow led suit if possible', async () => {
    // p1's turn, led suit is hearts, p1 has hearts
    const game = makeGame({
      currentPlayer: 'p1',
      currentTrick: {
        lead: 'p0',
        plays: [{ player: 'p0', card: 'HK' }],
      },
    });
    const hand = ['HA', 'SA'];  // Has hearts, must follow
    const { db } = makeDbMock(game, hand);

    await expect(playCardLogic('p1', 'game1', 'SA', db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('joker cannot lead a trick', async () => {
    const game = makeGame({
      currentPlayer: 'p0',
      currentTrick: { lead: 'p0', plays: [] },
    });
    const hand = ['JO', 'SA'];
    const { db } = makeDbMock(game, hand);

    await expect(playCardLogic('p0', 'game1', 'JO', db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('card not in hand is rejected', async () => {
    const game = makeGame({ currentPlayer: 'p0' });
    const hand = ['HK', 'CQ'];
    const { db } = makeDbMock(game, hand);

    await expect(playCardLogic('p0', 'game1', 'SA', db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('poison joker pre-check: only card is joker → triggers round end with +10', async () => {
    const game = makeGame({ currentPlayer: 'p0' });
    const hand = ['JO'];  // Only one card and it's a joker → poison joker
    const { db, tx } = makeDbMock(game, hand);

    const result = await playCardLogic('p0', 'game1', 'JO', db);

    expect(result.status).toBe('poison-joker');
    expect(result.roundResult?.points).toBe(10);
    // p0 is even index (teamA) → opponent teamB wins
    expect(result.roundResult?.winningTeam).toBe('teamB');
    expect(tx.update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        phase: expect.stringMatching(/ROUND_SCORING|GAME_OVER/),
      })
    );
  });

  it('trick resolution after 4 plays — status is trick-won', async () => {
    // 3 plays already in trick; p3 plays the winning card
    const existingPlays: TrickPlay[] = [
      { player: 'p0', card: 'HK' },
      { player: 'p1', card: 'H9' },
      { player: 'p2', card: 'H7' },
    ];
    const game = makeGame({
      currentPlayer: 'p3',
      currentTrick: { lead: 'p0', plays: existingPlays },
      trumpSuit: 'spades',
    });
    const hand = ['HA'];
    const { db } = makeDbMock(game, hand);

    const result = await playCardLogic('p3', 'game1', 'HA', db);

    expect(result.status).toBe('trick-won');
    expect(result.trickWinner).toBeDefined();
  });

  it('trick winner becomes the next leader', async () => {
    // p0 plays ace of hearts leading, p1 p2 p3 play lower hearts
    const existingPlays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'p1', card: 'H9' },
      { player: 'p2', card: 'H7' },
    ];
    const game = makeGame({
      currentPlayer: 'p3',
      currentTrick: { lead: 'p0', plays: existingPlays },
      trumpSuit: 'spades',
      tricks: { teamA: 0, teamB: 0 },
    });
    const hand = ['H8'];
    const { db, tx } = makeDbMock(game, hand);

    const result = await playCardLogic('p3', 'game1', 'H8', db);

    expect(result.trickWinner).toBe('p0');  // HA wins

    const gameUpdateCalls = tx.update.mock.calls.filter((c: unknown[]) => {
      const data = c[1] as UpdateData;
      return 'currentTrick' in data && 'currentPlayer' in data;
    });
    expect(gameUpdateCalls.length).toBe(1);
    const updateData = gameUpdateCalls[0][1] as UpdateData;
    expect(updateData.currentPlayer).toBe('p0');
  });

  it('after 8 tricks → ROUND_SCORING with correct score', async () => {
    // 7 tricks already done, completing the 8th now
    // bid is 5, p0 (teamA) bid, 4 tricks already for teamA (need 5 to succeed)
    const existingPlays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'p1', card: 'H9' },
      { player: 'p2', card: 'H7' },
    ];
    // teamA has 4 tricks already, teamB 3 — 4+3=7 tricks done
    const game = makeGame({
      currentPlayer: 'p3',
      currentTrick: { lead: 'p0', plays: existingPlays },
      trumpSuit: 'spades',
      bid: { player: 'p0', amount: 5 },
      tricks: { teamA: 4, teamB: 3 },
      scores: { teamA: 0, teamB: 0 },
    });
    const hand = ['H8'];
    const { db, tx } = makeDbMock(game, hand);

    const result = await playCardLogic('p3', 'game1', 'H8', db);

    expect(result.status).toBe('round-complete');
    expect(result.roundResult).toBeDefined();
    // p0 wins the final trick with HA → teamA gets 5 tricks → bid of 5 succeeded
    expect(result.roundResult!.winningTeam).toBe('teamA');
    expect(result.roundResult!.points).toBe(5);  // BID_SUCCESS_POINTS[5] = 5

    const gameUpdateCalls = tx.update.mock.calls.filter((c: unknown[]) => {
      const data = c[1] as UpdateData;
      return 'phase' in data;
    });
    expect(gameUpdateCalls.length).toBe(1);
    const phaseUpdate = gameUpdateCalls[0][1] as UpdateData;
    expect(phaseUpdate.phase).toBe('ROUND_SCORING');
  });

  it('rejects when not player turn', async () => {
    const game = makeGame({ currentPlayer: 'p1' });
    const hand = ['SA'];
    const { db } = makeDbMock(game, hand);

    await expect(playCardLogic('p0', 'game1', 'SA', db)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('GAME_OVER triggered when score reaches 31', async () => {
    const existingPlays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'p1', card: 'H9' },
      { player: 'p2', card: 'H7' },
    ];
    const game = makeGame({
      currentPlayer: 'p3',
      currentTrick: { lead: 'p0', plays: existingPlays },
      trumpSuit: 'spades',
      bid: { player: 'p0', amount: 8 },
      tricks: { teamA: 7, teamB: 0 },
      scores: { teamA: 0, teamB: 0 },
    });
    const hand = ['H8'];
    const { db, tx } = makeDbMock(game, hand);

    const result = await playCardLogic('p3', 'game1', 'H8', db);

    expect(result.status).toBe('round-complete');
    // bid 8 success = 31 points → game over
    expect(result.gameOver).toBe(true);
    expect(result.gameWinner).toBe('teamA');

    const gameUpdateCalls = tx.update.mock.calls.filter((c: unknown[]) => {
      const data = c[1] as UpdateData;
      return 'phase' in data;
    });
    const phaseUpdate = gameUpdateCalls[0][1] as UpdateData;
    expect(phaseUpdate.phase).toBe('GAME_OVER');
  });
});
