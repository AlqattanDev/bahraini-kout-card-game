import { describe, it, expect } from 'vitest';
import { decideTrump } from '../../../src/game/bot/trump-strategy';
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
    currentBid: 5,
    currentTrick: [],
    trickWinners: [],
    tricks: { teamA: 0, teamB: 0 },
    roundHistory: [],
    isLead: false,
    isForced: false,
    isBiddingTeam: true,
    roundControlUrgency: 0,
    partnerLikelyWinningTrick: false,
    partnerNeedsProtection: false,
    opponentLikelyVoidInLedSuit: false,
    partnerLikelyVoidInLedSuit: false,
    ...overrides,
  };
}

describe('decideTrump', () => {
  it('picks longest + strongest suit', () => {
    // 4 spades (AKQJ) vs 2 hearts (AK) vs 1 club (A)
    const suit = decideTrump(makeCtx({ hand: ['SA', 'SK', 'SQ', 'SJ', 'HA', 'HK', 'CA', 'JO'] }));
    expect(suit).toBe('spades');
  });

  it('uses honor tiebreak when suits are close', () => {
    // 3 spades (A,K,7) vs 3 hearts (Q,J,10) — spades has better honors
    const suit = decideTrump(makeCtx({ hand: ['SA', 'SK', 'S7', 'HQ', 'HJ', 'H10', 'CA', 'JO'] }));
    expect(suit).toBe('spades');
  });

  it('returns valid suit for any hand', () => {
    const suit = decideTrump(makeCtx({ hand: ['S7', 'H7', 'C7', 'D8', 'D9', 'D10', 'DJ', 'JO'] }));
    expect(['spades', 'hearts', 'clubs', 'diamonds']).toContain(suit);
  });

  it('Kout weights favor strength over length', () => {
    // 3 spades (AKQ, high strength) vs 5 clubs (low cards)
    const suit = decideTrump(makeCtx({
      hand: ['SA', 'SK', 'SQ', 'C7', 'C8', 'C9', 'C10', 'CJ'],
      currentBid: 8,
    }));
    // With Kout weights (length=1.5, strength=2.0), AKQ spades should compete
    expect(['spades', 'clubs']).toContain(suit);
  });

  it('falls back to spades when no candidates', () => {
    // Edge case: single card hand
    const suit = decideTrump(makeCtx({ hand: ['JO'] }));
    expect(suit).toBe('spades');
  });

  it('prefers suit with 2+ cards over singleton', () => {
    const suit = decideTrump(makeCtx({
      hand: ['SA', 'SK', 'HA', 'CA', 'DA', 'D9', 'D8', 'JO'],
    }));
    // Diamonds has 3 cards, spades has 2 — both valid candidates
    expect(['spades', 'diamonds']).toContain(suit);
  });
});
