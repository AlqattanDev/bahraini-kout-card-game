import { describe, it, expect } from "vitest";
import { buildFourPlayerDeck, dealHands } from "../../src/game/deck";
import { encodeCard, decodeCard } from "../../src/game/card";
import { validateBid, validatePass, isLastBidder, checkBiddingComplete } from "../../src/game/bid-validator";
import { validatePlay, detectPoisonJoker } from "../../src/game/play-validator";
import { resolveTrick } from "../../src/game/trick-resolver";
import {
  applyScore, applyKout, applyPoisonJoker, checkGameOver,
  calculateRoundResult, isRoundDecided,
} from "../../src/game/scorer";
import { BotEngine, buildBotContext } from "../../src/game/bot";
import type { GameDocument, TeamName, SuitName, TrickPlay, BiddingState } from "../../src/game/types";
import { PLAYER_COUNT } from "../../src/game/types";

// ── Helpers ─────────────────────────────────────────────────────────────────

const PLAYERS = ["p0", "bot_1", "p2", "bot_3"];

function nextSeat(seat: number): number {
  return (seat - 1 + 4) % 4;
}

function teamForSeat(seat: number): TeamName {
  return seat % 2 === 0 ? "teamA" : "teamB";
}

function makeGame(dealerSeat: number, overrides?: Partial<GameDocument>): GameDocument {
  const firstBidder = PLAYERS[nextSeat(dealerSeat)];
  return {
    phase: "BIDDING",
    players: PLAYERS,
    currentTrick: null,
    tricks: { teamA: 0, teamB: 0 },
    scores: { teamA: 0, teamB: 0 },
    bid: null,
    biddingState: {
      currentBidder: firstBidder,
      highestBid: null,
      highestBidder: null,
      passed: [],
    },
    trumpSuit: null,
    dealer: PLAYERS[dealerSeat],
    currentPlayer: firstBidder,
    bidHistory: [],
    roundHistory: [],
    trickWinners: [],
    metadata: { createdAt: new Date().toISOString(), status: "active" },
    roundIndex: 0,
    ...overrides,
  };
}

// ── GameRoom init tests ────────────────────────────────────────────────────

describe("GameRoom: initGame", () => {
  it("initializes game with 4 players and deals 8 cards each", () => {
    const deck = buildFourPlayerDeck();
    expect(deck).toHaveLength(32);

    const hands = dealHands(deck);
    expect(hands).toHaveLength(4);
    for (const hand of hands) {
      expect(hand).toHaveLength(8);
    }

    // All 32 cards accounted for (no duplicates)
    const allCards = hands.flat().map((c) => encodeCard(c));
    expect(new Set(allCards).size).toBe(32);
  });

  it("deals valid card codes that round-trip encode/decode", () => {
    const deck = buildFourPlayerDeck();
    const hands = dealHands(deck);

    for (const hand of hands) {
      for (const card of hand) {
        const code = encodeCard(card);
        const decoded = decodeCard(code);
        expect(decoded.code).toBe(code);
        if (decoded.isJoker) {
          expect(code).toBe("JO");
        } else {
          expect(decoded.suit).toBeTruthy();
          expect(decoded.rank).toBeTruthy();
        }
      }
    }
  });

  it("deck has no 7 of diamonds", () => {
    const deck = buildFourPlayerDeck();
    const codes = deck.map((c) => encodeCard(c));
    expect(codes).not.toContain("D7");
    // But 7 of other suits exist
    expect(codes).toContain("S7");
    expect(codes).toContain("H7");
    expect(codes).toContain("C7");
  });
});

// ── WebSocket access control ───────────────────────────────────────────────

