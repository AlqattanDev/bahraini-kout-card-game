import { decodeCard } from '../card';
import { RANK_VALUES } from '../types';
import type { SuitName, TrickPlay } from '../types';
import type { CardTracker } from './card-tracker';
import type { BotContext } from './types';

export function decidePlay(ctx: BotContext, tracker: CardTracker): string {
  const legal = getLegalPlays(ctx.hand, ctx.currentTrick, ctx.trumpSuit, ctx.isLead);
  if (legal.length === 1) return legal[0];

  if (ctx.isLead) {
    return selectLead(legal, ctx, tracker);
  }
  return selectFollow(legal, ctx, tracker);
}

function getLegalPlays(
  hand: string[], trick: TrickPlay[], _trumpSuit: SuitName | undefined, isLead: boolean,
): string[] {
  if (isLead) {
    const nonJoker = hand.filter(c => c !== 'JO');
    return nonJoker.length > 0 ? nonJoker : [...hand];
  }

  if (trick.length === 0) return [...hand];

  const ledCard = decodeCard(trick[0].card);
  if (ledCard.isJoker) return [...hand];

  const ledSuit = ledCard.suit!;
  const suitCards = hand.filter(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.suit === ledSuit;
  });

  if (suitCards.length > 0) {
    return hand.includes('JO') ? [...suitCards, 'JO'] : suitCards;
  }

  return [...hand];
}

function selectLead(legal: string[], ctx: BotContext, tracker: CardTracker): string {
  const { trumpSuit, hand } = ctx;

  // Master card leads
  const masters = legal.filter(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.suit !== trumpSuit && tracker.isHighestRemaining(c, hand);
  });
  if (masters.length > 0) return masters[0];

  // Ace leads (non-trump)
  const aces = legal.filter(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.rank === 'ace' && d.suit !== trumpSuit;
  });
  if (aces.length > 0) return aces[0];

  // Trump strip for bidding team with 3+ trump
  if (ctx.isBiddingTeam && trumpSuit) {
    const myTrumps = legal.filter(c => {
      const d = decodeCard(c);
      return !d.isJoker && d.suit === trumpSuit;
    });
    if (myTrumps.length >= 3) {
      myTrumps.sort((a, b) => rankVal(b) - rankVal(a));
      return myTrumps[0];
    }
  }

  // Short suit leads for defense
  if (!ctx.isBiddingTeam) {
    const singles = legal.filter(c => {
      const d = decodeCard(c);
      if (d.isJoker || d.suit === trumpSuit) return false;
      return legal.filter(o => {
        const od = decodeCard(o);
        return !od.isJoker && od.suit === d.suit;
      }).length === 1;
    });
    if (singles.length > 0) return singles[0];
  }

  return leadFromLongestSuit(legal, trumpSuit);
}

function selectFollow(legal: string[], ctx: BotContext, _tracker: CardTracker): string {
  const { trumpSuit, currentTrick, hand, partnerSeat, players } = ctx;
  if (currentTrick.length === 0) return legal[0];

  const ledCard = decodeCard(currentTrick[0].card);
  if (ledCard.isJoker) return lowest(legal);

  const ledSuit = ledCard.suit!;
  const winning = currentWinner(currentTrick, trumpSuit, ledSuit);
  const partnerUid = players[partnerSeat];
  const partnerWinning = winning?.player === partnerUid;
  const followingSuit = legal.every(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.suit === ledSuit;
  });

  // Joker poison prevention
  if (hand.length <= 2 && hand.includes('JO') && legal.includes('JO')) {
    return 'JO';
  }

  // Following suit
  if (followingSuit) {
    if (partnerWinning) return lowest(legal);
    const winners = cardsBeating(legal, currentTrick, trumpSuit, ledSuit);
    return lowest(winners.length > 0 ? winners : legal);
  }

  // Void — partner winning: dump
  if (partnerWinning) {
    if (legal.includes('JO') && hand.filter(c => c !== 'JO').length <= 1) {
      return 'JO';
    }
    return strategicDump(legal, hand, trumpSuit);
  }

  // Joker urgency
  if (legal.includes('JO')) {
    const nonJoker = legal.filter(c => c !== 'JO');
    if (nonJoker.length <= 1) return 'JO';
    let urgency = 0;
    if (hand.length <= 3) urgency += 0.3;
    const opponentTrumped = trumpSuit != null &&
      currentTrick.some(p => { const d = decodeCard(p.card); return !d.isJoker && d.suit === trumpSuit; });
    if (opponentTrumped) urgency += 0.3;
    if (urgency >= 0.3) return 'JO';
  }

  // Try to trump
  if (trumpSuit) {
    const trumpCards = legal.filter(c => {
      const d = decodeCard(c);
      return !d.isJoker && d.suit === trumpSuit;
    });
    if (trumpCards.length > 0) {
      const winningTrumps = cardsBeating(trumpCards, currentTrick, trumpSuit, ledSuit);
      return lowest(winningTrumps.length > 0 ? winningTrumps : trumpCards);
    }
  }

  return strategicDump(legal, hand, trumpSuit);
}

