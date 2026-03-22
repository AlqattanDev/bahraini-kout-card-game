/**
 * Full game integration test — exercises the complete Kout game flow using
 * extracted logic functions with mock data. No Firebase emulator required.
 */

import { buildFourPlayerDeck, dealHands } from '../../src/game/deck';
import { validatePlay, detectPoisonJoker } from '../../src/game/play-validator';
import { checkBiddingComplete } from '../../src/game/bid-validator';
import { resolveTrick } from '../../src/game/trick-resolver';
import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyScore,
} from '../../src/game/scorer';
import { decodeCard } from '../../src/game/card';
import { SuitName, TrickPlay, TeamName } from '../../src/game/types';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Returns the team for a given seat index: even = teamA, odd = teamB */
function teamForSeat(seat: number): TeamName {
  return seat % 2 === 0 ? 'teamA' : 'teamB';
}

/**
 * Pick the first valid card from a hand given current trick state.
 * If isLeadPlay, skip jokers. Otherwise follow suit if possible.
 */
function pickValidCard(
  hand: string[],
  ledSuit: SuitName | null,
  isLeadPlay: boolean
): string {
  for (const card of hand) {
    const result = validatePlay(card, hand, ledSuit, isLeadPlay);
    if (result.valid) return card;
  }
  throw new Error(`No valid card found in hand: ${hand.join(', ')}`);
}

// ─── Task 8: Full Game Integration Test ───────────────────────────────────────

