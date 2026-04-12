# Three Targeted Fixes

## Objective

Fix three concrete bugs identified in the post-parity sweep:
1. `disconnect.ts` raw score addition — scores diverge from tug-of-war model used everywhere else
2. Room-mode games missing `recordGame` insert — `completeGame` silently fails (UPDATE on non-existent row, ELO lost)
3. Partner void exploit lead in `play-strategy.ts` — step 5 is a no-op comment stub

## Implementation Plan

- [x] Fix 1. **`workers/src/presence/disconnect.ts:40-44`** — Replace raw `newScores[winningTeam] += penaltyPoints` with the same tug-of-war arithmetic used by `applyScore` in game-room. Specifically: `loserScore = Math.max(0, scores[penaltyAgainstTeam] - penaltyPoints)` and `winnerScore = Math.min(TARGET_SCORE, scores[winningTeam] + penaltyPoints)`. Import `TARGET_SCORE` from `../game/types` (it is already exported at `types.ts:64`). Set both sides: `newScores[penaltyAgainstTeam] = loserScore` and `newScores[winningTeam] = winnerScore`. Remove the single-sided addition line.

- [x] Fix 2. **`workers/src/index.ts` — `/api/rooms/start` handler (`index.ts:192-213`)**  — After the DO `/start` fetch succeeds and before returning `{ ok: true }`, call `await recordGame(c.env.DB, gameId, playersInSeatOrder)`. The player seat order for room games must first be fetched from the DO. Add a `/players` fetch to the room DO after `/start` succeeds, or — simpler — extend the `/start` response from the DO to return the seated player UIDs in order (seats 0–3). The `game-room.ts` `/start` handler already has `this.game.players` at that point; add it to the JSON response. Then in `index.ts`, read `players` from the response and call `recordGame(c.env.DB, gameId, players)`.

- [x] Fix 3. **`workers/src/game/bot/play-strategy.ts:90-96`** — Replace the no-op stub in step 5 of `selectLead` with the real implementation matching Dart's `play_strategy.dart:163-177`. The logic: iterate `tracker.knownVoids.get(ctx.partnerSeat)` (a `Set<SuitName>`). For each void suit that is not the trump suit, collect legal cards of that suit. If any exist, sort ascending by rank and return the lowest. The `tracker` argument is already available in `selectLead`'s signature. `ctx.partnerSeat` is already available in `BotContext`. The `knownVoids` getter on `CardTracker` already exists at `card-tracker.ts:24`.

## Verification Criteria

- `disconnect.ts`: `evaluateDisconnect` with `scores: { teamA: 10, teamB: 5 }`, `playerTeam: 'teamB'`, `bidAmount: 6` → `newScores` must be `{ teamA: min(31, 10+12)=22, teamB: max(0, 5-12)=0 }`, not `{ teamA: 22, teamB: 5 }` as before.
- Room game completion: after a room game ends, `game_history` row must exist and `users.elo_rating` must be updated for all four players.
- Partner void exploit: when `tracker.knownVoids.get(partnerSeat)` contains `'hearts'` and legal hand has hearts, bot leads the lowest heart instead of falling through to `leadFromLongestSuit`.
- TypeScript build: `node_modules/.bin/tsc --noEmit` passes with zero errors.
- All worker tests pass: `npm test` in `workers/`.

## Potential Risks and Mitigations

1. **Room `/start` response change breaks existing clients** — The Flutter `RoomLobbyScreen` calls `/api/rooms/start` and currently only reads `ok: true`. Adding `players` to the response is additive and the client ignores unknown fields, so no breakage. Mitigation: keep `ok: true` alongside the new `players` field.

2. **`recordGame` called after game already has state** — For room games, `recordGame` is called at start (after dealing), so `completeGame`'s UPDATE will find the row. No race with `recordGameCompletion` since that fires only on GAME_OVER which happens rounds later. Mitigation: none needed beyond the insert.

3. **Partner void exploit leads into a suit the bot doesn't control** — The Dart implementation leads the *lowest* card of the void suit, which is intentionally a throwaway; the partner ruffs with trump. This is correct. Mitigation: confirm the sort is ascending (lowest first).

## Alternative Approaches

1. **Fix 2 — fetch players from DO separately**: Add a `GET /players` endpoint on the DO instead of enriching the `/start` response. Simpler DO surface change but requires an extra HTTP round-trip. Enriching the `/start` response is preferred as it's one atomic operation.
2. **Fix 1 — call `applyScore` directly from `disconnect.ts`**: Import and reuse `applyScore` from `game-room.ts`. This avoids duplicating the arithmetic. However, `applyScore` is a private method on the `GameRoom` class, not an exported function. The arithmetic inline is simpler unless `applyScore` is extracted to a shared utility first.
