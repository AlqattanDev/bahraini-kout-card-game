import { decodeCard } from '../card';
import { RANK_VALUES } from '../types';
import type { SuitName, TrickPlay } from '../types';

const ALL_CARDS: string[] = (() => {
  const suits: SuitName[] = ['spades', 'hearts', 'clubs', 'diamonds'];
  const ranks = ['A', 'K', 'Q', 'J', '10', '9', '8', '7'];
  const cards: string[] = ['JO'];
  for (const suit of suits) {
    const prefix = suit === 'spades' ? 'S' : suit === 'hearts' ? 'H' : suit === 'clubs' ? 'C' : 'D';
    for (const rank of ranks) {
      // Diamonds has no 7
      if (suit === 'diamonds' && rank === '7') continue;
      cards.push(`${prefix}${rank}`);
    }
  }
  return cards;
})();

export class CardTracker {
  private _played = new Set<string>();
  private _knownVoids = new Map<number, Set<SuitName>>();

  recordPlay(card: string): void {
    this._played.add(card);
  }

  recordTrick(plays: TrickPlay[]): void {
    for (const p of plays) {
      this._played.add(p.card);
    }
  }

  inferVoid(seat: number, suit: SuitName): void {
    if (!this._knownVoids.has(seat)) this._knownVoids.set(seat, new Set());
    this._knownVoids.get(seat)!.add(suit);
  }

  get playedCards(): ReadonlySet<string> {
    return this._played;
  }

  remainingCards(myHand: string[]): Set<string> {
    const myHandSet = new Set(myHand);
    const result = new Set<string>();
    for (const c of ALL_CARDS) {
      if (!this._played.has(c) && !myHandSet.has(c)) {
        result.add(c);
      }
    }
    return result;
  }

  trumpsRemaining(trumpSuit: SuitName, myHand: string[]): number {
    const remaining = this.remainingCards(myHand);
    let count = 0;
    for (const c of remaining) {
      const d = decodeCard(c);
      if (!d.isJoker && d.suit === trumpSuit) count++;
    }
    return count;
  }

  isHighestRemaining(card: string, myHand: string[]): boolean {
    const d = decodeCard(card);
    if (d.isJoker) return true;
    const suit = d.suit!;
    const remaining = this.remainingCards(myHand);
    let highestRemaining = 0;
    for (const c of remaining) {
      const cd = decodeCard(c);
      if (!cd.isJoker && cd.suit === suit) {
        const v = RANK_VALUES[cd.rank!];
        if (v > highestRemaining) highestRemaining = v;
      }
    }
    if (highestRemaining === 0) return true;
    return RANK_VALUES[d.rank!] > highestRemaining;
  }

  isSuitExhausted(suit: SuitName, myHand: string[]): boolean {
    const remaining = this.remainingCards(myHand);
    for (const c of remaining) {
      const d = decodeCard(c);
      if (!d.isJoker && d.suit === suit) return false;
    }
    return true;
  }

  reset(): void {
    this._played.clear();
    this._knownVoids.clear();
  }
}
