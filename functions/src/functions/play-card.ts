import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { requireAuth } from '../utils/auth';
import { GameDocument, TeamName, TrickPlay } from '../game/types';
import { validatePlay, detectPoisonJoker } from '../game/play-validator';
import { resolveTrick } from '../game/trick-resolver';
import {
  calculateRoundResult,
  calculatePoisonJokerResult,
  applyScore,
  checkGameOver,
} from '../game/scorer';
import { decodeCard } from '../game/card';

export interface PlayCardInput {
  gameId: string;
  card: string;
}

export interface PlayCardResult {
  status: string;
  trickWinner?: string;
  roundResult?: { winningTeam: TeamName; points: number };
  gameOver?: boolean;
  gameWinner?: TeamName;
}

/**
 * Returns the team for the given player UID (even indices = teamA, odd = teamB).
 */
function getTeamForPlayer(players: string[], uid: string): TeamName {
  const idx = players.indexOf(uid);
  return idx % 2 === 0 ? 'teamA' : 'teamB';
}

/**
 * Core play-card logic — extracted for testability.
 */
export async function playCardLogic(
  uid: string,
  gameId: string,
  card: string,
  db: FirebaseFirestore.Firestore
): Promise<PlayCardResult> {
  const gameRef = db.collection('games').doc(gameId);
  const handRef = gameRef.collection('private').doc(uid);

  return db.runTransaction(async (tx) => {
    const [gameSnap, handSnap] = await Promise.all([
      tx.get(gameRef),
      tx.get(handRef),
    ]);

    if (!gameSnap.exists) {
      throw new HttpsError('not-found', 'Game not found');
    }
    if (!handSnap.exists) {
      throw new HttpsError('not-found', 'Hand not found');
    }

    const game = gameSnap.data() as GameDocument;
    const handData = handSnap.data() as { hand: string[] };
    const hand = handData.hand ?? [];

    if (game.phase !== 'PLAYING') {
      throw new HttpsError('failed-precondition', 'Game is not in PLAYING phase');
    }

    if (game.currentPlayer !== uid) {
      throw new HttpsError('failed-precondition', 'Not your turn to play');
    }

    // ─── Poison Joker Pre-check ───────────────────────────────────────────────
    if (detectPoisonJoker(hand)) {
      const poisonTeam = getTeamForPlayer(game.players, uid);
      const roundResult = calculatePoisonJokerResult(poisonTeam);
      const newScores = applyScore(game.scores, roundResult.winningTeam, roundResult.points);
      const gameWinner = checkGameOver(newScores);

      tx.update(gameRef, {
        phase: gameWinner ? 'GAME_OVER' : 'ROUND_SCORING',
        scores: newScores,
        ...(gameWinner ? { metadata: { ...game.metadata, status: 'completed', winner: gameWinner } } : {}),
      });
      // Remove poison joker from hand
      tx.update(handRef, { hand: [] });

      return {
        status: 'poison-joker',
        roundResult,
        gameOver: !!gameWinner,
        gameWinner: gameWinner ?? undefined,
      };
    }

    // ─── Validate play ────────────────────────────────────────────────────────
    const currentTrick = game.currentTrick!;
    const isLeadPlay = currentTrick.plays.length === 0;
    const ledSuit = isLeadPlay
      ? null
      : (() => {
          const leadCard = decodeCard(currentTrick.plays[0].card);
          return leadCard.isJoker ? null : leadCard.suit;
        })();

    const validation = validatePlay(card, hand, ledSuit, isLeadPlay);
    if (!validation.valid) {
      throw new HttpsError('failed-precondition', validation.error ?? 'Invalid play');
    }

    // ─── Remove card from hand ────────────────────────────────────────────────
    const newHand = hand.filter((c) => c !== card);
    tx.update(handRef, { hand: newHand });

    // ─── Add play to current trick ────────────────────────────────────────────
    const newPlay: TrickPlay = { player: uid, card };
    const newPlays = [...currentTrick.plays, newPlay];

    if (newPlays.length < 4) {
      // Trick not complete — advance to next player
      const currentIndex = game.players.indexOf(uid);
      const nextPlayer = game.players[(currentIndex + 1) % game.players.length];

      tx.update(gameRef, {
        currentTrick: { ...currentTrick, plays: newPlays },
        currentPlayer: nextPlayer,
      });

      return { status: 'card-played' };
    }

    // ─── Resolve trick ────────────────────────────────────────────────────────
    const completedPlays = newPlays;
    const leadCardCode = completedPlays[0].card;
    const leadCardObj = decodeCard(leadCardCode);
    const resolvedLedSuit = leadCardObj.isJoker
      ? game.trumpSuit!  // Joker lead: trumpSuit is used as fallback (shouldn't normally happen)
      : leadCardObj.suit!;

    const trickWinner = resolveTrick(completedPlays, resolvedLedSuit, game.trumpSuit!);
    const winnerTeam = getTeamForPlayer(game.players, trickWinner);

    const newTricks: Record<TeamName, number> = {
      teamA: game.tricks.teamA + (winnerTeam === 'teamA' ? 1 : 0),
      teamB: game.tricks.teamB + (winnerTeam === 'teamB' ? 1 : 0),
    };

    const totalTricks = newTricks.teamA + newTricks.teamB;

    if (totalTricks < 8) {
      // More tricks to play
      tx.update(gameRef, {
        currentTrick: { lead: trickWinner, plays: [] },
        currentPlayer: trickWinner,
        tricks: newTricks,
        roundHistory: [...(game.roundHistory ?? []), completedPlays],
      });

      return { status: 'trick-won', trickWinner };
    }

    // ─── Round complete (8 tricks done) ───────────────────────────────────────
    const bidInfo = game.bid!;
    const biddingTeam = getTeamForPlayer(game.players, bidInfo.player);
    const roundResult = calculateRoundResult(bidInfo.amount, biddingTeam, newTricks);
    const newScores = applyScore(game.scores, roundResult.winningTeam, roundResult.points);
    const gameWinner = checkGameOver(newScores);

    tx.update(gameRef, {
      phase: gameWinner ? 'GAME_OVER' : 'ROUND_SCORING',
      scores: newScores,
      tricks: newTricks,
      roundHistory: [...(game.roundHistory ?? []), completedPlays],
      currentTrick: null,
      ...(gameWinner ? { metadata: { ...game.metadata, status: 'completed', winner: gameWinner } } : {}),
    });

    return {
      status: 'round-complete',
      trickWinner,
      roundResult,
      gameOver: !!gameWinner,
      gameWinner: gameWinner ?? undefined,
    };
  });
}

export const playCard = onCall(async (request) => {
  const uid = requireAuth(request);
  const { gameId, card } = request.data as PlayCardInput;
  const db = getFirestore();
  return playCardLogic(uid, gameId, card, db);
});
