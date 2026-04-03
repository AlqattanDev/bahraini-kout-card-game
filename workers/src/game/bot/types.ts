import type { SuitName, TeamName, TrickPlay } from '../types';

export interface BotContext {
  hand: string[];
  scores: Record<TeamName, number>;
  myTeam: TeamName;
  mySeat: number;
  partnerSeat: number;
  players: string[];
  bidHistory: { seat: number; action: string }[];
  trumpSuit: SuitName | undefined;
  currentBid: number | undefined;
  currentTrick: TrickPlay[];
  trickWinners: TeamName[];
  tricks: Record<TeamName, number>;
  roundHistory: TrickPlay[][];
  isLead: boolean;
  isForced: boolean;
  isBiddingTeam: boolean;
}

export function teamForSeat(seat: number): TeamName {
  return seat % 2 === 0 ? 'teamA' : 'teamB';
}
