/// Shared timing constants used by both the game controller and UI.
abstract final class GameTiming {
  /// How long a human player has to act before auto-play kicks in.
  static const Duration humanTurnTimeout = Duration(seconds: 15);

  /// Deal animation pause.
  static const Duration dealDelay = Duration(milliseconds: 300);

  /// Pause after a card is played so the user can see it.
  static const Duration cardPlayDelay = Duration(milliseconds: 1500);

  /// Pause after a trick resolves before starting the next.
  static const Duration trickResolutionDelay = Duration(seconds: 2);

  /// Pause before scoring overlay transitions.
  static const Duration scoringDelay = Duration(seconds: 2);

  /// Bot thinking range: [botThinkingMinMs, botThinkingMinMs + botThinkingRangeMs).
  static const int botThinkingMinMs = 3000;
  static const int botThinkingRangeMs = 2000;
}
