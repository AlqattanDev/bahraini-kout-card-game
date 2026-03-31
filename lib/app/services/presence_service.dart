/// Presence is now handled by the WebSocket connection itself.
/// When connected → present. When WS closes → GameRoom DO starts
/// a 90s disconnect alarm. No client-side heartbeat needed.
///
/// This class is kept for API compatibility but is essentially a no-op.
class PresenceService {
  void start() {
    // No-op: WebSocket connection IS the presence signal
  }

  void stop() {
    // No-op
  }

  Future<void> disconnect() async {
    // No-op: closing the WebSocket triggers server-side disconnect handling
  }

  void dispose() {
    // No-op
  }
}