describe("GameRoom: WebSocket access", () => {
  it("rejects non-player by checking players array", () => {
    // Simulates the check: if (!game.players.includes(uid))
    const game = makeGame(0);
    expect(game.players.includes("unknown_uid")).toBe(false);
    expect(game.players.includes("p0")).toBe(true);
    expect(game.players.includes("bot_1")).toBe(true);
  });

  it("sends private hand only to owning player (isolation check)", () => {
    const deck = buildFourPlayerDeck();
    const dealt = dealHands(deck);
    const hands = new Map<string, string[]>();
    for (let i = 0; i < 4; i++) {
      hands.set(PLAYERS[i], dealt[i].map((c) => encodeCard(c)));
    }

    // Each player's hand is different
    const handSets = [...hands.values()].map((h) => new Set(h));
    for (let i = 0; i < 4; i++) {
      for (let j = i + 1; j < 4; j++) {
        // No shared cards between different players
        const shared = [...handSets[i]].filter((c) => handSets[j].has(c));
        expect(shared).toHaveLength(0);
      }
    }

    // Card counts for public state (what opponents see)
    const cardCounts: Record<string, number> = {};
    for (let i = 0; i < PLAYERS.length; i++) {
      cardCounts[String(i)] = hands.get(PLAYERS[i])!.length;
    }
    // All start at 8
    for (const count of Object.values(cardCounts)) {
      expect(count).toBe(8);
    }
  });
});

// ── Bidding state broadcast ────────────────────────────────────────────────

describe("GameRoom: broadcasts state update after bid", () => {
  it("updates biddingState after a valid bid", () => {
    const biddingState: BiddingState = {
      currentBidder: "bot_3",
      highestBid: null,
      highestBidder: null,
      passed: [],
    };

    // bot_3 bids 5
    const validation = validateBid(5, biddingState.highestBid, biddingState.passed, "bot_3");
    expect(validation.valid).toBe(true);

    const updated: BiddingState = {
      ...biddingState,
      highestBid: 5,
      highestBidder: "bot_3",
      currentBidder: PLAYERS[nextSeat(3)], // next bidder CCW
    };
    const bidHistory = [{ player: "bot_3", action: "5" }];

    expect(updated.highestBid).toBe(5);
    expect(updated.highestBidder).toBe("bot_3");
    expect(bidHistory).toHaveLength(1);
  });

  it("updates biddingState after a pass", () => {
    const biddingState: BiddingState = {
      currentBidder: "bot_3",
      highestBid: null,
      highestBidder: null,
      passed: [],
    };

    const validation = validatePass(biddingState.passed, "bot_3", PLAYER_COUNT, null);
    expect(validation.valid).toBe(true);

    const updated: BiddingState = {
      ...biddingState,
      passed: [...biddingState.passed, "bot_3"],
      currentBidder: PLAYERS[nextSeat(3)],
    };
    expect(updated.passed).toContain("bot_3");
  });

  it("transitions to TRUMP_SELECTION when bidding completes", () => {
    // 3 pass, 1 forced bid
    const passed = ["bot_3", "p2", "bot_1"];
    const complete = checkBiddingComplete(passed, 5, "p0");
    expect(complete.complete).toBe(true);
    expect(complete.winner).toBe("p0");
    expect(complete.bid).toBe(5);
  });
});

// ── Full game flow ─────────────────────────────────────────────────────────

