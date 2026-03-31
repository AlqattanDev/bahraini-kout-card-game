import { SuitName, TrickPlay, RANK_VALUES } from './types';
import { decodeCard } from './card';

export function resolveTrick(
  plays: TrickPlay[],
  ledSuit: SuitName,
  trumpSuit: SuitName
): string {
  // Rule 1: Joker always wins
  for (const play of plays) {
    const card = decodeCard(play.card);
    if (card.isJoker) return play.player;
  }

  // Rule 2: Highest trump wins (if any trump played)
  const trumpPlays = plays.filter((p) => {
    const card = decodeCard(p.card);
    return !card.isJoker && card.suit === trumpSuit;
  });

  if (trumpPlays.length > 0) {
    trumpPlays.sort((a, b) => {
      const cardA = decodeCard(a.card);
      const cardB = decodeCard(b.card);
      return RANK_VALUES[cardB.rank!] - RANK_VALUES[cardA.rank!];
    });
    return trumpPlays[0].player;
  }

  // Rule 3: Highest card of led suit wins
  const ledSuitPlays = plays.filter((p) => {
    const card = decodeCard(p.card);
    return !card.isJoker && card.suit === ledSuit;
  });

  ledSuitPlays.sort((a, b) => {
    const cardA = decodeCard(a.card);
    const cardB = decodeCard(b.card);
    return RANK_VALUES[cardB.rank!] - RANK_VALUES[cardA.rank!];
  });

  return ledSuitPlays[0].player;
}
