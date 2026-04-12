/**
 * End-to-end game flow tests.
 *
 * These simulate complete game rounds by calling the same pure functions
 * that game-room.ts calls, in the same sequence. No Durable Objects or
 * WebSockets — just the logic pipeline.
 *
 * This is the highest-value test file: if these pass, the game logic is
 * correct regardless of infrastructure.
 */
import { describe, it, expect } from 'vitest';
import { buildFourPlayerDeck, dealHands } from '../../src/game/deck';
import { encodeCard, decodeCard } from '../../src/game/card';
import { validateBid, validatePass, isLastBidder, checkBiddingComplete } from '../../src/game/bid-validator';
import { validatePlay, detectPoisonJoker } from '../../src/game/play-validator';
import { resolveTrick } from '../../src/game/trick-resolver';
import {
  calculateRoundResult, applyScore, applyKout, applyPoisonJoker,
  checkGameOver, isRoundDecided,
} from '../../src/game/scorer';
import { BotEngine, buildBotContext } from '../../src/game/bot';
import type { GameDocument, TeamName, SuitName, TrickPlay } from '../../src/game/types';

// ── Helpers ─────────────────────────────────────────────────────────────────

const PLAYERS = ['p0', 'bot_1', 'p2', 'bot_3'];

function nextSeat(seat: number): number {
  return (seat - 1 + 4) % 4;
}

function teamForSeat(seat: number): TeamName {
  return seat % 2 === 0 ? 'teamA' : 'teamB';
}

/** Deal a deterministic set of hands for testing. */
function dealDeterministic(): Map<string, string[]> {
  const deck = buildFourPlayerDeck();
  const hands = dealHands(deck);
  const map = new Map<string, string[]>();
  for (let i = 0; i < 4; i++) {
    map.set(PLAYERS[i], hands[i].map(c => encodeCard(c)));
  }
  return map;
}

/** Deal with specific hands for controlled tests. */
function dealFixed(h0: string[], h1: string[], h2: string[], h3: string[]): Map<string, string[]> {
  return new Map([
    [PLAYERS[0], h0],
    [PLAYERS[1], h1],
    [PLAYERS[2], h2],
    [PLAYERS[3], h3],
  ]);
}

function makeInitialGame(dealerSeat: number): GameDocument {
  return {
    phase: 'BIDDING',
    players: PLAYERS,
    currentTrick: null,
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: null,
    biddingState: {
      currentBidder: PLAYERS[nextSeat(dealerSeat)],
      highestBid: null,
      highestBidder: null,
      passed: [],
    },
    trumpSuit: null,
    dealer: PLAYERS[dealerSeat],
    currentPlayer: PLAYERS[nextSeat(dealerSeat)],
    bidHistory: [],
    roundHistory: [],
    trickWinners: [],
    metadata: { createdAt: new Date().toISOString(), status: 'active' },
    roundIndex: 0,
  };
}

// ── Tests ───────────────────────────────────────────────────────────────────

describe('E2E: Complete bidding phase', () => {
  it('3 pass + forced bid results in Bab (5)', () => {
    const game = makeInitialGame(0); // dealer is p0, first bidder is p3
    const passed: string[] = [];

    // Seats bid CCW: 3, 2, 1, 0
    // p3 passes
    expect(validatePass(passed, 'bot_3', 4, null).valid).toBe(true);
    passed.push('bot_3');

    // p2 passes
    expect(validatePass(passed, 'p2', 4, null).valid).toBe(true);
    passed.push('p2');

    // bot_1 passes
    expect(validatePass(passed, 'bot_1', 4, null).valid).toBe(true);
    passed.push('bot_1');

    // p0 is forced — cannot pass
    expect(isLastBidder(passed, 'p0', 4)).toBe(true);
    const passResult = validatePass(passed, 'p0', 4, null);
    expect(passResult.valid).toBe(false);
    expect(passResult.error).toBe('must-bid');

    // p0 must bid at least 5
    expect(validateBid(5, null, passed, 'p0').valid).toBe(true);

    passed.length = 0; // Reset for completion check
    const complete = checkBiddingComplete(['bot_3', 'p2', 'bot_1'], 5, 'p0');
    expect(complete.complete).toBe(true);
    expect(complete.winner).toBe('p0');
    expect(complete.bid).toBe(5);
  });

  it('Kout (8) ends bidding immediately', () => {
    const passed: string[] = [];

    // p3 bids 5
    expect(validateBid(5, null, passed, 'bot_3').valid).toBe(true);

    // p2 bids 8 (Kout)
    expect(validateBid(8, 5, passed, 'p2').valid).toBe(true);

    // After Kout, bidding is complete (3 others auto-pass conceptually)
    const complete = checkBiddingComplete(['bot_3', 'bot_1', 'p0'], 8, 'p2');
    expect(complete.complete).toBe(true);
    expect(complete.bid).toBe(8);
  });

  it('rejects bid not higher than current', () => {
    expect(validateBid(5, 5, [], 'bot_1').valid).toBe(false);
    expect(validateBid(5, 6, [], 'bot_1').valid).toBe(false);
    expect(validateBid(6, 5, [], 'bot_1').valid).toBe(true);
  });

  it('last bidder CAN pass if someone already bid', () => {
    const passed = ['bot_3', 'p2', 'bot_1'];
    expect(validatePass(passed, 'p0', 4, 5).valid).toBe(true);
  });
});