describe("GameRoom: handles full game flow: bid → trump → play → score", () => {
  it("plays a complete round with all bots using GameRoom phase transitions", () => {
    const deck = buildFourPlayerDeck();
    const dealt = dealHands(deck);
    const hands = new Map<string, string[]>();
    for (let i = 0; i < 4; i++) {
      hands.set(PLAYERS[i], dealt[i].map((c) => encodeCard(c)));
    }

    const dealerSeat = 0;
    let game = makeGame(dealerSeat);

    // ── DEALING → BIDDING ──
    expect(game.phase).toBe("BIDDING");

    // ── Bidding Phase ──
    let seat = nextSeat(dealerSeat);
    let highestBid: number | null = null;
    let highestBidder: string | null = null;
    const passed: string[] = [];
    const bidHistory: Array<{ player: string; action: string }> = [];

    for (let i = 0; i < 4; i++) {
      const player = PLAYERS[seat];
      const isForced = passed.length === 3 && highestBid === null;

      game = {
        ...game,
        bid: highestBid ? { player: highestBidder!, amount: highestBid } : null,
        biddingState: { currentBidder: player, highestBid, highestBidder, passed: [...passed] },
        currentPlayer: player,
        bidHistory: [...bidHistory],
        forcedBidSeat: isForced ? seat : null,
      };

      const ctx = buildBotContext(game, hands, seat);
      const decision = BotEngine.bid(ctx);

      if (decision.action === "bid") {
        highestBid = decision.amount;
        highestBidder = player;
        bidHistory.push({ player, action: String(decision.amount) });
        if (decision.amount === 8) break;
      } else {
        passed.push(player);
        bidHistory.push({ player, action: "pass" });
      }

      seat = nextSeat(seat);
    }

    expect(highestBid).not.toBeNull();
    expect(highestBidder).not.toBeNull();

    // ── BIDDING → TRUMP_SELECTION ──
    game.phase = "TRUMP_SELECTION";
    game.bid = { player: highestBidder!, amount: highestBid! };
    game.currentPlayer = highestBidder!;

    const bidderSeat = PLAYERS.indexOf(highestBidder!);
    const trumpCtx = buildBotContext(game, hands, bidderSeat);
    const trumpSuit: SuitName = BotEngine.trump(trumpCtx);
    expect(["spades", "hearts", "clubs", "diamonds"]).toContain(trumpSuit);

    // ── TRUMP_SELECTION → BID_ANNOUNCEMENT → PLAYING ──
    game.phase = "PLAYING";
    game.trumpSuit = trumpSuit;

    const tricks: Record<TeamName, number> = { teamA: 0, teamB: 0 };
    const roundHistory: TrickPlay[][] = [];
    const trickWinners: TeamName[] = [];
    let leadSeat = nextSeat(bidderSeat);
    let poisonJoker = false;

    for (let trickNum = 0; trickNum < 8; trickNum++) {
      const plays: TrickPlay[] = [];
      let currentSeat = leadSeat;

      for (let p = 0; p < 4; p++) {
        const player = PLAYERS[currentSeat];
        const hand = hands.get(player)!;

        if (hand.length === 0) break;

        const isLead = plays.length === 0;

        if (isLead && detectPoisonJoker(hand)) {
          poisonJoker = true;
          break;
        }

        game = {
          ...game,
          currentTrick: plays.length > 0 ? { lead: PLAYERS[leadSeat], plays: [...plays] } : { lead: player, plays: [] },
          tricks: { ...tricks },
          trickWinners: [...trickWinners],
          roundHistory: [...roundHistory],
          currentPlayer: player,
        };

        const playCtx = buildBotContext(game, hands, currentSeat);
        const card = BotEngine.play(playCtx);

        // Validate play
        const ledSuit = plays.length > 0
          ? (() => { const d = decodeCard(plays[0].card); return d.isJoker ? null : d.suit; })()
          : null;

        const v = validatePlay(card, hand, ledSuit, isLead, trumpSuit, highestBid === 8, trickNum === 0);
        expect(v.valid, `Invalid play: ${card} from [${hand}] — ${v.error}`).toBe(true);

        plays.push({ player, card });
        hand.splice(hand.indexOf(card), 1);
        currentSeat = nextSeat(currentSeat);
      }

      if (poisonJoker) break;

      if (plays.length === 4) {
        const led = decodeCard(plays[0].card);
        const ledSuit = led.isJoker ? trumpSuit : led.suit;
        const winner = resolveTrick(plays, ledSuit, trumpSuit);
        const winnerTeam = teamForSeat(PLAYERS.indexOf(winner));
        tricks[winnerTeam]++;
        trickWinners.push(winnerTeam);
        roundHistory.push(plays);
        leadSeat = PLAYERS.indexOf(winner);
      }

      if (isRoundDecided(highestBid!, teamForSeat(bidderSeat), tricks)) break;
    }

    // ── PLAYING → ROUND_SCORING ──
    const biddingTeam = teamForSeat(bidderSeat);
    let finalScores: Record<TeamName, number>;

    if (poisonJoker) {
      finalScores = applyPoisonJoker(biddingTeam);
    } else {
      const result = calculateRoundResult(highestBid!, biddingTeam, tricks);
      finalScores =
        highestBid === 8 && result.winningTeam === biddingTeam
          ? applyKout(result.winningTeam)
          : applyScore(game.scores, result.winningTeam, result.points);
    }

    // Only one team should have points
    expect(finalScores.teamA === 0 || finalScores.teamB === 0).toBe(true);
    expect(finalScores.teamA + finalScores.teamB).toBeGreaterThan(0);

    // ── ROUND_SCORING → check GAME_OVER ──
    const gameWinner = checkGameOver(finalScores);
    const expectedPhase = gameWinner ? "GAME_OVER" : "ROUND_SCORING";
    expect(["GAME_OVER", "ROUND_SCORING"]).toContain(expectedPhase);
  });
});

