export type SuitName = 'spades' | 'hearts' | 'clubs' | 'diamonds';
export type RankName = 'ace' | 'king' | 'queen' | 'jack' | 'ten' | 'nine' | 'eight' | 'seven';

export interface GameCard {
  suit: SuitName | null;
  rank: RankName | null;
  isJoker: boolean;
  code: string;
}

export type GamePhase = 'WAITING' | 'LOBBY' | 'DEALING' | 'BIDDING' | 'TRUMP_SELECTION' | 'PLAYING' | 'ROUND_SCORING' | 'GAME_OVER';
export type TeamName = 'teamA' | 'teamB';

export interface TrickPlay {
  player: string;
  card: string;
}

export interface BiddingState {
  currentBidder: string;
  highestBid: number | null;
  highestBidder: string | null;
  passed: string[];
}

export interface GameDocument {
  phase: GamePhase;
  players: string[];
  currentTrick: { lead: string; plays: TrickPlay[] } | null;
  tricks: Record<TeamName, number>;
  scores: Record<TeamName, number>;
  bid: { player: string; amount: number } | null;
  biddingState: BiddingState | null;
  trumpSuit: SuitName | null;
  dealer: string;
  currentPlayer: string;
  bidHistory: { player: string; action: string }[];
  roundHistory: TrickPlay[][];
  trickWinners: TeamName[];
  metadata: { createdAt: string; status: string; winner?: TeamName; roomCode?: string };
  seats?: SeatState[];
  isRoomGame?: boolean;
}

export interface SeatState {
  uid: string | null;
  isBot: boolean;
  connected: boolean;
}

export interface PendingEvent {
  type: 'bot_turn' | 'disconnect_timeout' | 'lobby_expiry' | 'round_delay';
  fireAt: number;
  meta?: string;
}

export const RANK_VALUES: Record<RankName, number> = {
  ace: 14, king: 13, queen: 12, jack: 11, ten: 10, nine: 9, eight: 8, seven: 7,
};

export const BID_SUCCESS_POINTS: Record<number, number> = { 5: 5, 6: 6, 7: 7, 8: 31 };
export const BID_FAILURE_POINTS: Record<number, number> = { 5: 10, 6: 12, 7: 14, 8: 16 };
export const TARGET_SCORE = 31;
export const POISON_JOKER_PENALTY = 10;