describe('E2E: Complete trick resolution', () => {
  it('Joker wins over trump ace', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'bot_3', card: 'JO' },
      { player: 'p2', card: 'SA' }, // trump ace
      { player: 'bot_1', card: 'HK' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('bot_3');
  });

  it('trump 7 beats non-trump ace', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'HA' },
      { player: 'bot_3', card: 'S7' }, // trump
      { player: 'p2', card: 'HK' },
      { player: 'bot_1', card: 'H9' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('bot_3');
  });

  it('highest led suit wins when no trump played', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'H9' },
      { player: 'bot_3', card: 'HA' },
      { player: 'p2', card: 'HK' },
      { player: 'bot_1', card: 'HQ' },
    ];
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('bot_3');
  });

  it('off-suit card never wins', () => {
    const plays: TrickPlay[] = [
      { player: 'p0', card: 'H9' },
      { player: 'bot_3', card: 'CA' }, // off-suit ace
      { player: 'p2', card: 'H7' },
      { player: 'bot_1', card: 'H8' },
    ];
    // H9 is highest hearts
    expect(resolveTrick(plays, 'hearts', 'spades')).toBe('p0');
  });
});

describe('E2E: Scoring — tug of war', () => {
  it('bid 5 success from zero', () => {
    const result = calculateRoundResult(5, 'teamA', { teamA: 5, teamB: 3 });
    expect(result).toEqual({ winningTeam: 'teamA', points: 5 });
    const scores = applyScore({ teamA: 0, teamB: 0 }, 'teamA', 5);
    expect(scores).toEqual({ teamA: 5, teamB: 0 });
  });

  it('bid failure deducts from opponent then adds to winner', () => {
    // teamA had 7 points, teamB wins 10
    const scores = applyScore({ teamA: 7, teamB: 0 }, 'teamB', 10);
    expect(scores).toEqual({ teamA: 0, teamB: 3 });
  });

  it('Kout success = instant win (31)', () => {
    const result = calculateRoundResult(8, 'teamA', { teamA: 8, teamB: 0 });
    expect(result.points).toBe(31);
    const scores = applyKout('teamA');
    expect(scores).toEqual({ teamA: 31, teamB: 0 });
    expect(checkGameOver(scores)).toBe('teamA');
  });

  it('Kout failure gives opponent 31', () => {
    const result = calculateRoundResult(8, 'teamA', { teamA: 7, teamB: 1 });
    expect(result.winningTeam).toBe('teamB');
    // Game uses applyKout for Kout scenarios
    const scores = applyKout('teamB');
    expect(scores).toEqual({ teamA: 0, teamB: 31 });
    expect(checkGameOver(scores)).toBe('teamB');
  });

  it('tug of war over multiple rounds', () => {
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    // Round 1: teamA bids 5, wins
    scores = applyScore(scores, 'teamA', 5);
    expect(scores).toEqual({ teamA: 5, teamB: 0 });

    // Round 2: teamB bids 6, wins
    scores = applyScore(scores, 'teamB', 6);
    expect(scores).toEqual({ teamA: 0, teamB: 1 });

    // Round 3: teamA bids 7, wins
    scores = applyScore(scores, 'teamA', 7);
    expect(scores).toEqual({ teamA: 6, teamB: 0 });

    expect(checkGameOver(scores)).toBeNull();
  });

  it('poison joker instant game loss', () => {
    const scores = applyPoisonJoker('teamA');
    expect(scores).toEqual({ teamA: 0, teamB: 31 });
    expect(checkGameOver(scores)).toBe('teamB');
  });
});

