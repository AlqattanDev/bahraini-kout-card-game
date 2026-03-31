import { DurableObject } from "cloudflare:workers";
import type { Env } from "../env";

/**
 * Single global lobby DO that players connect to while waiting for a match.
 * When the Worker finds a match, it calls /notify on this DO to inform players.
 */
export class MatchmakingLobby extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair("ping", "pong")
    );
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/ws") {
      if (request.headers.get("Upgrade") !== "websocket") {
        return new Response("Expected WebSocket", { status: 426 });
      }

      const uid = url.searchParams.get("uid");
      if (!uid) return new Response("Missing uid", { status: 400 });

      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      this.ctx.acceptWebSocket(server, [uid]);

      return new Response(null, { status: 101, webSocket: client });
    }

    if (url.pathname === "/notify") {
      const body = await request.json<{ gameId: string; players: string[] }>();
      const { gameId, players } = body;

      for (const ws of this.ctx.getWebSockets()) {
        const tags = this.ctx.getTags(ws);
        const uid = tags[0];
        if (uid && players.includes(uid)) {
          try {
            ws.send(JSON.stringify({ event: "matched", data: { gameId } }));
            ws.close(1000, "matched");
          } catch {
            // already closed
          }
        }
      }

      return Response.json({ notified: players.length });
    }

    if (url.pathname === "/remove") {
      const body = await request.json<{ uid: string }>();
      for (const ws of this.ctx.getWebSockets()) {
        const tags = this.ctx.getTags(ws);
        if (tags[0] === body.uid) {
          try {
            ws.close(1000, "left queue");
          } catch {
            // closed
          }
        }
      }
      return Response.json({ removed: true });
    }

    return new Response("Not found", { status: 404 });
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string): Promise<void> {
    ws.close(code, reason);
  }
}
