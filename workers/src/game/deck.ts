import { SuitName, RankName, GameCard } from './types';
import { makeCard, makeJoker } from './card';

const FULL_SUITS: SuitName[] = ['spades', 'hearts', 'clubs'];
const ALL_RANKS: RankName[] = ['ace', 'king', 'queen', 'jack', 'ten', 'nine', 'eight', 'seven'];
const DIAMOND_RANKS: RankName[] = ['ace', 'king', 'queen', 'jack', 'ten', 'nine', 'eight'];

export function buildFourPlayerDeck(): GameCard[] {
  const cards: GameCard[] = [];

  for (const suit of FULL_SUITS) {
    for (const rank of ALL_RANKS) {
      cards.push(makeCard(suit, rank));
    }
  }

  // Diamonds: all ranks except seven
  for (const rank of DIAMOND_RANKS) {
    cards.push(makeCard('diamonds', rank));
  }

  cards.push(makeJoker());
  return cards;
}

function shuffle<T>(arr: T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export function dealHands(deck: GameCard[]): [GameCard[], GameCard[], GameCard[], GameCard[]] {
  const shuffled = shuffle(deck);
  const cardsPerPlayer = Math.floor(shuffled.length / 4);
  return [
    shuffled.slice(0, cardsPerPlayer),
    shuffled.slice(cardsPerPlayer, cardsPerPlayer * 2),
    shuffled.slice(cardsPerPlayer * 2, cardsPerPlayer * 3),
    shuffled.slice(cardsPerPlayer * 3, cardsPerPlayer * 4),
  ];
}
