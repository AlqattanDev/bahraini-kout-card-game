import { decodeCard, beatsCard } from '../card';
import { RANK_VALUES, TRICKS_PER_ROUND } from '../types';
import type { SuitName, TrickPlay } from '../types';
import type { CardTracker } from './card-tracker';
import type { BotContext } from './types';

export function decidePlay(ctx: BotContext, tracker: CardTracker): string {
  const isKout = ctx.currentBid === 8;
  const isFirstTrick = ctx.trickWinners.length === 0;
  const legal = getLegalPlays(ctx.hand, ctx.currentTrick, ctx.trumpSuit, ctx.isLead, isKout, isFirstTrick);
  if (legal.length === 1) return legal[0];

  if (ctx.isLead) {
    return selectLead(legal, ctx, tracker);
  }
  return selectFollow(legal, ctx, tracker);
}

function getLegalPlays(
  hand: string[], trick: TrickPlay[], trumpSuit: SuitName | undefined, isLead: boolean,
  isKout: boolean = false, isFirstTrick: boolean = false,
): string[] {
  if (isLead) {
    // Kout first trick: must lead trump if you have any (matches PlayValidator).
    if (isKout && isFirstTrick && trumpSuit) {
      const trumpCards = hand.filter(c => {
        const d = decodeCard(c);
        return !d.isJoker && d.suit === trumpSuit;
      });
      if (trumpCards.length > 0) return trumpCards;
    }
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

  // Master card leads — non-trump before trump.
  const masters = legal.filter(c => {
    const d = decodeCard(c);
    return !d.isJoker && tracker.isHighestRemaining(c, hand);
  });
  if (masters.length > 0) {
    // Non-trump masters first, sorted by rank descending.
    const nonTrumpMasters = masters.filter(c => decodeCard(c).suit !== trumpSuit);
    const pool = nonTrumpMasters.length > 0 ? nonTrumpMasters : masters;
    pool.sort((a, b) => rankVal(b) - rankVal(a));
    return pool[0];
  }

  // Non-trump aces — prefer A-K combo.
  const aces = legal.filter(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.rank === 'ace' && d.suit !== trumpSuit;
  });
  if (aces.length > 0) {
    const aceWithKing = aces.find(a => {
      const suit = decodeCard(a).suit!;
      return hand.some(h => { const hd = decodeCard(h); return !hd.isJoker && hd.suit === suit && hd.rank === 'king'; });
    });
    return aceWithKing ?? aces[0];
  }

  // 3. Singleton voids — lead a singleton non-trump card when you have trump (play_strategy.dart).
  if (trumpSuit) {
    const hasTrump = hand.some(c => {
      const d = decodeCard(c);
      return !d.isJoker && d.suit === trumpSuit;
    });
    if (hasTrump) {
      const singletons = legal.filter(c => {
        const d = decodeCard(c);
        if (d.isJoker || d.suit === trumpSuit) return false;
        const count = hand.filter(h => {
          const hd = decodeCard(h);
          return !hd.isJoker && hd.suit === d.suit;
        }).length;
        return count === 1;
      });
      if (singletons.length > 0) {
        singletons.sort((a, b) => rankVal(a) - rankVal(b));
        return singletons[0];
      }
    }
  }

  // 4. Trump strip — bidding team with 3+ trumps: lead highest trump.
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

  // 5. Partner void exploit.
  const partnerVoids = tracker.knownVoids.get(ctx.partnerSeat);
  if (partnerVoids && partnerVoids.size > 0) {
    for (const voidSuit of partnerVoids) {
      if (voidSuit === trumpSuit) continue;
      const suitCards = legal.filter(c => {
        const d = decodeCard(c);
        return !d.isJoker && d.suit === voidSuit;
      });
      if (suitCards.length > 0) {
        suitCards.sort((a, b) => rankVal(a) - rankVal(b));
        return suitCards[0];
      }
    }
  }

  return leadFromLongestSuit(legal, trumpSuit);
}

function selectFollow(legal: string[], ctx: BotContext, tracker: CardTracker): string {
  const { trumpSuit, currentTrick, hand, partnerSeat, players } = ctx;
  if (currentTrick.length === 0) return legal[0];

  const ledCard = decodeCard(currentTrick[0].card);
  if (ledCard.isJoker) return lowest(legal);

  const ledSuit = ledCard.suit!;
  const myPosition = currentTrick.length; // 1=2nd, 2=3rd, 3=4th
  const winning = currentWinner(currentTrick, trumpSuit, ledSuit);
  const partnerUid = players[partnerSeat];
  const partnerWinning = winning?.player === partnerUid;
  const followingSuit = legal.some(c => {
    const d = decodeCard(c);
    return !d.isJoker && d.suit === ledSuit;
  });
  const hasJoker = legal.includes('JO');
  const tricksRemaining = TRICKS_PER_ROUND - (ctx.trickWinners.length);

  // Joker countdown.
  if (tricksRemaining <= 2 && hasJoker) {
    return 'JO';
  }

  // Poison prevention.
  if (hand.length <= 2 && hasJoker && legal.includes('JO')) {
    return 'JO';
  }

  if (followingSuit) {
    return followSuit(legal, currentTrick, trumpSuit, ledSuit, partnerWinning, myPosition, hasJoker);
  }

  return voidFollow(legal, hand, currentTrick, trumpSuit, ledSuit, partnerWinning, myPosition, hasJoker, tracker);
}

