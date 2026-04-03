import { describe, it, expect } from 'vitest';
import { decideBid } from '../../../src/game/bot/bid-strategy';
import type { BotContext } from '../../../src/game/bot/types';

function makeCtx(overrides: Partial<BotContext> = {}): BotContext {
  return {
    hand: ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO'],
    scores: { teamA: 0, teamB: 0 },
    myTeam: 'teamB',
    mySeat: 1,
    partnerSeat: 3,
    players: ['p0', 'bot_1', 'p2', 'bot_3'],
    bidHistory: [],
    currentBid: undefined,
    currentTrick: [],
    trickWinners: [],
    tricks: { teamA: 0, teamB: 0 },
    roundHistory: [],
    isLead: false,
    isForced: false,
    isBiddingTeam: false,
    ...overrides,
  };
}

describe('decideBid', () => {
  it('bids with strong hand', () => {
    const result = decideBid(makeCtx());
    expect(result.action).toBe('bid');
  });

  it('passes with weak hand', () => {
    const result = decideBid(makeCtx({ hand: ['S7', 'S8', 'H7', 'H8', 'C7', 'C8', 'D8', 'D9'] }));
    expect(result.action).toBe('pass');
  });

  it('forced bid returns bid action', () => {
    const result = decideBid(makeCtx({
      hand: ['S7', 'S8', 'H7', 'H8', 'C7', 'C8', 'D8', 'D9'],
      isForced: true,
    }));
    expect(result.action).toBe('bid');
    if (result.action === 'bid') expect(result.amount).toBeGreaterThanOrEqual(5);
  });

  it('forced bid exceeds current bid', () => {
    const result = decideBid(makeCtx({
      hand: ['S7', 'S8', 'H7', 'H8', 'C7', 'C8', 'D8', 'D9'],
      isForced: true,
      currentBid: 5,
    }));
    expect(result.action).toBe('bid');
    if (result.action === 'bid') expect(result.amount).toBeGreaterThan(5);
  });

  it('bid amount never exceeds 8', () => {
    const result = decideBid(makeCtx());
    if (result.action === 'bid') expect(result.amount).toBeLessThanOrEqual(8);
  });
});
