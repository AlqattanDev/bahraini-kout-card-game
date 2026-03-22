import {
  buildDisconnectTimer,
  disconnectTimerDocId,
  DISCONNECT_GRACE_PERIOD_MS,
  PresenceExpiredPayload,
} from '../../src/presence/presence-monitor';
import {
  evaluateDisconnect,
  DEFAULT_DISCONNECT_PENALTY,
  DisconnectCheckInput,
} from '../../src/presence/disconnect-handler';

// ─── presence-monitor: buildDisconnectTimer ───────────────────────────────────

describe('buildDisconnectTimer', () => {
  const payload: PresenceExpiredPayload = { uid: 'player1', gameId: 'game-abc' };
  const now = new Date('2026-03-23T10:00:00.000Z');

  it('presence expired → disconnect timer doc is created with 90-second expiry', () => {
    const timer = buildDisconnectTimer(payload, now);

    expect(timer.uid).toBe('player1');
    expect(timer.gameId).toBe('game-abc');
    expect(timer.createdAt).toEqual(now);
    expect(timer.expiresAt.getTime()).toBe(now.getTime() + DISCONNECT_GRACE_PERIOD_MS);
  });

  it('expiresAt is exactly 90 seconds after createdAt', () => {
    const timer = buildDisconnectTimer(payload, now);
    const diffMs = timer.expiresAt.getTime() - timer.createdAt.getTime();
    expect(diffMs).toBe(90_000);
  });

  it('timer doc contains correct uid and gameId', () => {
    const timer = buildDisconnectTimer({ uid: 'uid-xyz', gameId: 'game-999' }, now);
    expect(timer.uid).toBe('uid-xyz');
    expect(timer.gameId).toBe('game-999');
  });
});

describe('disconnectTimerDocId', () => {
  it('generates a predictable document ID', () => {
    expect(disconnectTimerDocId('game-abc', 'player1')).toBe('game-abc_player1');
  });

  it('is unique per game-player combination', () => {
    const id1 = disconnectTimerDocId('game-1', 'uid-a');
    const id2 = disconnectTimerDocId('game-1', 'uid-b');
    const id3 = disconnectTimerDocId('game-2', 'uid-a');
    expect(id1).not.toBe(id2);
    expect(id1).not.toBe(id3);
  });
});

// ─── disconnect-handler: evaluateDisconnect ───────────────────────────────────

describe('evaluateDisconnect', () => {
  const baseInput: DisconnectCheckInput = {
    uid: 'player1',
    gameId: 'game-abc',
    isPresent: false,
    hasBid: false,
    playerTeam: 'teamA',
    scores: { teamA: 0, teamB: 0 },
  };

  // Reconnection within 90s → timer cancelled
  it('reconnection within 90s → timer cancelled', () => {
    const result = evaluateDisconnect({ ...baseInput, isPresent: true });

    expect(result.action).toBe('cancel');
    if (result.action === 'cancel') {
      expect(result.reason).toBe('reconnected');
    }
  });

  // No reconnection → forfeit
  it('no reconnection → game forfeited with default penalty (+10) when no bid active', () => {
    const result = evaluateDisconnect({ ...baseInput, isPresent: false, hasBid: false });

    expect(result.action).toBe('forfeit');
    if (result.action === 'forfeit') {
      expect(result.penaltyPoints).toBe(DEFAULT_DISCONNECT_PENALTY); // 10
      expect(result.penaltyAgainstTeam).toBe('teamA');
      expect(result.winningTeam).toBe('teamB');
      expect(result.newScores.teamB).toBe(10);
      expect(result.newScores.teamA).toBe(0);
    }
  });

  it('no reconnection with active bid of 5 → penalty is BID_FAILURE_POINTS[5] = 10', () => {
    const result = evaluateDisconnect({
      ...baseInput,
      isPresent: false,
      hasBid: true,
      bidAmount: 5,
      playerTeam: 'teamA',
    });

    expect(result.action).toBe('forfeit');
    if (result.action === 'forfeit') {
      expect(result.penaltyPoints).toBe(10); // BID_FAILURE_POINTS[5]
      expect(result.winningTeam).toBe('teamB');
    }
  });

  it('no reconnection with active bid of 7 → penalty is BID_FAILURE_POINTS[7] = 14', () => {
    const result = evaluateDisconnect({
      ...baseInput,
      isPresent: false,
      hasBid: true,
      bidAmount: 7,
      playerTeam: 'teamB',
      scores: { teamA: 5, teamB: 0 },
    });

    expect(result.action).toBe('forfeit');
    if (result.action === 'forfeit') {
      expect(result.penaltyPoints).toBe(14); // BID_FAILURE_POINTS[7]
      expect(result.winningTeam).toBe('teamA');
      expect(result.newScores.teamA).toBe(5 + 14); // existing + penalty
      expect(result.newScores.teamB).toBe(0);
    }
  });

  it('no reconnection with active bid of 8 (kout) → penalty is 31', () => {
    const result = evaluateDisconnect({
      ...baseInput,
      isPresent: false,
      hasBid: true,
      bidAmount: 8,
      playerTeam: 'teamA',
    });

    expect(result.action).toBe('forfeit');
    if (result.action === 'forfeit') {
      expect(result.penaltyPoints).toBe(31); // BID_FAILURE_POINTS[8]
    }
  });

  it('forfeit adds penalty to opponent team score (existing scores preserved)', () => {
    const result = evaluateDisconnect({
      ...baseInput,
      isPresent: false,
      hasBid: false,
      playerTeam: 'teamA',
      scores: { teamA: 15, teamB: 8 },
    });

    expect(result.action).toBe('forfeit');
    if (result.action === 'forfeit') {
      expect(result.newScores.teamA).toBe(15); // unchanged
      expect(result.newScores.teamB).toBe(8 + DEFAULT_DISCONNECT_PENALTY); // 18
    }
  });

  it('forfeit from teamB player awards penalty to teamA', () => {
    const result = evaluateDisconnect({
      ...baseInput,
      isPresent: false,
      playerTeam: 'teamB',
      scores: { teamA: 0, teamB: 0 },
    });

    expect(result.action).toBe('forfeit');
    if (result.action === 'forfeit') {
      expect(result.winningTeam).toBe('teamA');
      expect(result.penaltyAgainstTeam).toBe('teamB');
      expect(result.newScores.teamA).toBe(DEFAULT_DISCONNECT_PENALTY);
    }
  });
});
