export interface QueuedPlayer {
  uid: string;
  eloRating: number;
  queuedAt: string; // ISO 8601
}

export function calculateBracket(queuedAt: string): number {
  const waitTimeMs = Date.now() - new Date(queuedAt).getTime();
  const waitTimeSec = waitTimeMs / 1000;
  const expansions = Math.floor(waitTimeSec / 15);
  return Math.min(200 + expansions * 100, 500);
}

export function findBestMatch(players: QueuedPlayer[]): QueuedPlayer[] | null {
  if (players.length < 4) return null;

  const sorted = [...players].sort((a, b) => a.eloRating - b.eloRating);

  let bestWindow: QueuedPlayer[] | null = null;
  let bestSpread = Infinity;

  for (let i = 0; i <= sorted.length - 4; i++) {
    const window = sorted.slice(i, i + 4);
    const spread = window[3].eloRating - window[0].eloRating;

    const maxBracket = Math.max(
      ...window.map((p) => calculateBracket(p.queuedAt))
    );

    if (spread <= maxBracket * 2 && spread < bestSpread) {
      bestSpread = spread;
      bestWindow = window;
    }
  }

  return bestWindow;
}

export function assignSeats(players: QueuedPlayer[]): string[] {
  const seats = [0, 1, 2, 3];
  for (let i = seats.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [seats[i], seats[j]] = [seats[j], seats[i]];
  }
  const playersInSeatOrder = new Array<string>(4);
  players.forEach((p, idx) => {
    playersInSeatOrder[seats[idx]] = p.uid;
  });
  return playersInSeatOrder;
}
