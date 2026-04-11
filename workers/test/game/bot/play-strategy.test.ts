import { describe, it, expect } from 'vitest';
import { BotEngine } from '../../../src/game/bot';
import type { BotContext } from '../../../src/game/bot';

function makePlayCtx(overrides: Partial<BotContext> = {}): BotContext {
  return {
    hand: ['SA', 'SK', 'HK', 'H9', 'CQ', 'C8', 'D10', 'JO'],
    scores: { teamA: 0, teamB: 0 },
    myTeam: 'teamB',
    mySeat: 1,
    partnerSeat: 3,
    players: ['p0', 'bot_1', 'p2', 'bot_3'],
    bidHistory: [{ seat: 0, action: '5' }],
    trumpSuit: 'spades',
    currentBid: 5,
    currentTrick: [],
    trickWinners: [],
    tricks: { teamA: 0, teamB: 0 },
    roundHistory: [],
    isLead: true,
    isForced: false,
    isBiddingTeam: false,
    roundControlUrgency: 0,
    partnerLikelyWinningTrick: false,
    partnerNeedsProtection: false,
    opponentLikelyVoidInLedSuit: false,
    partnerLikelyVoidInLedSuit: false,
    ...overrides,
  };
}

describe('BotEngine.play', () => {
  it('returns a card from the hand', () => {
    const ctx = makePlayCtx();
    const card = BotEngine.play(ctx);
    expect(ctx.hand).toContain(card);
  });

  it('follows suit when required', () => {
    const ctx = makePlayCtx({
      hand: ['HK', 'H9', 'CQ', 'C8'],
      isLead: false,
      currentTrick: [{ player: 'p0', card: 'HA' }],
    });
    const card = BotEngine.play(ctx);
    expect(card).toMatch(/^H/);
  });

  it('plays only legal card when single option', () => {
    const ctx = makePlayCtx({
      hand: ['H9'],
      isLead: false,
      currentTrick: [{ player: 'p0', card: 'HA' }],
    });
    expect(BotEngine.play(ctx)).toBe('H9');
  });

  it('does not lead with joker', () => {
    const ctx = makePlayCtx({ hand: ['JO', 'S7'], isLead: true });
    expect(BotEngine.play(ctx)).not.toBe('JO');
  });
});

describe('BotEngine.bid', () => {
  it('returns bid or pass', () => {
    const ctx = makePlayCtx();
    const result = BotEngine.bid(ctx);
    expect(['bid', 'pass']).toContain(result.action);
  });
});

describe('BotEngine.trump', () => {
  it('returns a valid suit', () => {
    const ctx = makePlayCtx();
    const suit = BotEngine.trump(ctx);
    expect(['spades', 'hearts', 'clubs', 'diamonds']).toContain(suit);
  });
});
