import { calculateBracket, findBestMatch, QueuedPlayer } from '../../src/matchmaking/match-players';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makePlayer(uid: string, elo: number, secsAgo = 0): QueuedPlayer {
  return {
    uid,
    eloRating: elo,
    queuedAt: new Date(Date.now() - secsAgo * 1000),
  };
}

// ─── calculateBracket ─────────────────────────────────────────────────────────

describe('calculateBracket', () => {
  it('returns ±200 for a player who just joined (0 seconds)', () => {
    const queuedAt = new Date(); // right now
    expect(calculateBracket(queuedAt)).toBe(200);
  });

  it('returns ±200 for a player waiting 14 seconds', () => {
    const queuedAt = new Date(Date.now() - 14_000);
    expect(calculateBracket(queuedAt)).toBe(200);
  });

  it('returns ±300 after 15 seconds', () => {
    const queuedAt = new Date(Date.now() - 15_000);
    expect(calculateBracket(queuedAt)).toBe(300);
  });

  it('returns ±300 after 29 seconds', () => {
    const queuedAt = new Date(Date.now() - 29_000);
    expect(calculateBracket(queuedAt)).toBe(300);
  });

  it('returns ±400 after 30 seconds', () => {
    const queuedAt = new Date(Date.now() - 30_000);
    expect(calculateBracket(queuedAt)).toBe(400);
  });

  it('returns ±500 after 45 seconds (cap)', () => {
    const queuedAt = new Date(Date.now() - 45_000);
    expect(calculateBracket(queuedAt)).toBe(500);
  });

  it('bracket is capped at ±500 regardless of wait time', () => {
    const queuedAt = new Date(Date.now() - 3_600_000); // 1 hour ago
    expect(calculateBracket(queuedAt)).toBe(500);
  });
});

// ─── findBestMatch ────────────────────────────────────────────────────────────

describe('findBestMatch', () => {
  it('returns null when fewer than 4 players are queued', () => {
    const players = [makePlayer('a', 1000), makePlayer('b', 1100), makePlayer('c', 1200)];
    expect(findBestMatch(players)).toBeNull();
  });

  it('4 players within ±200 ELO match immediately (0 wait time)', () => {
    // All joined now — bracket is ±200
    // Spread = 1150 - 1000 = 150 ≤ 200*2 = 400 → should match
    const players = [
      makePlayer('p1', 1000, 0),
      makePlayer('p2', 1050, 0),
      makePlayer('p3', 1100, 0),
      makePlayer('p4', 1150, 0),
    ];
    const group = findBestMatch(players);
    expect(group).not.toBeNull();
    expect(group).toHaveLength(4);
    const uids = group!.map((p) => p.uid).sort();
    expect(uids).toEqual(['p1', 'p2', 'p3', 'p4']);
  });

  it('players outside ±200 do NOT match immediately (spread 450 > 200 bracket)', () => {
    // Spread of 450 exceeds initial bracket of ±200 (max allowed spread = 400)
    const players = [
      makePlayer('p1', 1000, 0),
      makePlayer('p2', 1100, 0),
      makePlayer('p3', 1300, 0),
      makePlayer('p4', 1450, 0),
    ];
    const group = findBestMatch(players);
    expect(group).toBeNull();
  });

  it('players outside initial ±200 DO match after waiting 30s (bracket expands to ±400)', () => {
    // Spread = 1350 - 1000 = 350. With ±400 bracket (30s wait), spread 350 ≤ 800 → match
    const players = [
      makePlayer('p1', 1000, 30), // waited 30s → bracket ±400
      makePlayer('p2', 1100, 30),
      makePlayer('p3', 1250, 30),
      makePlayer('p4', 1350, 30),
    ];
    const group = findBestMatch(players);
    expect(group).not.toBeNull();
    expect(group).toHaveLength(4);
  });

  it('bracket caps at ±500 — players spread > 1000 do NOT match even with long wait', () => {
    // Spread = 1100 > 1000 (cap = ±500 → max spread = 1000)
    const players = [
      makePlayer('p1', 1000, 3600), // waited 1 hour → bracket ±500
      makePlayer('p2', 1200, 3600),
      makePlayer('p3', 1800, 3600),
      makePlayer('p4', 2100, 3600), // spread from p1 = 1100
    ];
    const group = findBestMatch(players);
    expect(group).toBeNull();
  });

  it('bracket caps at ±500 — players within spread 1000 DO match after long wait', () => {
    // Spread = 950 ≤ 1000 (cap bracket ±500 → max spread = 1000) → should match
    const players = [
      makePlayer('p1', 1000, 3600),
      makePlayer('p2', 1300, 3600),
      makePlayer('p3', 1700, 3600),
      makePlayer('p4', 1950, 3600), // spread = 950
    ];
    const group = findBestMatch(players);
    expect(group).not.toBeNull();
    expect(group).toHaveLength(4);
  });

  it('picks the closest-ELO group when multiple valid windows exist', () => {
    // 6 players; the 4 clustered together should be preferred over outliers
    const players = [
      makePlayer('outlier-low', 500, 3600),
      makePlayer('a', 1190, 30),
      makePlayer('b', 1200, 30),
      makePlayer('c', 1210, 30),
      makePlayer('d', 1220, 30),
      makePlayer('outlier-high', 2000, 3600),
    ];
    const group = findBestMatch(players);
    expect(group).not.toBeNull();
    const uids = group!.map((p) => p.uid);
    expect(uids).toContain('a');
    expect(uids).toContain('b');
    expect(uids).toContain('c');
    expect(uids).toContain('d');
    expect(uids).not.toContain('outlier-low');
    expect(uids).not.toContain('outlier-high');
  });

  it('a single long-waiting player expands the bracket for the whole group', () => {
    // p1 waited 30s → bracket ±400. Others joined just now (bracket ±200).
    // The max bracket in the group is ±400, so spread up to 800 is allowed.
    // Spread = 1350 - 1000 = 350 ≤ 800 → should match
    const players = [
      makePlayer('p1', 1000, 30), // waited 30s
      makePlayer('p2', 1150, 0),
      makePlayer('p3', 1280, 0),
      makePlayer('p4', 1350, 0),
    ];
    const group = findBestMatch(players);
    expect(group).not.toBeNull();
    expect(group).toHaveLength(4);
  });
});