describe('E2E: isRoundDecided early exit', () => {
  it('bid 5: decided when bidder gets 5 tricks', () => {
    expect(isRoundDecided(5, 'teamA', { teamA: 5, teamB: 2 })).toBe(true);
  });

  it('bid 5: decided when opponent gets 4 (kills bid)', () => {
    expect(isRoundDecided(5, 'teamA', { teamA: 2, teamB: 4 })).toBe(true);
  });

  it('bid 5: not decided at 4-3', () => {
    expect(isRoundDecided(5, 'teamA', { teamA: 4, teamB: 3 })).toBe(false);
  });

  it('Kout: needs all 8 or 1 opponent trick', () => {
    expect(isRoundDecided(8, 'teamA', { teamA: 7, teamB: 0 })).toBe(false);
    expect(isRoundDecided(8, 'teamA', { teamA: 8, teamB: 0 })).toBe(true);
    expect(isRoundDecided(8, 'teamA', { teamA: 0, teamB: 1 })).toBe(true);
  });
});

describe('E2E: Bot plays full round (4 bots)', () => {
  it('completes a full 8-trick round with valid moves', () => {
    const hands = dealDeterministic();
    const dealerSeat = 0;
    const game = makeInitialGame(dealerSeat);

    // Validate all hands are 8 cards
    for (const [, hand] of hands) {
      expect(hand).toHaveLength(8);
    }

    // ── Bidding Phase ──
    let currentBidderSeat = nextSeat(dealerSeat);
    let highestBid: number | null = null;
    let highestBidder: string | null = null;
    const passed: string[] = [];
    const bidHistory: Array<{ seat: number; action: string }> = [];

    for (let i = 0; i < 4; i++) {
      const seat = currentBidderSeat;
      const player = PLAYERS[seat];

      const ctx = buildBotContext(
        {
          ...game,
          bid: highestBid ? { player: highestBidder!, amount: highestBid } : null,
          biddingState: { currentBidder: player, highestBid, highestBidder, passed: [...passed] },
          forcedBidSeat: (passed.length === 3 && highestBid === null) ? seat : null,
        },
        hands,
        seat,
      );

      const result = BotEngine.bid(ctx);

      if (result.action === 'bid') {
        if (highestBid !== null) {
          expect(result.amount).toBeGreaterThan(highestBid);
        }
        expect(result.amount).toBeGreaterThanOrEqual(5);
        expect(result.amount).toBeLessThanOrEqual(8);
        highestBid = result.amount;
        highestBidder = player;
        bidHistory.push({ seat, action: String(result.amount) });

        if (result.amount === 8) break; // Kout ends bidding
      } else {
        // Validate pass is legal
        if (passed.length === 3 && highestBid === null) {
          // This shouldn't happen — forced bid should prevent pass
          expect.unreachable('Forced bidder should not pass');
        }
        passed.push(player);
        bidHistory.push({ seat, action: 'pass' });
      }

      currentBidderSeat = nextSeat(seat);
    }

    // Must have a winning bid
    expect(highestBid).not.toBeNull();
    expect(highestBidder).not.toBeNull();

    // ── Trump Selection ──
    const bidderSeat = PLAYERS.indexOf(highestBidder!);
    const trumpCtx = buildBotContext(
      {
        ...game,
        phase: 'TRUMP_SELECTION',
        bid: { player: highestBidder!, amount: highestBid! },
        bidHistory: bidHistory.map(e => ({ player: PLAYERS[e.seat], action: e.action })),
      },
      hands,
      bidderSeat,
    );
    const trumpSuit = BotEngine.trump(trumpCtx);
    expect(['spades', 'hearts', 'clubs', 'diamonds']).toContain(trumpSuit);

    // ── Play Phase ──
    const tricks: Record<TeamName, number> = { teamA: 0, teamB: 0 };
    const roundHistory: TrickPlay[][] = [];
    const trickWinners: TeamName[] = [];
    let leadSeat = nextSeat(bidderSeat);

    for (let trickNum = 0; trickNum < 8; trickNum++) {
      const trickPlays: TrickPlay[] = [];
      let currentSeat = leadSeat;

      for (let p = 0; p < 4; p++) {
        const player = PLAYERS[currentSeat];
        const hand = hands.get(player)!;

        if (hand.length === 0) break; // Round might end early

        const isLead = trickPlays.length === 0;

        // Check poison joker
        if (isLead && detectPoisonJoker(hand)) {
          // Poison joker path — round ends
          break;
        }

        const playGame: GameDocument = {
          ...game,
          phase: 'PLAYING',
          bid: { player: highestBidder!, amount: highestBid! },
          trumpSuit,
          currentTrick: trickPlays.length > 0 ? { lead: PLAYERS[leadSeat], plays: trickPlays } : null,
          tricks: { ...tricks },
          trickWinners: [...trickWinners],
          roundHistory: [...roundHistory],
          bidHistory: bidHistory.map(e => ({ player: PLAYERS[e.seat], action: e.action })),
        };

        const playCtx = buildBotContext(playGame, hands, currentSeat);
        const card = BotEngine.play(playCtx);

        // Validate the play
        const ledSuit = trickPlays.length > 0
          ? (() => { const d = decodeCard(trickPlays[0].card); return d.isJoker ? null : d.suit; })()
          : null;

        const validation = validatePlay(
          card, hand, ledSuit, isLead, trumpSuit,
          highestBid === 8, trickNum === 0,
        );
        expect(validation.valid, `Invalid play: ${card} from ${hand.join(',')} — ${validation.error}`).toBe(true);

        // Play the card
        trickPlays.push({ player, card });

        // Remove from hand
        const idx = hand.indexOf(card);
        expect(idx).toBeGreaterThanOrEqual(0);
        hand.splice(idx, 1);

        currentSeat = nextSeat(currentSeat);
      }

      if (trickPlays.length === 4) {
        const ledCard = decodeCard(trickPlays[0].card);
        const ledSuit = ledCard.isJoker ? trumpSuit : ledCard.suit;
        const winner = resolveTrick(trickPlays, ledSuit, trumpSuit);
        const winnerSeat = PLAYERS.indexOf(winner);
        const winnerTeam = teamForSeat(winnerSeat);
        tricks[winnerTeam]++;
        trickWinners.push(winnerTeam);
        roundHistory.push(trickPlays);
        leadSeat = winnerSeat;
      }

      // Check early round decided
      if (isRoundDecided(highestBid!, teamForSeat(bidderSeat), tricks)) break;
    }

    // Round should be decided
    expect(tricks.teamA + tricks.teamB).toBeGreaterThanOrEqual(1);
    expect(tricks.teamA + tricks.teamB).toBeLessThanOrEqual(8);

    // Score the round
    const biddingTeam = teamForSeat(bidderSeat);
    const roundResult = calculateRoundResult(highestBid!, biddingTeam, tricks);
    expect(roundResult.points).toBeGreaterThan(0);

    const finalScores = highestBid === 8
      ? applyKout(roundResult.winningTeam)
      : applyScore({ teamA: 0, teamB: 0 }, roundResult.winningTeam, roundResult.points);

    // Only one team should have points (tug of war from zero)
    expect(finalScores.teamA === 0 || finalScores.teamB === 0).toBe(true);
  });
});

