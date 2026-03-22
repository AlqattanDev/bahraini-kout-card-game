import { SuitName } from './types';
import { decodeCard } from './card';

export interface PlayValidationResult {
  valid: boolean;
  error?: string;
}

/**
 * Validates whether a card play is legal.
 */
export function validatePlay(
  card: string,
  hand: string[],
  ledSuit: SuitName | null,
  isLeadPlay: boolean
): PlayValidationResult {
  if (!hand.includes(card)) {
    return { valid: false, error: 'card-not-in-hand' };
  }

  const cardObj = decodeCard(card);

  if (isLeadPlay && cardObj.isJoker) {
    return { valid: false, error: 'cannot-lead-joker' };
  }

  if (!isLeadPlay && ledSuit !== null) {
    const hasLedSuit = hand.some((c) => {
      const decoded = decodeCard(c);
      return !decoded.isJoker && decoded.suit === ledSuit;
    });
    if (hasLedSuit && (cardObj.isJoker || cardObj.suit !== ledSuit)) {
      return { valid: false, error: 'must-follow-suit' };
    }
  }

  return { valid: true };
}

/**
 * Returns true if the hand contains exactly one card and it is the Joker.
 */
export function detectPoisonJoker(hand: string[]): boolean {
  if (hand.length !== 1) return false;
  const card = decodeCard(hand[0]);
  return card.isJoker;
}