function followSuit(
  legal: string[],
  trickPlays: TrickPlay[],
  trumpSuit: SuitName | undefined,
  ledSuit: SuitName,
  partnerWinning: boolean,
  myPosition: number,
  hasJoker: boolean,
): string {
  const suitCards = legal.filter(c => { const d = decodeCard(c); return !d.isJoker && d.suit === ledSuit; });
  const canBeat = cardsBeating(suitCards, trickPlays, trumpSuit, ledSuit);

  // Partner winning → play lowest.
  if (partnerWinning) return lowest(suitCards);

  if (canBeat.length > 0) {
    // Last to play: lowest winner suffices.
    if (myPosition === 3) return lowest(canBeat);
    // Otherwise: highest winner.
    return highest(canBeat);
  }

  // Cannot beat with suit cards.
  // Last to play + have Joker → play Joker to salvage the trick.
  if (myPosition === 3 && hasJoker) return 'JO';

  // Not last or no Joker → play lowest suit card.
  return lowest(suitCards);
}

function voidFollow(
  legal: string[],
  hand: string[],
  trickPlays: TrickPlay[],
  trumpSuit: SuitName | undefined,
  ledSuit: SuitName,
  partnerWinning: boolean,
  myPosition: number,
  hasJoker: boolean,
  tracker: CardTracker,
): string {
  const trumpCards = trumpSuit
    ? legal.filter(c => { const d = decodeCard(c); return !d.isJoker && d.suit === trumpSuit; })
    : [];
  const winningTrumps = cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);

  // Partner winning safely (last to play) → dump.
  if (partnerWinning && myPosition === 3) {
    return strategicDump(legal, hand, trumpSuit);
  }

  // Partner winning but opponent still to play → consider trumping to guarantee.
  if (partnerWinning) {
    if (trumpCards.length > 0 && trumpSuit) {
      const trumpsOut = tracker.trumpsRemaining(trumpSuit, hand);
      if (trumpsOut === 0) {
        // No opponent trumps remaining — any trump guarantees.
        return lowest(trumpCards);
      }
      // Check if my highest trump beats all remaining trump.
      const remaining = tracker.remainingCards(hand);
      const remainingTrumps = remaining.filter(c => { const d = decodeCard(c); return !d.isJoker && d.suit === trumpSuit; });
      const myHighestTrump = trumpCards.reduce((best, c) => rankVal(c) > rankVal(best) ? c : best, trumpCards[0]);
      const canGuarantee = remainingTrumps.every(c => rankVal(myHighestTrump) > rankVal(c));
      if (canGuarantee) return myHighestTrump;
    }
    return strategicDump(legal, hand, trumpSuit);
  }

  // Opponent winning + have winning trump → play lowest winning trump.
  if (winningTrumps.length > 0) return lowest(winningTrumps);

  // Opponent winning + have trump but none beat current winner → play lowest trump.
  if (trumpCards.length > 0) return lowest(trumpCards);

  // Can't win with trump → try Joker if it would win.
  if (hasJoker) {
    const nonJokerCanWin = cardsBeating(
      legal.filter(c => c !== 'JO'),
      trickPlays,
      trumpSuit,
      ledSuit,
    ).length > 0;
    if (!nonJokerCanWin) return 'JO';
  }

  // No trump, no Joker, can't win → dump.
  return strategicDump(legal, hand, trumpSuit);
}

function strategicDump(legal: string[], hand: string[], trumpSuit?: SuitName): string {
  const dumpable = legal.filter(c => c !== 'JO');
  if (dumpable.length === 0) return legal[0];

  // Tier 1: Singletons in non-trump suits (create voids).
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

  // Tier 2: Avoid breaking honor combos.
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

  // Tier 3: Lowest non-trump.
  const nonTrump = dumpable.filter(c => decodeCard(c).suit !== trumpSuit);
  if (nonTrump.length > 0) {
    nonTrump.sort((a, b) => rankVal(a) - rankVal(b));
    return nonTrump[0];
  }

  // Only trump remains — prefer Joker over wasting a trump.
  if (legal.includes('JO')) return 'JO';

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

function highest(cards: string[]): string {
  const nonJoker = cards.filter(c => c !== 'JO');
  if (nonJoker.length === 0) return cards[0];
  nonJoker.sort((a, b) => rankVal(b) - rankVal(a));
  return nonJoker[0];
}

function currentWinner(plays: TrickPlay[], trumpSuit: SuitName | undefined, ledSuit: SuitName): TrickPlay | null {
  if (plays.length === 0) return null;
  let best = plays[0];
  for (let i = 1; i < plays.length; i++) {
    if (beatsCard(plays[i].card, best.card, trumpSuit, ledSuit)) best = plays[i];
  }
  return best;
}

function cardsBeating(candidates: string[], plays: TrickPlay[], trumpSuit: SuitName | undefined, ledSuit: SuitName): string[] {
  const best = currentWinner(plays, trumpSuit, ledSuit);
  if (!best) return candidates;
  return candidates.filter(c => beatsCard(c, best.card, trumpSuit, ledSuit));
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

  // Sort by length descending, then by max rank descending (Dart tiebreak).
  const sortedSuits = [...groups.entries()].sort((a, b) => {
    const lenDiff = b[1].length - a[1].length;
    if (lenDiff !== 0) return lenDiff;
    const aMax = Math.max(...a[1].map(rankVal));
    const bMax = Math.max(...b[1].map(rankVal));
    return bMax - aMax;
  });

  const best = sortedSuits[0][1];
  best.sort((a, b) => rankVal(a) - rankVal(b));
  return best[0];
}
