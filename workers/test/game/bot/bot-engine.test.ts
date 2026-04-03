import { describe, it, expect } from 'vitest';
import { buildBotContext } from '../../../src/game/bot';
import type { GameDocument } from '../../../src/game/types';

describe('buildBotContext', () => {
  it('builds context from game document for bot seat 1', () => {
    const game: GameDocument = {
      phase: 'BIDDING',
      players: ['host', 'bot_1', 'friend', 'bot_3'],
      currentTrick: null,
      tricks: { teamA: 0, teamB: 0 },
      scores: { teamA: 10, teamB: 5 },
      bid: null,
      biddingState: { currentBidder: 'bot_1', highestBid: null, highestBidder: null, passed: [] },
      trumpSuit: null,
      dealer: 'host',
      currentPlayer: 'bot_1',
      bidHistory: [{ player: 'host', action: 'pass' }],
      roundHistory: [],
      trickWinners: [],
      metadata: { createdAt: '', status: 'active' },
    };
    const hands = new Map([['bot_1', ['SA', 'SK', 'HQ', 'H9', 'CJ', 'C8', 'D10', 'JO']]]);

    const ctx = buildBotContext(game, hands, 1);
    expect(ctx.mySeat).toBe(1);
    expect(ctx.myTeam).toBe('teamB');
    expect(ctx.partnerSeat).toBe(3);
    expect(ctx.hand).toHaveLength(8);
    expect(ctx.bidHistory).toHaveLength(1);
    expect(ctx.bidHistory[0].seat).toBe(0);
  });
});
