import { decideBid } from './bid-strategy';
import { decideTrump } from './trump-strategy';
import { decidePlay } from './play-strategy';
import { CardTracker } from './card-tracker';
import type { BotContext } from './types';
import { teamForSeat } from './types';
import type { GameDocument, TeamName, SuitName } from '../types';

export { CardTracker } from './card-tracker';
export { teamForSeat } from './types';
export type { BotContext } from './types';

export class BotEngine {
  static bid(ctx: BotContext): { action: 'bid'; amount: number } | { action: 'pass' } {
    return decideBid(ctx);
  }

  static trump(ctx: BotContext): SuitName {
    return decideTrump(ctx.hand, ctx.isForced);
  }

  static play(ctx: BotContext): string {
    const tracker = buildTracker(ctx);
    return decidePlay(ctx, tracker);
  }
}

function buildTracker(ctx: BotContext): CardTracker {
  const tracker = new CardTracker();
  for (const trick of ctx.roundHistory) {
    tracker.recordTrick(trick);
  }
  for (const play of ctx.currentTrick) {
    tracker.recordPlay(play.card);
  }
  return tracker;
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

  return {
    hand,
    scores: game.scores,
    myTeam,
    mySeat: botSeat,
    partnerSeat,
    players: game.players,
    bidHistory: (game.bidHistory ?? []).map(entry => ({
      seat: game.players.indexOf(entry.player),
      action: entry.action,
    })),
    trumpSuit: game.trumpSuit ?? undefined,
    currentBid: game.bid?.amount,
    currentTrick: game.currentTrick?.plays ?? [],
    trickWinners: game.trickWinners ?? [],
    tricks: game.tricks,
    roundHistory: game.roundHistory ?? [],
    isLead: !game.currentTrick || game.currentTrick.plays.length === 0,
    isForced: false,
    isBiddingTeam: biddingTeam === myTeam,
  };
}
