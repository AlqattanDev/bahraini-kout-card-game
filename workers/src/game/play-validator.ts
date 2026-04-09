import { SuitName } from './types';
import { decodeCard } from './card';

export interface PlayValidationResult {
  valid: boolean;
  error?: string;
}

export function validatePlay(
  card: string,
  hand: string[],
  ledSuit: SuitName | null,
  isLeadPlay: boolean,
  trumpSuit?: SuitName | null,
  isKout: boolean = false,
  isFirstTrick: boolean = false
): PlayValidationResult {
  if (!hand.includes(card)) {
    return { valid: false, error: 'card-not-in-hand' };
  }

  const cardObj = decodeCard(card);

  // Joker can never be led.
  if (isLeadPlay && cardObj.isJoker) {
    return { valid: false, error: 'joker-cannot-lead' };
  }

  // Kout rule: first trick leader must play trump if they have it.
  if (isKout && isLeadPlay && isFirstTrick && trumpSuit) {
    const hasTrump = hand.some((c) => {
      const decoded = decodeCard(c);
      return !decoded.isJoker && decoded.suit === trumpSuit;
    });
    if (hasTrump && !cardObj.isJoker && cardObj.suit !== trumpSuit) {
      return { valid: false, error: 'must-lead-trump' };
    }
  }

  if (!isLeadPlay && ledSuit !== null) {
    const hasLedSuit = hand.some((c) => {
      const decoded = decodeCard(c);
      return !decoded.isJoker && decoded.suit === ledSuit;
    });
    if (hasLedSuit && !cardObj.isJoker && cardObj.suit !== ledSuit) {
      return { valid: false, error: 'must-follow-suit' };
    }
  }

  return { valid: true };
}

export function detectPoisonJoker(hand: string[]): boolean {
  if (hand.length !== 1) return false;
  const card = decodeCard(hand[0]);
  return card.isJoker;
}

