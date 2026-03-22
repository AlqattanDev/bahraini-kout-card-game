import { SuitName, RankName, GameCard, RANK_VALUES } from './types';

const SUIT_INITIAL: Record<SuitName, string> = {
  spades: 'S',
  hearts: 'H',
  clubs: 'C',
  diamonds: 'D',
};

const INITIAL_TO_SUIT: Record<string, SuitName> = {
  S: 'spades',
  H: 'hearts',
  C: 'clubs',
  D: 'diamonds',
};

const RANK_STRING: Record<RankName, string> = {
  ace: 'A',
  king: 'K',
  queen: 'Q',
  jack: 'J',
  ten: '10',
  nine: '9',
  eight: '8',
  seven: '7',
};

const STRING_TO_RANK: Record<string, RankName> = {
  A: 'ace',
  K: 'king',
  Q: 'queen',
  J: 'jack',
  '10': 'ten',
  '9': 'nine',
  '8': 'eight',
  '7': 'seven',
};

export function encodeCard(card: GameCard): string {
  if (card.isJoker) return 'JO';
  return `${SUIT_INITIAL[card.suit!]}${RANK_STRING[card.rank!]}`;
}

export function makeCard(suit: SuitName, rank: RankName): GameCard {
  const code = `${SUIT_INITIAL[suit]}${RANK_STRING[rank]}`;
  return { suit, rank, isJoker: false, code };
}

export function makeJoker(): GameCard {
  return { suit: null, rank: null, isJoker: true, code: 'JO' };
}

export function decodeCard(encoded: string): GameCard {
  if (encoded === 'JO') return makeJoker();
  const suitChar = encoded.substring(0, 1);
  const rankStr = encoded.substring(1);
  const suit = INITIAL_TO_SUIT[suitChar];
  const rank = STRING_TO_RANK[rankStr];
  if (suit === undefined || rank === undefined) {
    throw new Error(`Invalid card encoding: ${encoded}`);
  }
  return makeCard(suit, rank);
}

export function rankValue(rank: RankName): number {
  return RANK_VALUES[rank];
}