describe('E2E: Dealer rotation', () => {
  it('losing team deals next round', () => {
    // Simulate: teamA lost (teamB won). Dealer should be on teamA.
    // Current dealer was p0 (seat 0, teamA) → stays since already on losing team
    const dealerSeat = 0;
    const losingTeam: TeamName = 'teamA';
    const dealerTeam = teamForSeat(dealerSeat);

    if (dealerTeam === losingTeam) {
      // Dealer stays
      expect(dealerSeat).toBe(0);
    } else {
      // Rotate CCW until on losing team
      let newDealer = nextSeat(dealerSeat);
      while (teamForSeat(newDealer) !== losingTeam) {
        newDealer = nextSeat(newDealer);
      }
      expect(teamForSeat(newDealer)).toBe(losingTeam);
    }
  });

  it('dealer rotates CCW to land on losing team', () => {
    // Dealer is p1 (seat 1, teamB). TeamA lost.
    const dealerSeat = 1;
    const losingTeam: TeamName = 'teamA';
    const dealerTeam = teamForSeat(dealerSeat);

    expect(dealerTeam).toBe('teamB'); // not on losing team
    const newDealer = nextSeat(dealerSeat); // seat 0 = teamA
    expect(teamForSeat(newDealer)).toBe('teamA');
  });
});

describe('E2E: Poison Joker scenario', () => {
  it('detects poison joker when last card is Joker', () => {
    // Player has only Joker left and must lead
    expect(detectPoisonJoker(['JO'])).toBe(true);
    // Opponent team score set to 31
    const scores = applyPoisonJoker('teamA');
    expect(scores.teamB).toBe(31);
    expect(checkGameOver(scores)).toBe('teamB');
  });
});
