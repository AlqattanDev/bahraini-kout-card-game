import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../../shared/constants/timing.dart';
import '../components/player_seat.dart';
import '../components/unified_hud.dart';

/// Owns turn timer state: elapsed time, active player tracking, seat
/// timer ring updates, and HUD game timer. Extracted from KoutGame.
class TurnTimerManager {
  String? _lastCurrentPlayer;
  GamePhase? _lastTimerPhase;
  String? _lastTurnSignature;
  double _turnElapsed = 0.0;

  Stopwatch? _gameTimer;
  double _hudTickAccum = 0.0;

  /// Ensures the game timer is started. Returns the stopwatch.
  Stopwatch ensureGameTimer() => _gameTimer ??= (Stopwatch()..start());

  static final double _humanTimeout =
      GameTiming.humanTurnTimeout.inMilliseconds / 1000.0;
  static const double _botTimeout = 4.0; // average of 3-5s

  /// Called every frame from KoutGame.update(). Updates the timer ring on each
  /// seat component and the HUD game clock.
  void tick(
    double dt,
    ClientGameState? state,
    List<PlayerSeatComponent> seats, {
    UnifiedHudComponent? hud,
  }) {
    // Tick game timer on HUD every second
    if (_gameTimer != null && hud != null) {
      _hudTickAccum += dt;
      if (_hudTickAccum >= 1.0) {
        _hudTickAccum = 0.0;
        hud.updateTimer(_gameTimer!.elapsed);
      }
    }

    if (state == null) return;

    final isActionPhase =
        state.phase == GamePhase.bidding ||
        state.phase == GamePhase.trumpSelection ||
        state.phase == GamePhase.playing;

    if (isActionPhase && state.currentPlayerUid != null) {
      final turnSignature = _buildTurnSignature(state);
      // Reset timer when active player or phase changes
      if (state.currentPlayerUid != _lastCurrentPlayer ||
          state.phase != _lastTimerPhase ||
          turnSignature != _lastTurnSignature) {
        _lastCurrentPlayer = state.currentPlayerUid;
        _lastTimerPhase = state.phase;
        _lastTurnSignature = turnSignature;
        _turnElapsed = 0.0;
      }
      _turnElapsed += dt;

      // Update the active seat's timer ring
      final isHuman = state.currentPlayerUid == state.myUid;
      final timeout = isHuman ? _humanTimeout : _botTimeout;
      final progress = (1.0 - (_turnElapsed / timeout)).clamp(0.0, 1.0);

      for (int i = 0; i < seats.length; i++) {
        final uid = state.playerUids[i];
        seats[i].timerProgress = uid == state.currentPlayerUid ? progress : 0.0;
      }
    } else {
      _lastCurrentPlayer = null;
      _lastTimerPhase = null;
      _lastTurnSignature = null;
      for (final seat in seats) {
        seat.timerProgress = 0.0;
      }
    }
  }

  String _buildTurnSignature(ClientGameState state) {
    return [
      state.phase.name,
      state.currentPlayerUid ?? '',
      state.currentTrickPlays.length.toString(),
      state.trickWinners.length.toString(),
      state.bidHistory.length.toString(),
      state.passedPlayers.length.toString(),
      state.currentBid?.value.toString() ?? '-',
    ].join('|');
  }
}
