import { decideBid } from './bid-strategy';
import { decideTrump } from './trump-strategy';
import { decidePlay } from './play-strategy';
import { CardTracker } from './card-tracker';
import type { BotContext } from './types';
import { teamForSeat } from './types';
import type { GameDocument, TeamName, SuitName } from '../types';
import { TRICKS_PER_ROUND } from '../types';
import { decodeCard, beatsCard } from '../card';

export { CardTracker } from './card-tracker';
export { teamForSeat } from './types';
export type { BotContext } from './types';

export class BotEngine {
  static bid(ctx: BotContext): { action: 'bid'; amount: number } | { action: 'pass' } {
    return decideBid(ctx);
  }

  static trump(ctx: BotContext): SuitName {
    return decideTrump(ctx);
  }

  static play(ctx: BotContext): string {
    const tracker = buildTracker(ctx);
    return decidePlay(ctx, tracker);
  }
}

function buildTracker(ctx: BotContext): CardTracker {
  return buildTrackerFromRaw(ctx.players, ctx.roundHistory, ctx.currentTrick);
}

export function buildBotContext(
  game: GameDocument,
  hands: Map<string, string[]>,
  botSeat: number,
): BotContext {
  const botUid = game.players[botSeat];
  const hand = hands.get(botUid) ?? [];
  const myTeam = teamForSeat(botSeat);
  const partnerSeat = (botSeat + 2) % 4;
  const bidderSeat = game.bid ? game.players.indexOf(game.bid.player) : null;
  const biddingTeam: TeamName | null = bidderSeat !== null ? teamForSeat(bidderSeat) : null;
  const trickWinners = game.trickWinners ?? [];
  const roundHistory = game.roundHistory ?? [];
  const currentTrickPlays = game.currentTrick?.plays ?? [];
  const bidHistory = (game.bidHistory ?? []).map(entry => ({
    seat: game.players.indexOf(entry.player),
    action: entry.action,
  }));

  const tracker = buildTrackerFromRaw(game.players, roundHistory, currentTrickPlays);

  const roundControlUrgency = computeRoundControlUrgency(
    game.bid?.amount ?? 5,
    bidderSeat,
    game.tricks,
    trickWinners.length,
  );

  const trickSignals = computeTrickSignals(
    botSeat,
    partnerSeat,
    currentTrickPlays,
    game.players,
    game.trumpSuit ?? null,
    tracker,
  );

  return {
    hand,
    scores: game.scores,
    myTeam,
    mySeat: botSeat,
    partnerSeat,
    players: game.players,
    bidHistory,
    trumpSuit: game.trumpSuit ?? undefined,
    currentBid: game.biddingState?.highestBid ?? game.bid?.amount,
    currentTrick: currentTrickPlays,
    trickWinners,
    tricks: game.tricks,
    roundHistory,
    isLead: !game.currentTrick || game.currentTrick.plays.length === 0,
    isForced: game.forcedBidSeat === botSeat,
    isBiddingTeam: biddingTeam === myTeam,
    roundControlUrgency,
    partnerLikelyWinningTrick: trickSignals.partnerLikelyWinning,
    partnerNeedsProtection: trickSignals.partnerNeedsProtection,
    opponentLikelyVoidInLedSuit: trickSignals.opponentVoidLed,
    partnerLikelyVoidInLedSuit: trickSignals.partnerVoidLed,
  };
}

// ── Private helpers ──────────────────────────────────────────────────────────

function buildTrackerFromRaw(
  players: string[],
  roundHistory: Array<Array<{ player: string; card: string }>>,
  currentTrick: Array<{ player: string; card: string }>,
): CardTracker {
  const tracker = new CardTracker();
  for (const trick of roundHistory) {
    if (trick.length === 0) continue;
    const leadCard = decodeCard(trick[0].card);
    const ledSuit = leadCard.isJoker ? null : leadCard.suit;
    for (const play of trick) {
      const seat = players.indexOf(play.player);
      tracker.recordPlay(seat, play.card);
      if (ledSuit !== null && play !== trick[0]) {
        const d = decodeCard(play.card);
        if (!d.isJoker && d.suit !== ledSuit) tracker.inferVoid(seat, ledSuit);
      }
    }
  }
  for (const play of currentTrick) {
    const seat = players.indexOf(play.player);
    tracker.recordPlay(seat, play.card);
  }
  return tracker;
}

function computeRoundControlUrgency(
  bidAmount: number,
  bidderSeat: number | null,
  tricks: Record<TeamName, number>,
  tricksPlayed: number,
): number {
  if (bidderSeat === null) return 0.0;
  const biddingTeam = teamForSeat(bidderSeat);
  const won = tricks[biddingTeam] ?? 0;
  const need = Math.max(0, bidAmount - won);
  const remaining = TRICKS_PER_ROUND - tricksPlayed;
  if (remaining <= 0 || need <= 0) return 0.0;
  if (need > remaining) return 1.0;
  return Math.min(1.0, need / remaining);
}

function computeTrickSignals(
  mySeat: number,
  partnerSeat: number,
  plays: Array<{ player: string; card: string }>,
  players: string[],
  trumpSuit: SuitName | null,
  tracker: CardTracker,
): {
  partnerLikelyWinning: boolean;
  partnerNeedsProtection: boolean;
  opponentVoidLed: boolean;
  partnerVoidLed: boolean;
} {
  if (plays.length === 0) {
    return { partnerLikelyWinning: false, partnerNeedsProtection: false, opponentVoidLed: false, partnerVoidLed: false };
  }

  const leadCard = decodeCard(plays[0].card);
  const ledSuit = leadCard.isJoker ? null : leadCard.suit;

  // Find current winner
  let best = plays[0];
  for (let i = 1; i < plays.length; i++) {
    if (beatsCard(plays[i].card, best.card, trumpSuit, ledSuit)) best = plays[i];
  }

  const partnerUid = players[partnerSeat];
  const partnerWinning = best.player === partnerUid;

  const trumpPlayed = trumpSuit != null &&
    plays.some(p => { const d = decodeCard(p.card); return !d.isJoker && d.suit === trumpSuit; });
  const partnerNeedsProtection =
    partnerWinning &&
    trumpSuit != null &&
    ledSuit != null &&
    ledSuit !== trumpSuit &&
    !trumpPlayed;

  let opponentVoidLed = false;
  let partnerVoidLed = false;
  if (ledSuit !== null) {
    const voids = tracker.knownVoids;
    opponentVoidLed =
      (voids.get((mySeat + 1) % 4)?.has(ledSuit) ?? false) ||
      (voids.get((mySeat + 3) % 4)?.has(ledSuit) ?? false);
    partnerVoidLed = voids.get((mySeat + 2) % 4)?.has(ledSuit) ?? false;
  }

  return { partnerLikelyWinning: partnerWinning, partnerNeedsProtection, opponentVoidLed, partnerVoidLed };
}