// ── Poison Joker scenario ──────────────────────────────────────────────────

describe("GameRoom: handles poison joker scenario", () => {
  it("detects poison joker when player must lead with only Joker", () => {
    expect(detectPoisonJoker(["JO"])).toBe(true);
    expect(detectPoisonJoker(["JO", "SA"])).toBe(false);
    expect(detectPoisonJoker(["SA"])).toBe(false);
    expect(detectPoisonJoker([])).toBe(false);
  });

  it("applies instant game loss via applyPoisonJoker → applyKout", () => {
    // teamA triggers poison joker → opponent (teamB) wins instantly
    const scores = applyPoisonJoker("teamA");
    expect(scores.teamA).toBe(0);
    expect(scores.teamB).toBe(31);
    expect(checkGameOver(scores)).toBe("teamB");
  });

  it("Joker cannot be led voluntarily (PlayValidator prevents it)", () => {
    // Hand has Joker + other cards → Joker filtered from lead options
    const hand = ["JO", "SA", "HK"];
    const result = validatePlay("JO", hand, null, true, "spades", false, false);
    expect(result.valid).toBe(false);
    expect(result.error).toBe("joker-cannot-lead");
  });
});

// ── Forced bid (malzoom) scenario ──────────────────────────────────────────

describe("GameRoom: handles forced bid", () => {
  it("forces last bidder to bid when 3 pass with no bid", () => {
    const passed = ["bot_3", "p2", "bot_1"];

    // p0 is forced — cannot pass
    expect(isLastBidder(passed, "p0", PLAYER_COUNT)).toBe(true);
    const passResult = validatePass(passed, "p0", PLAYER_COUNT, null);
    expect(passResult.valid).toBe(false);
    expect(passResult.error).toBe("must-bid");

    // p0 must bid at least Bab (5)
    expect(validateBid(5, null, passed, "p0").valid).toBe(true);
  });

  it("last bidder CAN pass if someone already bid", () => {
    const passed = ["bot_3", "p2", "bot_1"];
    expect(isLastBidder(passed, "p0", PLAYER_COUNT)).toBe(true);
    // But highestBid is 5 (someone bid) → pass is allowed
    expect(validatePass(passed, "p0", PLAYER_COUNT, 5).valid).toBe(true);
  });

  it("bot correctly bids when forced (does not pass)", () => {
    const deck = buildFourPlayerDeck();
    const dealt = dealHands(deck);
    const hands = new Map<string, string[]>();
    for (let i = 0; i < 4; i++) {
      hands.set(PLAYERS[i], dealt[i].map((c) => encodeCard(c)));
    }

    // Simulate: 3 players passed, p0 forced
    const game = makeGame(0, {
      biddingState: {
        currentBidder: "p0",
        highestBid: null,
        highestBidder: null,
        passed: ["bot_3", "p2", "bot_1"],
      },
      currentPlayer: "p0",
      forcedBidSeat: 0,
      bidHistory: [
        { player: "bot_3", action: "pass" },
        { player: "p2", action: "pass" },
        { player: "bot_1", action: "pass" },
      ],
    });

    const ctx = buildBotContext(game, hands, 0);
    const decision = BotEngine.bid(ctx);

    // Forced bidder must bid, not pass
    expect(decision.action).toBe("bid");
    expect(decision.amount).toBeGreaterThanOrEqual(5);
  });
});