function strategicDump(legal: string[], hand: string[], trumpSuit?: SuitName): string {
  const dumpable = legal.filter(c => c !== 'JO');
  if (dumpable.length === 0) return legal[0];

  // Prefer singletons in non-trump suits
  const singles = dumpable.filter(c => {
    const d = decodeCard(c);
    if (d.suit === trumpSuit) return false;
    return hand.filter(h => {
      const hd = decodeCard(h);
      return !hd.isJoker && hd.suit === d.suit;
    }).length === 1;
  });
  if (singles.length > 0) {
    singles.sort((a, b) => rankVal(a) - rankVal(b));
    return singles[0];
  }

  // Avoid breaking honor combos
  const safe = dumpable.filter(c => {
    const d = decodeCard(c);
    if (d.suit === trumpSuit) return false;
    if (d.rank === 'king' && hand.some(h => { const hd = decodeCard(h); return hd.suit === d.suit && hd.rank === 'ace'; })) return false;
    if (d.rank === 'queen' && hand.some(h => { const hd = decodeCard(h); return hd.suit === d.suit && hd.rank === 'king'; })) return false;
    return true;
  });
  if (safe.length > 0) {
    safe.sort((a, b) => rankVal(a) - rankVal(b));
    return safe[0];
  }

  const nonTrump = dumpable.filter(c => decodeCard(c).suit !== trumpSuit);
  if (nonTrump.length > 0) {
    nonTrump.sort((a, b) => rankVal(a) - rankVal(b));
    return nonTrump[0];
  }

  dumpable.sort((a, b) => rankVal(a) - rankVal(b));
  return dumpable[0];
}

function rankVal(code: string): number {
  const d = decodeCard(code);
  return d.isJoker ? 15 : RANK_VALUES[d.rank!];
}

function lowest(cards: string[]): string {
  const nonJoker = cards.filter(c => c !== 'JO');
  if (nonJoker.length === 0) return cards[0];
  nonJoker.sort((a, b) => rankVal(a) - rankVal(b));
  return nonJoker[0];
}

function beats(a: string, b: string, trumpSuit: SuitName | undefined, ledSuit: SuitName): boolean {
  const da = decodeCard(a);
  const db = decodeCard(b);
  if (da.isJoker) return true;
  if (db.isJoker) return false;
  if (trumpSuit) {
    if (da.suit === trumpSuit && db.suit !== trumpSuit) return true;
    if (da.suit !== trumpSuit && db.suit === trumpSuit) return false;
    if (da.suit === trumpSuit && db.suit === trumpSuit) return RANK_VALUES[da.rank!] > RANK_VALUES[db.rank!];
  }
  if (da.suit === db.suit) return RANK_VALUES[da.rank!] > RANK_VALUES[db.rank!];
  if (da.suit === ledSuit && db.suit !== ledSuit) return true;
  return false;
}

function currentWinner(plays: TrickPlay[], trumpSuit: SuitName | undefined, ledSuit: SuitName): TrickPlay | null {
  if (plays.length === 0) return null;
  let best = plays[0];
  for (let i = 1; i < plays.length; i++) {
    if (beats(plays[i].card, best.card, trumpSuit, ledSuit)) best = plays[i];
  }
  return best;
}

function cardsBeating(candidates: string[], plays: TrickPlay[], trumpSuit: SuitName | undefined, ledSuit: SuitName): string[] {
  const best = currentWinner(plays, trumpSuit, ledSuit);
  if (!best) return candidates;
  return candidates.filter(c => beats(c, best.card, trumpSuit, ledSuit));
}

function leadFromLongestSuit(legal: string[], trumpSuit?: SuitName): string {
  const nonTrump = legal.filter(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.suit !== trumpSuit;
  });
  if (nonTrump.length === 0) {
    const nonJoker = legal.filter(c => c !== 'JO');
    nonJoker.sort((a, b) => rankVal(b) - rankVal(a));
    return nonJoker.length > 0 ? nonJoker[0] : legal[0];
  }

  const groups = new Map<SuitName, string[]>();
  for (const c of nonTrump) {
    const suit = decodeCard(c).suit!;
    if (!groups.has(suit)) groups.set(suit, []);
    groups.get(suit)!.push(c);
  }

  let longestSuit: string[] = [];
  for (const cards of groups.values()) {
    if (cards.length > longestSuit.length) longestSuit = cards;
  }

  longestSuit.sort((a, b) => rankVal(a) - rankVal(b));
  return longestSuit[0];
}
