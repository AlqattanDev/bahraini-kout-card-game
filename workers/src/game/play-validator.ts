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
  isLeadPlay: boolean
): PlayValidationResult {
  if (!hand.includes(card)) {
    return { valid: false, error: 'card-not-in-hand' };
  }

  const cardObj = decodeCard(card);

  // Joker CAN be led — but triggers immediate round loss (handled by game room).

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

/** Returns true when a Joker is played as the lead card of a trick. */
export function detectJokerLead(card: string, isLeadPlay: boolean): boolean {
  const decoded = decodeCard(card);
  return isLeadPlay && decoded.isJoker;
}
