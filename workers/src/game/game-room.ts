import { DurableObject } from "cloudflare:workers";
import type { Env } from "../env";
import {
  type GameDocument,
  type BiddingState,
  type TeamName,
  type SuitName,
  type TrickPlay,
  type PendingEvent,
  PLAYER_COUNT,
} from "./types";
import { buildFourPlayerDeck, dealHands } from "./deck";
import { decodeCard } from "./card";
import { validateBid, validatePass, checkBiddingComplete, isLastBidder } from "./bid-validator";
import { BotEngine, buildBotContext } from './bot';
import { validatePlay, detectPoisonJoker } from "./play-validator";
import { resolveTrick as resolveTrickWinner } from "./trick-resolver";
import {
  calculateRoundResult,
  applyScore,
  applyKout,
  applyPoisonJoker,
  checkGameOver,
  isRoundDecided,
} from "./scorer";
import { completeGame } from "../matchmaking/queue";
import { botThinkingDelayMs, DEAL_DELAY_MS, HUMAN_TURN_TIMEOUT_MS } from "./bot-timing";

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
      phase: "DEALING",
      players: playerUids,
      currentTrick: null,
      tricks: { teamA: 0, teamB: 0 },
      scores: { teamA: 0, teamB: 0 },
      bid: null,
      biddingState: null,
      trumpSuit: null,
      dealer,
      currentPlayer: firstBidder,
      bidHistory: [],
      roundHistory: [],
      trickWinners: [],
      metadata: { createdAt: new Date().toISOString(), status: "active" },
      forcedBidSeat: null,
      roundIndex: 0,
    };
    this.game.seats = playerUids.map(uid => ({
      uid,
      isBot: false,
      connected: false,
    }));
    this.game.isRoomGame = false;

    // Store hands — validate 8 cards each
    for (let i = 0; i < 4; i++) {
      const hand = dealtHands[i].map((c) => c.code);
      if (hand.length !== 8) throw new Error(`Player ${i} dealt ${hand.length} cards, expected 8`);
      this.hands.set(playerUids[i], hand);
    }

    // Persist to storage
    await this.persistState();
    await this.scheduleEvent({
      type: "deal_complete",
      fireAt: Date.now() + DEAL_DELAY_MS,
    });

    return gameId;
  }

  /**
   * Create a room-mode game in LOBBY phase with the host at seat 0 and bots at seats 1 and 3.
   */
  async initRoom(hostUid: string, roomCode?: string): Promise<string> {
    const gameId = this.ctx.id.toString();

    this.game = {
      phase: 'LOBBY',
      players: [hostUid, 'bot_1', '', 'bot_3'],
      currentTrick: null,
      tricks: { teamA: 0, teamB: 0 },
      scores: { teamA: 0, teamB: 0 },
      bid: null,
      biddingState: null,
      trumpSuit: null,
      dealer: hostUid,
      currentPlayer: '',
      bidHistory: [],
      roundHistory: [],
      trickWinners: [],
      metadata: { createdAt: new Date().toISOString(), status: 'lobby', roomCode },
      seats: [
        { uid: hostUid, isBot: false, connected: false },
        { uid: 'bot_1', isBot: true, connected: true },
        { uid: null, isBot: false, connected: false },
        { uid: 'bot_3', isBot: true, connected: true },
      ],
      isRoomGame: true,
    };

    this.hands = new Map();
    await this.persistState();
    await this.scheduleEvent({ type: 'lobby_expiry', fireAt: Date.now() + 600_000 });
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

      // Cancel any pending disconnect timeout for this player (reconnect detection)
      const events = await this.ctx.storage.get<PendingEvent[]>('pendingEvents') ?? [];
      const hadDisconnect = events.some(e => e.type === 'disconnect_timeout' && e.meta === uid);
      if (hadDisconnect) {
        await this.cancelEvent('disconnect_timeout', uid);
        server.send(JSON.stringify({
          event: "reconnected",
          data: { gracePeriodRemaining: 90 },
        }));
      }

      // Mark seat as connected
      if (this.game?.seats) {
        const seatIdx = this.game.players.indexOf(uid);
        if (seatIdx >= 0 && this.game.seats[seatIdx]) {
          this.game.seats[seatIdx].connected = true;
          await this.persistState();
        }
      }

      // Send appropriate initial state based on phase
      if (this.game?.phase === 'LOBBY') {
        this.broadcastLobbyState();
      } else {
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
      }

      return new Response(null, { status: 101, webSocket: client });
    }

    if (url.pathname === "/init") {
      const body = await request.json<{ mode?: string; players?: string[]; hostUid?: string; roomCode?: string }>();
      if (body.mode === 'room' && body.hostUid) {
        const gameId = await this.initRoom(body.hostUid, body.roomCode);
        return Response.json({ gameId });
      }
      // Default: matchmaking mode (backward compatible)
      const gameId = await this.initGame(body.players!);
      return Response.json({ gameId });
    }

    if (url.pathname === "/join") {
      const body = await request.json<{ playerUid: string }>();
      await this.loadState();
      if (!this.game || this.game.phase !== 'LOBBY') {
        return Response.json({ error: 'Room not in lobby phase' }, { status: 410 });
      }
      const seats = this.game.seats!;
      // Same player reconnecting
      if (seats[2].uid === body.playerUid) {
        seats[2].connected = true;
        await this.persistState();
        this.broadcastLobbyState();
        return Response.json({ ok: true });
      }
      // Different player trying to take seat 2
      if (seats[2].uid !== null) {
        return Response.json({ error: 'Room is full' }, { status: 409 });
      }
      seats[2] = { uid: body.playerUid, isBot: false, connected: false };
      this.game.players[2] = body.playerUid;
      await this.persistState();
      this.broadcastLobbyState();
      // Reset lobby expiry
      await this.cancelEvent('lobby_expiry');
      await this.scheduleEvent({ type: 'lobby_expiry', fireAt: Date.now() + 600_000 });
      return Response.json({ ok: true });
    }

    if (url.pathname === "/start") {
      const body = await request.json<{ hostUid: string }>();
      await this.loadState();
      if (!this.game || this.game.phase !== 'LOBBY') {
        return Response.json({ error: 'Not in lobby' }, { status: 400 });
      }
      const seats = this.game.seats!;
      if (seats[0].uid !== body.hostUid) {
        return Response.json({ error: 'Not the host' }, { status: 403 });
      }
      // If seat 2 is empty, fill with a bot so the host can start solo
      if (!seats[2].uid) {
        seats[2] = { uid: 'bot_2', isBot: true, connected: true };
        this.game.players[2] = 'bot_2';
      }

      // Cancel lobby expiry
      await this.cancelEvent('lobby_expiry');

      // Deal cards and start game
      const deck = buildFourPlayerDeck();
      const dealtHands = dealHands(deck);
      for (let i = 0; i < 4; i++) {
        const hand = dealtHands[i].map(c => c.code);
        if (hand.length !== 8) throw new Error(`Player ${i} dealt ${hand.length} cards, expected 8`);
        this.hands.set(this.game.players[i], hand);
      }

      const dealerIndex = Math.floor(Math.random() * 4);
      const dealer = this.game.players[dealerIndex];
      const firstBidderIndex = (dealerIndex - 1 + 4) % 4;
      const firstBidder = this.game.players[firstBidderIndex];

      this.game.phase = 'DEALING';
      this.game.dealer = dealer;
      this.game.currentPlayer = firstBidder;
      this.game.biddingState = null;
      this.game.bid = null;
      this.game.trumpSuit = null;
      this.game.currentTrick = null;
      this.game.bidHistory = [];
      this.game.roundHistory = [];
      this.game.trickWinners = [];
      this.game.metadata.status = 'active';
      this.game.forcedBidSeat = null;
      this.game.roundIndex = 0;

      await this.persistAndBroadcast();
      this.broadcastHands();

      await this.scheduleEvent({
        type: 'deal_complete',
        fireAt: Date.now() + DEAL_DELAY_MS,
      });

      return Response.json({ ok: true, players: this.game.players });
    }

    if (url.pathname === "/status") {
      await this.loadState();
      if (!this.game) {
        return Response.json({ error: 'No game' }, { status: 404 });
      }
      return Response.json({
        phase: this.game.phase,
        seats: this.game.seats ?? [],
        closed: this.game.metadata.status === 'closed',
      });
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
    if (this.game.phase === "DEALING") {
      this.sendError(ws, "DEALING", "Cards are being dealt");
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
  async webSocketClose(ws: WebSocket, _code: number, _reason: string, _wasClean: boolean): Promise<void> {
    const tags = this.ctx.getTags(ws);
    const uid = tags[0];
    if (!uid) return;

    await this.loadState();
    if (!this.game || this.game.phase === "GAME_OVER") return;

    // Lobby disconnect: mark seat disconnected but keep UID reserved
    if (this.game?.phase === 'LOBBY' && this.game.seats) {
      const seatIdx = this.game.players.indexOf(uid);
      if (seatIdx >= 0 && this.game.seats[seatIdx]) {
        this.game.seats[seatIdx].connected = false;
      }
      await this.persistState();
      this.broadcastLobbyState();
      return;
    }

    await this.scheduleEvent({
      type: 'disconnect_timeout',
      fireAt: Date.now() + 90_000,
      meta: uid,
    });
  }

  /**
   * Alarm handler — unified PendingEvent queue dispatcher.
   */
  async alarm(): Promise<void> {
    await this.loadState();
    if (!this.game) return;

    const events = await this.ctx.storage.get<PendingEvent[]>('pendingEvents') ?? [];
    const now = Date.now();

    const due = events.filter(e => e.fireAt <= now + 100);
    const remaining = events.filter(e => e.fireAt > now + 100);

    for (const event of due) {
      if (!this.game) break;
      if (this.game.phase === 'GAME_OVER' && event.type !== 'disconnect_timeout') break;
      switch (event.type) {
        case 'round_delay':
          if (this.game.phase === 'ROUND_SCORING') {
            await this.startNextRound();
          }
          break;
        case 'bid_announcement':
          if (this.game.phase === 'BID_ANNOUNCEMENT') {
            const firstPlayer = this.nextPlayer(this.game.players, this.game.bid!.player);
            this.game.phase = 'PLAYING';
            this.game.currentPlayer = firstPlayer;
            this.game.currentTrick = { lead: firstPlayer, plays: [] };
            await this.persistAndBroadcast();
            await this.checkAndScheduleBotTurn();
            await this.scheduleHumanTimeout();
          }
          break;
        case 'deal_complete':
          if (this.game?.phase === 'DEALING') {
            const firstBidder = this.firstBidderAfterDealer();
            this.game.phase = 'BIDDING';
            this.game.biddingState = {
              currentBidder: firstBidder,
              highestBid: null,
              highestBidder: null,
              passed: [],
            };
            this.game.currentPlayer = firstBidder;
            await this.persistAndBroadcast();
            this.broadcastHands();
            await this.checkAndScheduleBotTurn();
            await this.scheduleHumanTimeout();
          }
          break;
        case 'human_timeout': {
          if (!this.game) break;
          const uid = event.meta;
          if (!uid || this.game.currentPlayer !== uid) break; // already acted
          const phase = this.game.phase;
          if (phase === 'BIDDING') {
            const biddingState = this.game.biddingState!;
            if (biddingState.currentBidder !== uid) break;
            // Forced if last bidder with no bid yet
            const isForced = isLastBidder(biddingState.passed, uid, 4) && biddingState.highestBid === null;
            if (isForced) {
              // Must bid — bid minimum above current high (or 5 if none)
              const minBid = (biddingState.highestBid ?? 4) + 1;
              await this.handleBid(uid, minBid);
            } else {
              await this.handleBid(uid, 0); // pass
            }
          } else if (phase === 'TRUMP_SELECTION') {
            if (!this.game.bid || this.game.bid.player !== uid) break;
            // Pick the suit with the most cards in hand
            const hand = this.hands.get(uid) ?? [];
            const suitCounts: Record<string, number> = {};
            for (const card of hand) {
              const d = decodeCard(card);
              if (!d.isJoker && d.suit) suitCounts[d.suit] = (suitCounts[d.suit] ?? 0) + 1;
            }
            const suits = ['spades', 'hearts', 'clubs', 'diamonds'];
            const best = suits.reduce((a, b) => (suitCounts[a] ?? 0) >= (suitCounts[b] ?? 0) ? a : b);
            await this.handleSelectTrump(uid, best);
          } else if (phase === 'PLAYING') {
            if (this.game.currentPlayer !== uid) break;
            const hand = this.hands.get(uid) ?? [];
            const trick = this.game.currentTrick!;
            const isLead = trick.plays.length === 0;
            const ledCard = isLead ? null : decodeCard(trick.plays[0].card);
            const ledSuit = ledCard && !ledCard.isJoker ? ledCard.suit : null;
            const isKout = this.game.bid?.amount === 8;
            const isFirstTrick = (this.game.trickWinners ?? []).length === 0;
            const legal = hand.filter(c => validatePlay(c, hand, ledSuit, isLead, this.game!.trumpSuit, isKout, isFirstTrick).valid);
            const pick = legal.length > 0 ? legal[Math.floor(Math.random() * legal.length)] : hand[0];
            if (pick) await this.handlePlayCard(uid, pick);
          }
          break;
        }
        case 'disconnect_timeout':
          if (event.meta) {
            await this.handleForfeit(event.meta);
          }
          break;
        case 'bot_turn':
          try {
            await this.handleBotTurn();
          } catch (err) {
            console.error('handleBotTurn failed:', err);
          }
          break;
        case 'lobby_expiry':
          if (this.game?.phase === 'LOBBY') {
            this.game.metadata.status = 'closed';
            await this.persistState();
            for (const ws of this.ctx.getWebSockets()) {
              try { ws.close(1000, 'Room expired'); } catch { /* */ }
            }
          }
          break;
      }
    }

    // Merge remaining with any new events added by handlers during this alarm
    const currentEvents = await this.ctx.storage.get<PendingEvent[]>('pendingEvents') ?? [];
    const processedTypes = new Set(due.map(e => `${e.type}:${e.fireAt}`));
    const merged = [
      ...currentEvents.filter(e => !processedTypes.has(`${e.type}:${e.fireAt}`)),
      ...remaining.filter(r => !currentEvents.some(c => c.type === r.type && c.fireAt === r.fireAt)),
    ].sort((a, b) => a.fireAt - b.fireAt);
    await this.ctx.storage.put('pendingEvents', merged);
    if (merged.length > 0) {
      await this.ctx.storage.setAlarm(merged[0].fireAt);
    } else {
      await this.ctx.storage.deleteAlarm();
    }
  }

  // ─── Game Action Handlers ────────────────────────────────────────────────

  /** One CCW orbit: each player has exactly one bid or pass (Kout ends earlier). */
  private async finishBiddingAfterSingleOrbit(
    game: GameDocument,
    biddingState: BiddingState
  ): Promise<void> {
    if (biddingState.highestBid === null || biddingState.highestBidder === null) {
      throw new Error("Bidding orbit complete without a winning bid");
    }
    game.phase = "TRUMP_SELECTION";
    game.bid = {
      player: biddingState.highestBidder,
      amount: biddingState.highestBid,
    };
    game.biddingState = biddingState;
    game.currentPlayer = biddingState.highestBidder;
    await this.persistAndBroadcast();
    await this.checkAndScheduleBotTurn();
    await this.scheduleHumanTimeout();
  }

  private async handleBid(uid: string, bidAmount: number): Promise<void> {
    const game = this.game!;
    if (game.phase !== "BIDDING") throw new Error("Not in BIDDING phase");

    const biddingState = game.biddingState!;
    if (biddingState.currentBidder !== uid) throw new Error("Not your turn to bid");

    await this.cancelHumanTimeout();

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
      const newHistory = [...(game.bidHistory ?? []), { player: uid, action: "pass" }];
      game.bidHistory = newHistory;

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
        await this.checkAndScheduleBotTurn();
        await this.scheduleHumanTimeout();
        return;
      }

      const afterPass: BiddingState = { ...biddingState, passed: newPassed };
      if (newHistory.length >= PLAYER_COUNT) {
        await this.finishBiddingAfterSingleOrbit(game, afterPass);
        return;
      }

      // Advance to next bidder
      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = this.nextBidder(game.players, currentIndex, newPassed);
      game.biddingState = { ...afterPass, currentBidder: nextPlayer };
      game.currentPlayer = nextPlayer;
    } else {
      const validation = validateBid(bidAmount, biddingState.highestBid, biddingState.passed, uid);
      if (!validation.valid) throw new Error(validation.error!);

      const newHistory = [...(game.bidHistory ?? []), { player: uid, action: String(bidAmount) }];
      game.bidHistory = newHistory;

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
        await this.checkAndScheduleBotTurn();
        await this.scheduleHumanTimeout();
        return;
      }

      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = this.nextBidder(game.players, currentIndex, biddingState.passed);
      const updated: BiddingState = {
        ...biddingState,
        highestBid: bidAmount,
        highestBidder: uid,
        currentBidder: nextPlayer,
      };

      if (newHistory.length >= PLAYER_COUNT) {
        await this.finishBiddingAfterSingleOrbit(game, {
          ...updated,
          currentBidder: uid,
        });
        return;
      }

      game.biddingState = updated;
      game.currentPlayer = nextPlayer;
    }

    await this.persistAndBroadcast();
    await this.checkAndScheduleBotTurn();
    await this.scheduleHumanTimeout();
  }

  private async handleSelectTrump(uid: string, suit: string): Promise<void> {
    const game = this.game!;
    if (game.phase !== "TRUMP_SELECTION") throw new Error("Not in TRUMP_SELECTION phase");
    if (!game.bid || game.bid.player !== uid) throw new Error("Only winning bidder can select trump");

    await this.cancelHumanTimeout();

    const validSuits: SuitName[] = ["spades", "hearts", "clubs", "diamonds"];
    if (!validSuits.includes(suit as SuitName)) throw new Error(`Invalid suit: ${suit}`);

    game.phase = "BID_ANNOUNCEMENT";
    game.trumpSuit = suit as SuitName;
    game.tricks = { teamA: 0, teamB: 0 };
    game.forcedBidSeat = null;

    await this.persistAndBroadcast();
    // GameTiming.bidAnnouncementDelay (3s), then transition to PLAYING.
    await this.scheduleEvent({
      type: 'bid_announcement',
      fireAt: Date.now() + 3000,
    });
  }

  private async handlePlayCard(uid: string, card: string): Promise<void> {
    const game = this.game!;
    if (game.phase !== "PLAYING") throw new Error("Not in PLAYING phase");
    if (game.currentPlayer !== uid) throw new Error("Not your turn to play");

    await this.cancelHumanTimeout();

    const hand = this.hands.get(uid);
    if (!hand) throw new Error("Hand not found");

    // Validate and commit the play
    const currentTrick = game.currentTrick!;
    const isLeadPlay = currentTrick.plays.length === 0;

    // Poison Joker: only when leading and last card is joker → automatic round loss
    if (isLeadPlay && detectPoisonJoker(hand)) {
      await this.resolvePoisonJoker(uid);
      return;
    }
    const ledSuit = isLeadPlay ? null : (() => {
      const leadCard = decodeCard(currentTrick.plays[0].card);
      return leadCard.isJoker ? null : leadCard.suit;
    })();

    const validation = validatePlay(card, hand, ledSuit, isLeadPlay, game.trumpSuit, game.bid?.amount === 8, (game.trickWinners ?? []).length === 0);
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
      await this.checkAndScheduleBotTurn();
      await this.scheduleHumanTimeout();
      return;
    }

    // Trick complete — broadcast the 4th card FIRST so the client sees all 4
    // plays before the trick is resolved. This matches offline behavior where
    // _emitState() is called after each card, and enables proper pacing delays
    // (cardPlayDelay for 3→4, trickResolutionDelay for 4→0).
    game.currentTrick = { ...currentTrick, plays: newPlays };
    await this.persistAndBroadcast();
    this.sendHandToPlayer(uid, newHand);

    // Now resolve the trick (will broadcast again with new trick or scoring)
    await this.resolveTrick(newPlays);
  }

  private async resolvePoisonJoker(uid: string): Promise<void> {
    const game = this.game!;
    const poisonTeam = this.getTeamForPlayer(uid);
    const newScores = applyPoisonJoker(poisonTeam);

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
      await this.checkAndScheduleBotTurn();
      await this.scheduleHumanTimeout();
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
    // Already finalized by an earlier forfeit in this alarm pass
    if (game.phase === 'GAME_OVER') return;

    // Cancel any pending timers that would fire into an invalid state
    await this.cancelEvent('bid_announcement');
    await this.cancelHumanTimeout();

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

  private broadcastLobbyState(): void {
    if (!this.game || this.game.phase !== 'LOBBY') return;
    const seats = this.game.seats ?? [];
    for (const ws of this.ctx.getWebSockets()) {
      const tags = this.ctx.getTags(ws);
      const uid = tags[0];
      if (!uid) continue;
      try {
        ws.send(JSON.stringify({
          event: 'lobby_state',
          data: {
            seats: seats.map((s, i) => ({
              seat: i,
              uid: s.uid,
              isBot: s.isBot,
              connected: s.connected,
            })),
            roomCode: this.game.metadata.roomCode,
            isHost: uid === seats[0]?.uid,
          },
        }));
      } catch { /* closed */ }
    }
  }

  private isBotSeat(seatIndex: number): boolean {
    return this.game?.seats?.[seatIndex]?.isBot === true;
  }

  private async checkAndScheduleBotTurn(): Promise<void> {
    if (!this.game) return;
    const currentUid = this.game.currentPlayer;
    const seatIdx = this.game.players.indexOf(currentUid);
    if (seatIdx >= 0 && this.isBotSeat(seatIdx)) {
      await this.cancelEvent('bot_turn');
      const delay = this.computeBotDelayForSeat(seatIdx);
      await this.scheduleEvent({
        type: 'bot_turn',
        fireAt: Date.now() + delay,
      });
    }
  }

  /** Matches lib/shared/constants/timing.dart GameTiming.botThinkingDelay. */
  private computeBotDelayForSeat(seatIdx: number): number {
    const game = this.game!;
    const phase = game.phase;
    if (phase === 'BIDDING') {
      const biddingState = game.biddingState!;
      const uid = game.players[seatIdx];
      const isForced =
        isLastBidder(biddingState.passed, uid, PLAYER_COUNT) &&
        biddingState.highestBid === null;
      return botThinkingDelayMs({ phase: 'bidding', isForcedBid: isForced });
    }
    if (phase === 'TRUMP_SELECTION') {
      return botThinkingDelayMs({
        phase: 'trump',
        bidAmount: game.bid?.amount,
      });
    }
    if (phase === 'PLAYING') {
      const uid = game.players[seatIdx];
      const hand = this.hands.get(uid) ?? [];
      const legalMoves = this.countLegalPlaysForCurrentTurn(hand);
      const trickNumber = (game.trickWinners ?? []).length + 1;
      return botThinkingDelayMs({
        phase: 'playing',
        legalMoves,
        trickNumber,
      });
    }
    return botThinkingDelayMs({ phase: 'playing', legalMoves: 1, trickNumber: 1 });
  }

  private countLegalPlaysForCurrentTurn(hand: string[]): number {
    const game = this.game!;
    const trick = game.currentTrick!;
    const isLead = trick.plays.length === 0;
    const ledCard = isLead ? null : decodeCard(trick.plays[0].card);
    const ledSuit: SuitName | null =
      ledCard && !ledCard.isJoker ? ledCard.suit! : null;
    const isKout = game.bid?.amount === 8;
    const isFirstTrick = (game.trickWinners ?? []).length === 0;
    let n = 0;
    for (const c of hand) {
      if (validatePlay(c, hand, ledSuit, isLead, game.trumpSuit, isKout, isFirstTrick).valid) {
        n++;
      }
    }
    return Math.max(1, n);
  }

  private firstBidderAfterDealer(): string {
    const game = this.game!;
    const dealerIdx = game.players.indexOf(game.dealer);
    return game.players[(dealerIdx - 1 + game.players.length) % game.players.length];
  }

  private async scheduleHumanTimeout(): Promise<void> {
    if (!this.game) return;
    const currentUid = this.game.currentPlayer;
    const seatIdx = this.game.players.indexOf(currentUid);
    // Match offline: 15s for any human (room bots use isBot; matchmaking is all humans).
    if (seatIdx < 0 || this.isBotSeat(seatIdx)) return;
    const phase = this.game.phase;
    if (phase !== 'BIDDING' && phase !== 'TRUMP_SELECTION' && phase !== 'PLAYING') return;
    await this.scheduleEvent({
      type: 'human_timeout',
      fireAt: Date.now() + HUMAN_TURN_TIMEOUT_MS,
      meta: currentUid,
    });
  }

  private async cancelHumanTimeout(): Promise<void> {
    await this.cancelEvent('human_timeout');
  }

  private async handleBotTurn(): Promise<void> {
    if (!this.game || this.game.phase === 'GAME_OVER') return;

    const currentUid = this.game.currentPlayer;
    const seatIdx = this.game.players.indexOf(currentUid);
    if (!this.isBotSeat(seatIdx)) return;

    const ctx = buildBotContext(this.game, this.hands, seatIdx);

    switch (this.game.phase) {
      case 'BIDDING': {
        const biddingState = this.game.biddingState!;
        const forced = isLastBidder(biddingState.passed, currentUid, 4) && biddingState.highestBid === null;
        // Persist forced bid seat so buildBotContext can read it.
        if (forced) {
          this.game.forcedBidSeat = seatIdx;
          await this.persistState();
        }
        // Rebuild ctx after potentially setting forcedBidSeat so isForced is correct.
        const bidCtx = forced ? buildBotContext(this.game, this.hands, seatIdx) : ctx;
        const decision = BotEngine.bid(bidCtx);
        if (decision.action === 'bid') {
          try {
            await this.handleBid(currentUid, decision.amount);
          } catch {
            // Bot bid was invalid (e.g. not higher) — fall back to pass
            await this.handleBid(currentUid, 0);
          }
        } else {
          await this.handleBid(currentUid, 0); // pass
        }
        break;
      }
      case 'TRUMP_SELECTION': {
        const suit = BotEngine.trump(ctx);
        await this.handleSelectTrump(currentUid, suit);
        break;
      }
      case 'PLAYING': {
        const card = BotEngine.play(ctx);
        try {
          await this.handlePlayCard(currentUid, card);
        } catch {
          // Bot chose an invalid card — fall back to random legal card
          const hand = this.hands.get(currentUid) ?? [];
          const trick = this.game!.currentTrick!;
          const isLead = trick.plays.length === 0;
          const ledCard = isLead ? null : decodeCard(trick.plays[0].card);
          const ledSuit = ledCard && !ledCard.isJoker ? ledCard.suit : null;
          const isKout = this.game!.bid?.amount === 8;
          const isFirstTrick = (this.game!.trickWinners ?? []).length === 0;
          const legal = hand.filter(c => validatePlay(c, hand, ledSuit, isLead, this.game!.trumpSuit, isKout, isFirstTrick).valid);
          const pick = legal.length > 0 ? legal[0] : hand[0];
          if (pick) await this.handlePlayCard(currentUid, pick);
        }
        break;
      }
    }
  }

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

  private getPublicState(): Omit<GameDocument, 'metadata' | 'roundHistory'> & { gameId: string; cardCounts: Record<string, number>; passedPlayers: number[] } {
    const game = this.game!;
    const cardCounts: Record<string, number> = {};
    for (let i = 0; i < game.players.length; i++) {
      cardCounts[String(i)] = this.hands.get(game.players[i])?.length ?? 0;
    }
    const passedPlayers = (game.biddingState?.passed ?? []).map(
      uid => game.players.indexOf(uid)
    ).filter(i => i >= 0);
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
      trickWinners: game.trickWinners ?? [],
      roundIndex: game.roundIndex ?? 0,
      cardCounts,
      passedPlayers,
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

    // Re-deal — validate 8 cards each
    const deck = buildFourPlayerDeck();
    const dealtHands = dealHands(deck);
    for (let i = 0; i < 4; i++) {
      const hand = dealtHands[i].map((c) => c.code);
      if (hand.length !== 8) throw new Error(`Player ${i} dealt ${hand.length} cards, expected 8`);
      this.hands.set(game.players[i], hand);
    }

    // Reset game state for new round — DEALING then BIDDING (matches LocalGameController._deal).
    game.phase = "DEALING";
    game.dealer = newDealer;
    game.currentPlayer = firstBidder;
    game.bid = null;
    game.biddingState = null;
    game.trumpSuit = null;
    game.currentTrick = null;
    game.tricks = { teamA: 0, teamB: 0 };
    game.trickWinners = [];
    game.bidHistory = [];
    game.roundHistory = [];
    game.forcedBidSeat = null;
    game.roundIndex = (game.roundIndex ?? 0) + 1;

    await this.persistAndBroadcast();
    this.broadcastHands();
    await this.scheduleEvent({
      type: "deal_complete",
      fireAt: Date.now() + DEAL_DELAY_MS,
    });
  }

  private async scheduleRoundAdvance(): Promise<void> {
    // GameTiming.scoringDelay — same pause as offline before the next deal.
    await this.scheduleEvent({
      type: 'round_delay',
      fireAt: Date.now() + 2000,
    });
  }

  private async scheduleEvent(event: PendingEvent): Promise<void> {
    const events = await this.ctx.storage.get<PendingEvent[]>('pendingEvents') ?? [];
    events.push(event);
    events.sort((a, b) => a.fireAt - b.fireAt);
    await this.ctx.storage.put('pendingEvents', events);
    await this.ctx.storage.setAlarm(events[0].fireAt);
  }

  private async cancelEvent(type: PendingEvent['type'], meta?: string): Promise<void> {
    const events = await this.ctx.storage.get<PendingEvent[]>('pendingEvents') ?? [];
    const filtered = events.filter(e => !(e.type === type && (meta === undefined || e.meta === meta)));
    await this.ctx.storage.put('pendingEvents', filtered);
    if (filtered.length > 0) {
      await this.ctx.storage.setAlarm(filtered[0].fireAt);
    } else {
      await this.ctx.storage.deleteAlarm();
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
    // Always sync from storage — alarm wakes can reuse warm memory with stale `game`/`hands`.
    this.game = (await this.ctx.storage.get<GameDocument>("game")) ?? null;
    const handsObj = await this.ctx.storage.get<Record<string, string[]>>("hands");
    this.hands = handsObj ? new Map(Object.entries(handsObj)) : new Map();
  }
}
