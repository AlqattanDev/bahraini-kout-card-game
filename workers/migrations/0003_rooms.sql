CREATE TABLE room_codes (
  code       TEXT PRIMARY KEY,
  do_id      TEXT NOT NULL,
  host_uid   TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  status     TEXT DEFAULT 'open'
);

CREATE INDEX idx_room_codes_status ON room_codes(status);
