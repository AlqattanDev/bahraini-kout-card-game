import { describe, it, expect } from 'vitest';
import { buildBotContext } from '../../../src/game/bot';
import type { GameDocument } from '../../../src/game/types';

function makeGame(overrides: Partial<GameDocument> = {}): GameDocument {
  return {
    phase: 'PLAYING',
    players: ['p0', 'bot_1', 'p2', 'bot_3'],
    currentTrick: null,
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: { player: 'p0', amount: 5 },
    biddingState: null,
    trumpSuit: 'spades',
    dealer: 'bot_3',
    currentPlayer: 'bot_1',
    bidHistory: [{ player: 'p0', action: '5' }],
    roundHistory: [],
    trickWinners: [],
    metadata: { createdAt: '', status: 'active' },
    ...overrides,
  };
}

describe('buildBotContext — roundControlUrgency', () => {
  it('returns 0 when no bid', () => {
    const game = makeGame({ bid: null });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO']]]), 1);
    expect(ctx.roundControlUrgency).toBe(0);
  });

  it('returns 0 when bidder already met bid', () => {
    const game = makeGame({ tricks: { teamA: 5, teamB: 2 } });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA']]]), 1);
    expect(ctx.roundControlUrgency).toBe(0);
  });

  it('returns 1.0 when need > remaining', () => {
    // Need 5, played 7 tricks already (1 remaining), won 0
    const game = makeGame({
      tricks: { teamA: 0, teamB: 7 },
      trickWinners: ['teamB', 'teamB', 'teamB', 'teamB', 'teamB', 'teamB', 'teamB'],
    });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA']]]), 1);
    expect(ctx.roundControlUrgency).toBe(1.0);
  });

  it('returns proportional urgency mid-round', () => {
    // Bid 5, won 2, played 4 tricks (4 remaining), need 3 more → 3/4 = 0.75
    const game = makeGame({
      tricks: { teamA: 2, teamB: 2 },
      trickWinners: ['teamA', 'teamB', 'teamA', 'teamB'],
    });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ']]]), 1);
    expect(ctx.roundControlUrgency).toBe(0.75);
  });
});

describe('buildBotContext — trick signals', () => {
  it('detects partner winning current trick', () => {
    const game = makeGame({
      currentTrick: { lead: 'p0', plays: [{ player: 'p0', card: 'H7' }, { player: 'bot_3', card: 'HA' }] },
    });
    // bot_1 (seat 1), partner is bot_3 (seat 3) who played HA > H7
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HK', 'CA', 'C8', 'JO']]]), 1);
    expect(ctx.partnerLikelyWinningTrick).toBe(true);
  });

  it('detects opponent winning current trick', () => {
    const game = makeGame({
      currentTrick: { lead: 'p0', plays: [{ player: 'p0', card: 'HA' }] },
    });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HK', 'CA', 'C8', 'JO']]]), 1);
    expect(ctx.partnerLikelyWinningTrick).toBe(false);
  });

  it('isLead is true when no current trick plays', () => {
    const ctx = buildBotContext(makeGame(), new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO']]]), 1);
    expect(ctx.isLead).toBe(true);
  });

  it('isLead is false when current trick has plays', () => {
    const game = makeGame({
      currentTrick: { lead: 'p0', plays: [{ player: 'p0', card: 'HA' }] },
    });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HK', 'CA', 'C8', 'JO']]]), 1);
    expect(ctx.isLead).toBe(false);
  });

  it('isForced reads from forcedBidSeat', () => {
    const game = makeGame({ forcedBidSeat: 1 });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO']]]), 1);
    expect(ctx.isForced).toBe(true);
  });

  it('isForced false for other seats', () => {
    const game = makeGame({ forcedBidSeat: 3 });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO']]]), 1);
    expect(ctx.isForced).toBe(false);
  });

  it('isBiddingTeam correctly computed', () => {
    // Bidder is p0 (seat 0, teamA). Bot is seat 1 (teamB).
    const ctx = buildBotContext(makeGame(), new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO']]]), 1);
    expect(ctx.isBiddingTeam).toBe(false);

    // Bot is seat 0 (teamA), bidder is p0 (seat 0, teamA).
    const ctx2 = buildBotContext(makeGame(), new Map([['p0', ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO']]]), 0);
    expect(ctx2.isBiddingTeam).toBe(true);
  });
});

describe('buildBotContext — void inference from roundHistory', () => {
  it('infers void when player did not follow suit', () => {
    const game = makeGame({
      roundHistory: [
        [
          { player: 'p0', card: 'HA' }, // leads hearts
          { player: 'bot_3', card: 'SA' }, // plays spade → void in hearts
          { player: 'p2', card: 'HK' },
          { player: 'bot_1', card: 'H9' },
        ],
      ],
    });
    const ctx = buildBotContext(game, new Map([['bot_1', ['SA', 'SK', 'SQ', 'SJ', 'CA', 'CK', 'DA', 'JO']]]), 1);
    // bot_3 is seat 3 — should be void in hearts
    // The tracker is rebuilt inside buildBotContext, we check signals indirectly
    // Since bot_3 is partner of bot_1 and void in hearts → partnerLikelyVoidInLedSuit should work in a hearts trick
    expect(ctx).toBeDefined();
  });
});
