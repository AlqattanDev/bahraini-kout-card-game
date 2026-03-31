export interface Env {
  GAME_ROOM: DurableObjectNamespace;
  MATCHMAKING_LOBBY: DurableObjectNamespace;
  DB: D1Database;
  JWT_SECRET: string;
  ENVIRONMENT: string;
}
