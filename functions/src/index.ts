// functions/src/index.ts
import * as admin from 'firebase-admin';
admin.initializeApp();

export { joinQueue } from './functions/join-queue';
export { leaveQueue } from './functions/leave-queue';
export { matchPlayers } from './matchmaking/match-players';
export { placeBid } from './functions/place-bid';
export { selectTrump } from './functions/select-trump';
export { playCard } from './functions/play-card';
export { getMyHand } from './functions/get-my-hand';
