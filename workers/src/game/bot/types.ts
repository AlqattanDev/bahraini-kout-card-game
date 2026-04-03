import type { SuitName, TeamName, TrickPlay } from '../types';

export interface BidHistoryEntry {
  seat: number;
  action: 'bid' | 'pass';
  amount?: number;
}

export interface BotContext {
  hand: string[];
  scores: Record<TeamName, number>;
  myTeam: TeamName;
  mySeat: number;
  partnerSeat: number;
  players: string[];
  bidHistory: BidHistoryEntry[];
  currentBid: number | undefined;
  currentTrick: TrickPlay[];
  trickWinners: TeamName[];
  tricks: Record<TeamName, number>;
  roundHistory: TrickPlay[][];
  trumpSuit?: SuitName;
  isLead: boolean;
  isForced: boolean;
  isBiddingTeam: boolean;
}
