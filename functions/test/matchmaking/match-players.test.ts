import { findBestGroup, assignSeats, computeMatch, QueuedPlayer, buildGameDocument } from '../../src/matchmaking/match-players';

function makePlayer(uid: string, elo: number, secsAgo = 0): QueuedPlayer {
  return {
    uid,
    eloRating: elo,
    queuedAt: new Date(Date.now() - secsAgo * 1000),
  };
}

// ─── findBestGroup ────────────────────────────────────────────────────────────

describe('findBestGroup', () => {
  it('returns null when fewer than 4 players', () => {
    expect(findBestGroup([makePlayer('a', 1000), makePlayer('b', 1100)])).toBeNull();
  });

  it('returns null for exactly 3 players', () => {
    const players = [makePlayer('a', 1000), makePlayer('b', 1100), makePlayer('c', 1200)];
    expect(findBestGroup(players)).toBeNull();
  });

  it('returns all 4 players when exactly 4 are queued', () => {
    const players = [
      makePlayer('a', 1000),
      makePlayer('b', 1050),
      makePlayer('c', 1100),
      makePlayer('d', 1150),
    ];
    const group = findBestGroup(players)!;
    expect(group).toHaveLength(4);
    const uids = group.map((p) => p.uid).sort();
    expect(uids).toEqual(['a', 'b', 'c', 'd']);
  });

  it('picks the 4 closest-ELO players from a larger pool', () => {
    // 6 players: outlier at 500, 4 clustered around 1200, outlier at 2000
    const players = [
      makePlayer('outlier-low', 500),
      makePlayer('a', 1190),
      makePlayer('b', 1200),
      makePlayer('c', 1210),
      makePlayer('d', 1220),
      makePlayer('outlier-high', 2000),
    ];
    const group = findBestGroup(players)!;
    expect(group).toHaveLength(4);
    const uids = group.map((p) => p.uid);
    expect(uids).toContain('a');
    expect(uids).toContain('b');
    expect(uids).toContain('c');
    expect(uids).toContain('d');
    expect(uids).not.toContain('outlier-low');
    expect(uids).not.toContain('outlier-high');
  });
});

// ─── assignSeats ─────────────────────────────────────────────────────────────

describe('assignSeats', () => {
  it('assigns each player a seat 0-3', () => {
    const players = [
      makePlayer('a', 1000),
      makePlayer('b', 1100),
      makePlayer('c', 1200),
      makePlayer('d', 1300),
    ];
    const seats = assignSeats(players);
    const values = Object.values(seats).sort();
    expect(values).toEqual([0, 1, 2, 3]);
  });

  it('assigns a seat to every player', () => {
    const players = [
      makePlayer('p1', 1000),
      makePlayer('p2', 1100),
      makePlayer('p3', 1200),
      makePlayer('p4', 1300),
    ];
    const seats = assignSeats(players);
    expect(Object.keys(seats)).toHaveLength(4);
    for (const p of players) {
      expect(seats[p.uid]).toBeDefined();
      expect(seats[p.uid]).toBeGreaterThanOrEqual(0);
      expect(seats[p.uid]).toBeLessThanOrEqual(3);
    }
  });
});

// ─── computeMatch ─────────────────────────────────────────────────────────────

describe('computeMatch', () => {
  it('returns null when fewer than 4 players are queued', () => {
    const players = [makePlayer('a', 1000), makePlayer('b', 1100), makePlayer('c', 1200)];
    expect(computeMatch(players)).toBeNull();
  });

  it('returns match data when 4 players are queued', () => {
    const players = [
      makePlayer('p1', 1000, 30),
      makePlayer('p2', 1050, 20),
      makePlayer('p3', 1100, 10),
      makePlayer('p4', 1150, 5),
    ];
    const result = computeMatch(players)!;
    expect(result).not.toBeNull();
    expect(result.group).toHaveLength(4);
    expect(result.playersInSeatOrder).toHaveLength(4);
    expect(result.hands).toHaveLength(4);
    // Every hand should have cards
    for (const hand of result.hands) {
      expect(hand.length).toBeGreaterThan(0);
    }
  });

  it('produces 4 distinct seats [0,1,2,3]', () => {
    const players = [
      makePlayer('p1', 1000),
      makePlayer('p2', 1050),
      makePlayer('p3', 1100),
      makePlayer('p4', 1150),
    ];
    const result = computeMatch(players)!;
    const seats = Object.values(result.seatAssignment).sort();
    expect(seats).toEqual([0, 1, 2, 3]);
  });

  it('seat-ordered player list contains all 4 matched player uids', () => {
    const players = [
      makePlayer('alice', 1200),
      makePlayer('bob', 1210),
      makePlayer('carol', 1190),
      makePlayer('dave', 1205),
    ];
    const result = computeMatch(players)!;
    const uids = result.playersInSeatOrder.sort();
    expect(uids).toEqual(['alice', 'bob', 'carol', 'dave'].sort());
  });

  it('deals all cards — total across 4 hands equals deck size', () => {
    const players = [
      makePlayer('a', 1000),
      makePlayer('b', 1050),
      makePlayer('c', 1100),
      makePlayer('d', 1150),
    ];
    const result = computeMatch(players)!;
    const totalCards = result.hands.reduce((sum, hand) => sum + hand.length, 0);
    // Kout deck: 3*8 + 7 + 1 joker = 32
    expect(totalCards).toBe(32);
  });
});

// ─── buildGameDocument ────────────────────────────────────────────────────────

describe('buildGameDocument', () => {
  it('creates a WAITING-phase game document', () => {
    const players = ['alice', 'bob', 'carol', 'dave'];
    const doc = buildGameDocument(players);
    expect(doc.phase).toBe('WAITING');
  });

  it('sets dealer to seat 0 and currentPlayer/firstBidder to seat 1', () => {
    const players = ['p0', 'p1', 'p2', 'p3'];
    const doc = buildGameDocument(players);
    expect(doc.dealer).toBe('p0');
    expect(doc.currentPlayer).toBe('p1');
    expect(doc.biddingState?.currentBidder).toBe('p1');
  });

  it('initialises scores and tricks to zero', () => {
    const doc = buildGameDocument(['a', 'b', 'c', 'd']);
    expect(doc.scores).toEqual({ teamA: 0, teamB: 0 });
    expect(doc.tricks).toEqual({ teamA: 0, teamB: 0 });
  });

  it('stores all 4 players in order', () => {
    const players = ['p0', 'p1', 'p2', 'p3'];
    const doc = buildGameDocument(players);
    expect(doc.players).toEqual(players);
  });
});