describe('Full game integration', () => {
  const PLAYERS = ['uid1', 'uid2', 'uid3', 'uid4'];

  it('completes a full 8-trick round and scores correctly', () => {
    // Step 1: Build deck and deal
    const deck = buildFourPlayerDeck();
    expect(deck).toHaveLength(32); // 3*8 + 7 diamonds + 1 joker

    const [hand0, hand1, hand2, hand3] = dealHands(deck);
    const hands: string[][] = [
      hand0.map((c) => c.code),
      hand1.map((c) => c.code),
      hand2.map((c) => c.code),
      hand3.map((c) => c.code),
    ];

    // Verify each player got 8 cards
    expect(hands[0]).toHaveLength(8);
    expect(hands[1]).toHaveLength(8);
    expect(hands[2]).toHaveLength(8);
    expect(hands[3]).toHaveLength(8);

    // Step 2: Simulate bidding — seat 1 bids 5, seats 2, 3, 0 pass
    // uid1 (seat 1) bids 5
    const passed: string[] = [];
    let highestBid: number | null = 5;
    let highestBidder: string | null = PLAYERS[1];

    // uid2, uid3, uid0 pass
    passed.push(PLAYERS[2]);
    passed.push(PLAYERS[3]);
    passed.push(PLAYERS[0]);

    const biddingResult = checkBiddingComplete(passed, highestBid, highestBidder);
    expect(biddingResult.complete).toBe(true);
    expect(biddingResult.winner).toBe(PLAYERS[1]);
    expect(biddingResult.bid).toBe(5);

    // Step 3: Select trump — uid1 selects spades
    const trumpSuit: SuitName = 'spades';

    // Step 4: Play 8 tricks
    // After trump selection, first player is clockwise after bidder (uid2 = seat 2)
    const tricks: Record<TeamName, number> = { teamA: 0, teamB: 0 };
    let currentLeader = PLAYERS[2]; // seat 2, clockwise after uid1 (seat 1)

    for (let trickNum = 0; trickNum < 8; trickNum++) {
      const plays: TrickPlay[] = [];
      let ledSuit: SuitName | null = null;

      const startSeat = PLAYERS.indexOf(currentLeader);

      for (let i = 0; i < 4; i++) {
        const seatIdx = (startSeat + i) % 4;
        const uid = PLAYERS[seatIdx];
        const hand = hands[seatIdx];
        const isLeadPlay = i === 0;

        const card = pickValidCard(hand, ledSuit, isLeadPlay);

        // If it's the lead play, determine the led suit
        if (isLeadPlay) {
          const decoded = decodeCard(card);
          ledSuit = decoded.isJoker ? null : decoded.suit;
        }

        // Remove card from hand
        hands[seatIdx] = hand.filter((c) => c !== card);
        plays.push({ player: uid, card });
      }

      expect(plays).toHaveLength(4);

      // Resolve trick
      const resolvedLedSuit = ledSuit ?? trumpSuit;
      const trickWinner = resolveTrick(plays, resolvedLedSuit, trumpSuit);
      const winnerSeat = PLAYERS.indexOf(trickWinner);
      const winnerTeam = teamForSeat(winnerSeat);
      tricks[winnerTeam]++;
      currentLeader = trickWinner;
    }

    // All tricks played
    expect(tricks.teamA + tricks.teamB).toBe(8);

    // Step 5: Score the round
    // uid1 (seat 1 = teamB) bid 5
    const biddingTeam = teamForSeat(PLAYERS.indexOf(PLAYERS[1])); // teamB (odd seat)
    const roundResult = calculateRoundResult(5, biddingTeam, tricks);

    expect(['teamA', 'teamB']).toContain(roundResult.winningTeam);
    expect(roundResult.points).toBeGreaterThan(0);

    // Step 6: Apply scores
    const initialScores = { teamA: 0, teamB: 0 };
    const newScores = applyScore(initialScores, roundResult.winningTeam, roundResult.points);

    // Winning team's score should increase
    expect(newScores[roundResult.winningTeam]).toBe(roundResult.points);
    // The other team stays at 0 (no decrement when already 0)
    const losingTeam: TeamName = roundResult.winningTeam === 'teamA' ? 'teamB' : 'teamA';
    expect(newScores[losingTeam]).toBe(0);
  });

  // ─── Edge case: Poison Joker ───────────────────────────────────────────────

  it('detects poison joker when player has only the joker left', () => {
    // A player whose hand is down to just the joker triggers poison joker
    const hand = ['JO'];
    expect(detectPoisonJoker(hand)).toBe(true);

    // Not a poison joker when hand has multiple cards
    expect(detectPoisonJoker(['JO', 'SA'])).toBe(false);
    expect(detectPoisonJoker(['SA'])).toBe(false);
    expect(detectPoisonJoker([])).toBe(false);
  });

  it('poison joker grants +10 to the opponent team', () => {
    // uid0 (seat 0 = teamA) is stuck with the poison joker
    const poisonTeam: TeamName = 'teamA';
    const result = calculatePoisonJokerResult(poisonTeam);

    expect(result.winningTeam).toBe('teamB');
    expect(result.points).toBe(10);

    const scores = applyScore({ teamA: 0, teamB: 0 }, result.winningTeam, result.points);
    expect(scores.teamB).toBe(10);
    expect(scores.teamA).toBe(0);
  });

  it('poison joker from teamB grants +10 to teamA', () => {
    const result = calculatePoisonJokerResult('teamB');
    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(10);
  });

  // ─── Edge case: Kout instant win (bid 8, win all 8 tricks → +31) ──────────

  it('kout: bid 8, win all 8 tricks → +31 for bidding team', () => {
    // teamA bids 8 and wins all 8 tricks
    const tricksWon: Record<TeamName, number> = { teamA: 8, teamB: 0 };
    const result = calculateRoundResult(8, 'teamA', tricksWon);

    expect(result.winningTeam).toBe('teamA');
    expect(result.points).toBe(31);

    const scores = applyScore({ teamA: 0, teamB: 0 }, result.winningTeam, result.points);
    expect(scores.teamA).toBe(31);
    expect(scores.teamB).toBe(0);
  });

  it('kout: bid 8 but fails → opponent gets +31 (bid failure penalty)', () => {
    // teamA bids 8 but only wins 7 tricks
    const tricksWon: Record<TeamName, number> = { teamA: 7, teamB: 1 };
    const result = calculateRoundResult(8, 'teamA', tricksWon);

    expect(result.winningTeam).toBe('teamB');
    expect(result.points).toBe(31);
  });

  // ─── Bidding complete check ────────────────────────────────────────────────

  it('bidding is complete when exactly 3 players have passed with a current bid', () => {
    const result = checkBiddingComplete(['uid2', 'uid3', 'uid0'], 5, 'uid1');
    expect(result.complete).toBe(true);
    expect(result.winner).toBe('uid1');
    expect(result.bid).toBe(5);
  });

  it('bidding is NOT complete when fewer than 3 players have passed', () => {
    const result = checkBiddingComplete(['uid2', 'uid3'], 5, 'uid1');
    expect(result.complete).toBe(false);
  });

  it('bidding is NOT complete when no bid has been placed', () => {
    const result = checkBiddingComplete(['uid2', 'uid3', 'uid0'], null, null);
    expect(result.complete).toBe(false);
  });

  // ─── Play validation during trick play ────────────────────────────────────

  it('joker cannot lead a trick', () => {
    const hand = ['JO', 'SA', 'HK'];
    const result = validatePlay('JO', hand, null, true);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('cannot-lead-joker');
  });

  it('must follow led suit if player has it', () => {
    const hand = ['HA', 'SA'];
    // Led suit is hearts, player has hearts but tries to play spades
    const result = validatePlay('SA', hand, 'hearts', false);
    expect(result.valid).toBe(false);
    expect(result.error).toBe('must-follow-suit');
  });

  it('can play off-suit if player has no cards of led suit', () => {
    const hand = ['SA', 'CA'];
    // Led suit is hearts, player has none
    const result = validatePlay('SA', hand, 'hearts', false);
    expect(result.valid).toBe(true);
  });

  it('joker can be played when following suit and player has no led suit', () => {
    const hand = ['JO', 'SA'];
    // Led suit is hearts, no hearts in hand → joker is valid
    const result = validatePlay('JO', hand, 'hearts', false);
    expect(result.valid).toBe(true);
  });
});
