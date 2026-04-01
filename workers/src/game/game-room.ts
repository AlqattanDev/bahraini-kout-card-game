import { DurableObject } from "cloudflare:workers";
import type { Env } from "../env";
import type {
  GameDocument,
  TeamName,
  SuitName,
  TrickPlay,
} from "./types";
import { buildFourPlayerDeck, dealHands } from "./deck";
import { decodeCard } from "./card";
import { validateBid, validatePass, checkBiddingComplete, isLastBidder } from "./bid-validator";
import { validatePlay, detectPoisonJoker } from "./play-validator";
import { resolveTrick as resolveTrickWinner } from "./trick-resolver";
import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyScore,
  applyKout,
  checkGameOver,
  isRoundDecided,
} from "./scorer";
import { completeGame } from "../matchmaking/queue";

type ClientAction =
  | { action: "placeBid"; data: { bidAmount: number } }
  | { action: "selectTrump"; data: { suit: string } }
  | { action: "playCard"; data: { card: string } };

export class GameRoom extends DurableObject<Env> {
  private game: GameDocument | null = null;
  private hands: Map<string, string[]> = new Map();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Auto ping/pong without waking DO
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair("ping", "pong")
    );
  }

  /**
   * Called by the Worker to initialize a new game with 4 players.
   */
  async initGame(playerUids: string[]): Promise<string> {
    const gameId = this.ctx.id.toString();

    const deck = buildFourPlayerDeck();
    const dealtHands = dealHands(deck);

    const dealerIndex = Math.floor(Math.random() * playerUids.length);
    const dealer = playerUids[dealerIndex];
    const firstBidderIndex = (dealerIndex - 1 + playerUids.length) % playerUids.length;
    const firstBidder = playerUids[firstBidderIndex];

    this.game = {
      phase: "BIDDING",
      players: playerUids,
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
      dealer,
      currentPlayer: firstBidder,
      bidHistory: [],
      roundHistory: [],
      trickWinners: [],
      metadata: { createdAt: new Date().toISOString(), status: "active" },
    };

    // Store hands
    for (let i = 0; i < 4; i++) {
      const hand = dealtHands[i].map((c) => c.code);
      this.hands.set(playerUids[i], hand);
    }

    // Persist to storage
    await this.persistState();

    return gameId;
  }

  /**
   * HTTP fetch handler — used for WebSocket upgrade.
   */
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/ws") {
      if (request.headers.get("Upgrade") !== "websocket") {
        return new Response("Expected WebSocket", { status: 426 });
      }

      const uid = url.searchParams.get("uid");
      if (!uid) {
        return new Response("Missing uid", { status: 400 });
      }

      // Restore state if needed
      await this.loadState();

      if (this.game && !this.game.players.includes(uid)) {
        return new Response("Not a player in this game", { status: 403 });
      }

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      // Tag the WebSocket with the player's UID for later identification
      this.ctx.acceptWebSocket(server, [uid]);

      // Send initial state to this player
      server.send(JSON.stringify({
        event: "gameState",
        data: this.getPublicState(),
      }));

      const hand = this.hands.get(uid);
      if (hand) {
        server.send(JSON.stringify({
          event: "hand",
          data: { hand },
        }));
      }

      // Cancel any disconnect alarm for this player (and detect reconnect)
      const alarmKey = `disconnect:${uid}`;
      const disconnectTime = await this.ctx.storage.get<number>(alarmKey);
      if (disconnectTime) {
        await this.ctx.storage.delete(alarmKey);
        const elapsed = Math.floor((Date.now() - disconnectTime) / 1000);
        const remaining = Math.max(0, 90 - elapsed);
        server.send(JSON.stringify({
          event: "reconnected",
          data: { gracePeriodRemaining: remaining },
        }));
      }

      return new Response(null, { status: 101, webSocket: client });
    }

    if (url.pathname === "/init") {
      const body = await request.json<{ players: string[] }>();
      const gameId = await this.initGame(body.players);
      return Response.json({ gameId });
    }

    return new Response("Not found", { status: 404 });
  }

  /**
   * Handle incoming WebSocket messages from players.
   */
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message !== "string") return;

    const tags = this.ctx.getTags(ws);
    const uid = tags[0];
    if (!uid) return;

    await this.loadState();
    if (!this.game) {
      this.sendError(ws, "NO_GAME", "No game in progress");
      return;
    }

    let parsed: ClientAction;
    try {
      parsed = JSON.parse(message) as ClientAction;
    } catch {
      this.sendError(ws, "INVALID_JSON", "Could not parse message");
      return;
    }

    try {
      switch (parsed.action) {
        case "placeBid":
          await this.handleBid(uid, parsed.data.bidAmount);
          break;
        case "selectTrump":
          await this.handleSelectTrump(uid, parsed.data.suit);
          break;
        case "playCard":
          await this.handlePlayCard(uid, parsed.data.card);
          break;
        default:
          this.sendError(ws, "UNKNOWN_ACTION", `Unknown action`);
          return;
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      this.sendError(ws, "ACTION_FAILED", msg);
    }
  }

  /**
   * Handle WebSocket close — start disconnect timer.
   */
  async webSocketClose(ws: WebSocket, code: number, reason: string, _wasClean: boolean): Promise<void> {
    const tags = this.ctx.getTags(ws);
    const uid = tags[0];
    if (!uid) return;

    await this.loadState();
    if (!this.game || this.game.phase === "GAME_OVER") return;

    // Set a disconnect alarm for 90 seconds
    const alarmKey = `disconnect:${uid}`;
    await this.ctx.storage.put(alarmKey, Date.now());

    // Schedule alarm if not already set
    const currentAlarm = await this.ctx.storage.getAlarm();
    if (!currentAlarm) {
      await this.ctx.storage.setAlarm(Date.now() + 90_000);
    }

    ws.close(code, reason);
  }

  /**
   * Alarm handler — handles both round-advance and disconnect timers.
   */
  async alarm(): Promise<void> {
    await this.loadState();
    if (!this.game || this.game.phase === "GAME_OVER") return;

    const now = Date.now();
    let nextAlarm: number | null = null;

    // Check for round advance (auto-start next round after scoring)
    const roundAdvanceAt = await this.ctx.storage.get<number>("roundAdvanceAt");
    if (roundAdvanceAt && this.game.phase === "ROUND_SCORING") {
      if (now >= roundAdvanceAt) {
        await this.ctx.storage.delete("roundAdvanceAt");
        await this.startNextRound();
        return;
      } else {
        const remaining = roundAdvanceAt - now;
        if (!nextAlarm || remaining < nextAlarm) {
          nextAlarm = remaining;
        }
      }
    }

    // Check for expired disconnect timers
    for (const uid of this.game.players) {
      const alarmKey = `disconnect:${uid}`;
      const disconnectTime = await this.ctx.storage.get<number>(alarmKey);
      if (!disconnectTime) continue;

      const elapsed = now - disconnectTime;
      if (elapsed >= 90_000) {
        await this.handleForfeit(uid);
        await this.ctx.storage.delete(alarmKey);
        if (this.game?.phase === "GAME_OVER") return;
        continue;
      } else {
        const remaining = 90_000 - elapsed;
        if (!nextAlarm || remaining < nextAlarm) {
          nextAlarm = remaining;
        }
      }
    }

    if (nextAlarm) {
      await this.ctx.storage.setAlarm(Date.now() + nextAlarm);
    }
  }

  // ─── Game Action Handlers ────────────────────────────────────────────────

  private async handleBid(uid: string, bidAmount: number): Promise<void> {
    const game = this.game!;
    if (game.phase !== "BIDDING") throw new Error("Not in BIDDING phase");

    const biddingState = game.biddingState!;
    if (biddingState.currentBidder !== uid) throw new Error("Not your turn to bid");

    const isPass = bidAmount === 0;

    if (isPass) {
      const validation = validatePass(
        biddingState.passed,
        uid,
        game.players.length,
        biddingState.highestBid
      );
      if (!validation.valid) throw new Error(validation.error!);

      const newPassed = [...biddingState.passed, uid];
      game.bidHistory = [...(game.bidHistory ?? []), { player: uid, action: "pass" }];

      // Check if bidding is complete (3 passed + existing bid)
      const complete = checkBiddingComplete(
        newPassed,
        biddingState.highestBid,
        biddingState.highestBidder
      );

      if (complete.complete) {
        game.phase = "TRUMP_SELECTION";
        game.bid = { player: complete.winner!, amount: complete.bid! };
        game.biddingState = { ...biddingState, passed: newPassed };
        game.currentPlayer = complete.winner!;
        await this.persistAndBroadcast();
        return;
      }

      // Advance to next bidder
      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = this.nextBidder(game.players, currentIndex, newPassed);
      game.biddingState = { ...biddingState, passed: newPassed, currentBidder: nextPlayer };
      game.currentPlayer = nextPlayer;
    } else {
      const validation = validateBid(bidAmount, biddingState.highestBid, biddingState.passed, uid);
      if (!validation.valid) throw new Error(validation.error!);

      game.bidHistory = [...(game.bidHistory ?? []), { player: uid, action: String(bidAmount) }];

      // Check if Kout (bid 8) — immediate end of bidding
      if (bidAmount === 8) {
        game.phase = "TRUMP_SELECTION";
        game.bid = { player: uid, amount: bidAmount };
        game.biddingState = {
          ...biddingState,
          highestBid: bidAmount,
          highestBidder: uid,
        };
        game.currentPlayer = uid;
        await this.persistAndBroadcast();
        return;
      }

      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = this.nextBidder(game.players, currentIndex, biddingState.passed);
      game.biddingState = {
        ...biddingState,
        highestBid: bidAmount,
        highestBidder: uid,
        currentBidder: nextPlayer,
      };
      game.currentPlayer = nextPlayer;
    }

    await this.persistAndBroadcast();
  }

  private async handleSelectTrump(uid: string, suit: string): Promise<void> {
    const game = this.game!;
    if (game.phase !== "TRUMP_SELECTION") throw new Error("Not in TRUMP_SELECTION phase");
    if (!game.bid || game.bid.player !== uid) throw new Error("Only winning bidder can select trump");

    const validSuits: SuitName[] = ["spades", "hearts", "clubs", "diamonds"];
    if (!validSuits.includes(suit as SuitName)) throw new Error(`Invalid suit: ${suit}`);

    const firstPlayer = this.nextPlayer(game.players, uid);
    game.phase = "PLAYING";
    game.trumpSuit = suit as SuitName;
    game.currentPlayer = firstPlayer;
    game.currentTrick = { lead: firstPlayer, plays: [] };
    game.tricks = { teamA: 0, teamB: 0 };

    await this.persistAndBroadcast();
  }

  private async handlePlayCard(uid: string, card: string): Promise<void> {
    const game = this.game!;
    if (game.phase !== "PLAYING") throw new Error("Not in PLAYING phase");
    if (game.currentPlayer !== uid) throw new Error("Not your turn to play");

    const hand = this.hands.get(uid);
    if (!hand) throw new Error("Hand not found");

    // Poison Joker: last card is joker → automatic round loss
    if (detectPoisonJoker(hand)) {
      await this.resolvePoisonJoker(uid);
      return;
    }

    // Validate and commit the play
    const currentTrick = game.currentTrick!;
    const isLeadPlay = currentTrick.plays.length === 0;
    const ledSuit = isLeadPlay ? null : (() => {
      const leadCard = decodeCard(currentTrick.plays[0].card);
      return leadCard.isJoker ? null : leadCard.suit;
    })();

    const validation = validatePlay(card, hand, ledSuit, isLeadPlay, game.trumpSuit, game.currentBid === 8, (game.trickWinners ?? []).length === 0);
    if (!validation.valid) throw new Error(validation.error!);

    const newHand = hand.filter((c) => c !== card);
    this.hands.set(uid, newHand);

    const newPlays = [...currentTrick.plays, { player: uid, card } as TrickPlay];

    // Trick incomplete — advance to next player
    if (newPlays.length < 4) {
      game.currentTrick = { ...currentTrick, plays: newPlays };
      game.currentPlayer = this.nextPlayer(game.players, uid);
      await this.persistAndBroadcast();
      this.sendHandToPlayer(uid, newHand);
      return;
    }

    // Trick complete — resolve winner and check round status
    await this.resolveTrick(newPlays);
  }

  private async resolvePoisonJoker(uid: string): Promise<void> {
    const game = this.game!;
    const poisonTeam = this.getTeamForPlayer(uid);
    const roundResult = calculatePoisonJokerResult(poisonTeam);
    const newScores = applyScore(game.scores, roundResult.winningTeam, roundResult.points);

    game.scores = newScores;
    this.hands.set(uid, []);
    await this.finalizeRound(newScores);
  }

  private async resolveTrick(plays: TrickPlay[]): Promise<void> {
    const game = this.game!;
    const leadCardObj = decodeCard(plays[0].card);
    const resolvedLedSuit = leadCardObj.isJoker ? game.trumpSuit! : leadCardObj.suit!;
    const trickWinner = resolveTrickWinner(plays, resolvedLedSuit, game.trumpSuit!);
    const winnerTeam = this.getTeamForPlayer(trickWinner);

    game.tricks[winnerTeam] += 1;
    game.trickWinners = [...(game.trickWinners ?? []), winnerTeam];
    game.roundHistory = [...(game.roundHistory ?? []), plays];

    const totalTricks = game.tricks.teamA + game.tricks.teamB;
    const bidInfo = game.bid!;
    const biddingTeam = this.getTeamForPlayer(bidInfo.player);
    const decided = isRoundDecided(bidInfo.amount, biddingTeam, game.tricks);

    // More tricks remain and round not yet decided — continue playing
    if (totalTricks < 8 && !decided) {
      game.currentTrick = { lead: trickWinner, plays: [] };
      game.currentPlayer = trickWinner;
      await this.persistAndBroadcast();
      this.broadcastHands();
      return;
    }

    // Round complete
    const roundResult = calculateRoundResult(bidInfo.amount, biddingTeam, game.tricks);
    const newScores = bidInfo.amount === 8 && roundResult.winningTeam === biddingTeam
      ? applyKout(roundResult.winningTeam)
      : applyScore(game.scores, roundResult.winningTeam, roundResult.points);

    game.scores = newScores;
    game.currentTrick = null;
    await this.finalizeRound(newScores);
  }

  /** Apply scores, check for game over, and broadcast. */
  private async finalizeRound(newScores: { teamA: number; teamB: number }): Promise<void> {
    const game = this.game!;
    const gameWinner = checkGameOver(newScores);

    game.phase = gameWinner ? "GAME_OVER" : "ROUND_SCORING";
    if (gameWinner) {
      game.metadata = { ...game.metadata, status: "completed", winner: gameWinner };
      await this.recordGameCompletion();
    } else {
      await this.scheduleRoundAdvance();
    }

    await this.persistAndBroadcast();
    this.broadcastHands();
  }

  private async handleForfeit(disconnectedUid: string): Promise<void> {
    const game = this.game!;
    const playerTeam = this.getTeamForPlayer(disconnectedUid);
    const winningTeam: TeamName = playerTeam === "teamA" ? "teamB" : "teamA";

    // Use bid failure penalty if bid is active, otherwise 10
    let penalty = 10;
    if (game.bid) {
      const penaltyMap: Record<number, number> = { 5: 10, 6: 12, 7: 14, 8: 16 };
      penalty = penaltyMap[game.bid.amount] ?? 10;
    }

    game.scores = applyScore(game.scores, winningTeam, penalty);
    const gameWinner = checkGameOver(game.scores);
    game.phase = gameWinner ? "GAME_OVER" : "ROUND_SCORING";
    if (gameWinner) {
      game.metadata = { ...game.metadata, status: "completed", winner: gameWinner };
      await this.recordGameCompletion();
    } else {
      await this.scheduleRoundAdvance();
    }

    await this.persistAndBroadcast();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  private getTeamForPlayer(uid: string): TeamName {
    const idx = this.game!.players.indexOf(uid);
    return idx % 2 === 0 ? "teamA" : "teamB";
  }

  private nextPlayer(players: string[], currentUid: string): string {
    const idx = players.indexOf(currentUid);
    return players[(idx - 1 + players.length) % players.length];
  }

  private nextBidder(players: string[], currentIndex: number, passed: string[]): string {
    for (let i = 1; i < players.length; i++) {
      const idx = (currentIndex - i + players.length) % players.length;
      if (!passed.includes(players[idx])) return players[idx];
    }
    return players[(currentIndex - 1 + players.length) % players.length];
  }

  private getPublicState(): Omit<GameDocument, "metadata"> & { gameId: string } {
    const game = this.game!;
    return {
      gameId: this.ctx.id.toString(),
      phase: game.phase,
      players: game.players,
      currentTrick: game.currentTrick,
      tricks: game.tricks,
      scores: game.scores,
      bid: game.bid,
      biddingState: game.biddingState,
      trumpSuit: game.trumpSuit,
      dealer: game.dealer,
      currentPlayer: game.currentPlayer,
      bidHistory: game.bidHistory ?? [],
      roundHistory: game.roundHistory,
      trickWinners: game.trickWinners ?? [],
    };
  }

  private broadcastAll(message: object): void {
    const json = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(json);
      } catch {
        // WebSocket already closed
      }
    }
  }

  private broadcastHands(): void {
    for (const ws of this.ctx.getWebSockets()) {
      const tags = this.ctx.getTags(ws);
      const uid = tags[0];
      if (!uid) continue;
      const hand = this.hands.get(uid);
      if (hand) {
        try {
          ws.send(JSON.stringify({ event: "hand", data: { hand } }));
        } catch {
          // closed
        }
      }
    }
  }

  private sendHandToPlayer(uid: string, hand: string[]): void {
    for (const ws of this.ctx.getWebSockets()) {
      const tags = this.ctx.getTags(ws);
      if (tags[0] === uid) {
        try {
          ws.send(JSON.stringify({ event: "hand", data: { hand } }));
        } catch {
          // closed
        }
        return;
      }
    }
  }

  private sendError(ws: WebSocket, code: string, message: string): void {
    try {
      ws.send(JSON.stringify({ event: "error", data: { code, message } }));
    } catch {
      // closed
    }
  }

  private async persistAndBroadcast(): Promise<void> {
    await this.persistState();
    this.broadcastAll({ event: "gameState", data: this.getPublicState() });
  }

  private async persistState(): Promise<void> {
    await this.ctx.storage.put("game", this.game);
    const handsObj: Record<string, string[]> = {};
    for (const [uid, hand] of this.hands) {
      handsObj[uid] = hand;
    }
    await this.ctx.storage.put("hands", handsObj);
  }

  private async startNextRound(): Promise<void> {
    const game = this.game!;

    // Losing team deals; dealer only rotates when losing team flips
    const oldDealerIndex = game.players.indexOf(game.dealer);
    const scoreA = game.scores.teamA ?? 0;
    const scoreB = game.scores.teamB ?? 0;
    let newDealerIndex = oldDealerIndex;
    if (scoreA !== scoreB) {
      const dealerTeam: TeamName = oldDealerIndex % 2 === 0 ? 'teamA' : 'teamB';
      const losingTeam: TeamName = scoreA < scoreB ? 'teamA' : 'teamB';
      if (dealerTeam !== losingTeam) {
        newDealerIndex = (oldDealerIndex - 1 + game.players.length) % game.players.length;
      }
    }
    const newDealer = game.players[newDealerIndex];

    // First bidder is counter-clockwise from new dealer
    const firstBidderIndex = (newDealerIndex - 1 + game.players.length) % game.players.length;
    const firstBidder = game.players[firstBidderIndex];

    // Re-deal
    const deck = buildFourPlayerDeck();
    const dealtHands = dealHands(deck);
    for (let i = 0; i < 4; i++) {
      const hand = dealtHands[i].map((c) => c.code);
      this.hands.set(game.players[i], hand);
    }

    // Reset game state for new round
    game.phase = "BIDDING";
    game.dealer = newDealer;
    game.currentPlayer = firstBidder;
    game.bid = null;
    game.biddingState = {
      currentBidder: firstBidder,
      highestBid: null,
      highestBidder: null,
      passed: [],
    };
    game.trumpSuit = null;
    game.currentTrick = null;
    game.tricks = { teamA: 0, teamB: 0 };
    game.trickWinners = [];
    game.bidHistory = [];
    game.roundHistory = [];

    await this.persistAndBroadcast();
    this.broadcastHands();
  }

  private async scheduleRoundAdvance(): Promise<void> {
    const advanceTime = Date.now() + 5000;
    await this.ctx.storage.put("roundAdvanceAt", advanceTime);
    const currentAlarm = await this.ctx.storage.getAlarm();
    if (!currentAlarm) {
      await this.ctx.storage.setAlarm(advanceTime);
    }
  }

  private async recordGameCompletion(): Promise<void> {
    if (!this.game) return;
    const winner = this.game.metadata.winner;
    if (!winner) return;

    try {
      await completeGame(
        this.env.DB,
        this.ctx.id.toString(),
        winner,
        this.game.scores,
        this.game.players
      );
    } catch (err) {
      // Non-fatal: game continues even if ELO update fails
      console.error("Failed to update ELO:", err);
    }
  }

  private async loadState(): Promise<void> {
    if (this.game) return; // Already loaded
    this.game = (await this.ctx.storage.get<GameDocument>("game")) ?? null;
    const handsObj = await this.ctx.storage.get<Record<string, string[]>>("hands");
    if (handsObj) {
      this.hands = new Map(Object.entries(handsObj));
    }
  }
}