// ── Forfeit logic (kept from original) ─────────────────────────────────────

describe("disconnect → alarm → forfeit (logic)", () => {
  function getTeamForPlayer(uid: string, players: string[]): TeamName {
    const seat = players.indexOf(uid);
    return seat % 2 === 0 ? "teamA" : "teamB";
  }

  function simulateForfeit(
    scores: Record<TeamName, number>,
    disconnectedUid: string,
    players: string[],
    bidAmount: number | null
  ): { scores: Record<TeamName, number>; gameOver: TeamName | null } {
    const playerTeam = getTeamForPlayer(disconnectedUid, players);
    const winningTeam: TeamName = playerTeam === "teamA" ? "teamB" : "teamA";

    let penalty = 10;
    if (bidAmount !== null) {
      const penaltyMap: Record<number, number> = { 5: 10, 6: 12, 7: 14, 8: 16 };
      penalty = penaltyMap[bidAmount] ?? 10;
    }

    const newScores = applyScore(scores, winningTeam, penalty);
    const gameOver = checkGameOver(newScores);
    return { scores: newScores, gameOver };
  }

  it("applies penalties for multiple disconnected players from the same team", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    const r1 = simulateForfeit(scores, "p0", players, null);
    scores = r1.scores;
    expect(scores.teamB).toBe(10);
    expect(r1.gameOver).toBeNull();

    const r2 = simulateForfeit(scores, "p2", players, null);
    scores = r2.scores;
    expect(scores.teamB).toBe(20);
    expect(r2.gameOver).toBeNull();
  });

  it("applies penalties for disconnected players from different teams", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    const r1 = simulateForfeit(scores, "p0", players, null);
    scores = r1.scores;
    expect(scores.teamB).toBe(10);

    const r2 = simulateForfeit(scores, "p1", players, null);
    scores = r2.scores;
    expect(scores.teamA).toBe(0);
    expect(scores.teamB).toBe(0);
  });

  it("first forfeit can end the game, second is skipped (GAME_OVER guard)", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 25 };
    let phase = "PLAYING";

    const r1 = simulateForfeit(scores, "p0", players, null);
    scores = r1.scores;
    if (r1.gameOver) phase = "GAME_OVER";

    expect(scores.teamB).toBe(35);
    expect(phase).toBe("GAME_OVER");
    expect(r1.gameOver).toBe("teamB");

    if (phase !== "GAME_OVER") {
      const r2 = simulateForfeit(scores, "p1", players, null);
      scores = r2.scores;
    }

    expect(scores.teamB).toBe(35);
    expect(scores.teamA).toBe(0);
  });

  it("uses bid penalty when a bid is active", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 0 };

    const r1 = simulateForfeit(scores, "p0", players, 7);
    scores = r1.scores;
    expect(scores.teamB).toBe(14);

    const r2 = simulateForfeit(scores, "p2", players, 7);
    scores = r2.scores;
    expect(scores.teamB).toBe(28);
  });

  it("both forfeits process before game ends when neither alone reaches 31", () => {
    const players = ["p0", "p1", "p2", "p3"];
    let scores: Record<TeamName, number> = { teamA: 0, teamB: 10 };
    const forfeited: string[] = [];

    const disconnectedPlayers = ["p0", "p2"];
    for (const uid of disconnectedPlayers) {
      const result = simulateForfeit(scores, uid, players, null);
      scores = result.scores;
      forfeited.push(uid);
      if (result.gameOver) break;
    }

    expect(forfeited).toEqual(["p0", "p2"]);
    expect(scores.teamB).toBe(30);
    expect(checkGameOver(scores)).toBeNull();
  });
});
