import { decodeCard } from '../card';
import { buildFourPlayerDeck } from '../deck';
import type { SuitName, TrickPlay } from '../types';
import { RANK_VALUES } from '../types';

export class CardTracker {
  private played = new Set<string>();
  private _knownVoids = new Map<number, Set<SuitName>>();

  recordTrick(plays: TrickPlay[]): void {
    for (const play of plays) this.played.add(play.card);
  }

  recordPlay(_seat: number, card: string): void {
    this.played.add(card);
  }

  inferVoid(seat: number, suit: SuitName): void {
    if (!this._knownVoids.has(seat)) this._knownVoids.set(seat, new Set());
    this._knownVoids.get(seat)!.add(suit);
  }

  get knownVoids(): Map<number, Set<SuitName>> {
    return this._knownVoids;
  }

  remainingCards(myHand: string[]): string[] {
    const allCodes = buildFourPlayerDeck().map(c => c.code);
    const held = new Set(myHand);
    return allCodes.filter(c => !this.played.has(c) && !held.has(c));
  }

  isHighestRemaining(card: string, myHand: string[]): boolean {
    const decoded = decodeCard(card);
    if (decoded.isJoker) return true;
    const suit = decoded.suit!;
    const value = RANK_VALUES[decoded.rank!];
    const remaining = this.remainingCards(myHand);
    for (const c of remaining) {
      const d = decodeCard(c);
      if (!d.isJoker && d.suit === suit && RANK_VALUES[d.rank!] > value) return false;
    }
    return true;
  }

  isSuitExhausted(suit: SuitName, myHand: string[]): boolean {
    return !this.remainingCards(myHand).some(c => {
      const d = decodeCard(c);
      return !d.isJoker && d.suit === suit;
    });
  }

  trumpsRemaining(trumpSuit: SuitName, myHand: string[]): number {
    return this.remainingCards(myHand).filter(c => {
      const d = decodeCard(c);
      return !d.isJoker && d.suit === trumpSuit;
    }).length;
  }

  reset(): void {
    this.played.clear();
    this._knownVoids.clear();
  }
}
