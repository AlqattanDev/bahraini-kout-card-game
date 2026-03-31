-- Users: anonymous identities with ELO
CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,
  elo_rating INTEGER NOT NULL DEFAULT 1000,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Matchmaking queue
CREATE TABLE IF NOT EXISTS matchmaking_queue (
  uid TEXT PRIMARY KEY REFERENCES users(uid),
  elo_rating INTEGER NOT NULL,
  queued_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Game history (for ELO updates after games end)
CREATE TABLE IF NOT EXISTS game_history (
  game_id TEXT PRIMARY KEY,
  players TEXT NOT NULL,          -- JSON array of UIDs in seat order
  winner_team TEXT,               -- 'teamA' | 'teamB' | null (in progress)
  final_scores TEXT NOT NULL,     -- JSON: {"teamA": N, "teamB": N}
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_queue_elo ON matchmaking_queue(elo_rating);
CREATE INDEX IF NOT EXISTS idx_queue_time ON matchmaking_queue(queued_at);
