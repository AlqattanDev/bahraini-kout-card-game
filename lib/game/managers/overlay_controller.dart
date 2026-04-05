import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import 'sound_manager.dart';

/// Callback interface for overlay operations — decouples from FlameGame.overlays.
typedef OverlayDelegate = ({
  bool Function(String key) isActive,
  void Function(String key) add,
  void Function(String key) remove,
});

/// Manages game overlay visibility state machine. Decides which overlays to
/// show/hide based on [GamePhase] transitions. Extracted from KoutGame.
class OverlayController {
  static const List<String> _allOverlays = [
    'bid',
    'trump',
    'bidAnnouncement',
    'roundResult',
    'gameOver',
  ];

  GamePhase? _prevPhase;

  /// Snapshot of scores before round scoring, for the round result overlay.
  int previousScoreA = 0;
  int previousScoreB = 0;
  int _lastScoreA = 0;
  int _lastScoreB = 0;

  /// Call each frame to track scores for pre-round snapshots.
  void trackScores(ClientGameState state) {
    if (state.phase != GamePhase.roundScoring) {
      _lastScoreA = state.scores[Team.a] ?? 0;
      _lastScoreB = state.scores[Team.b] ?? 0;
    }
  }

  /// Determines which overlay should be active and mutates the overlay set
  /// via [delegate]. Plays phase-transition sounds via [soundManager].
  void update(
    ClientGameState state, {
    required OverlayDelegate delegate,
    SoundManager? soundManager,
  }) {
    // Detect poison joker sound
    if (state.phase == GamePhase.roundScoring &&
        _prevPhase == GamePhase.playing &&
        state.myHand.length == 1 &&
        state.myHand.first.isJoker) {
      soundManager?.playPoisonJokerSound();
    }
    _prevPhase = state.phase;

    // Determine which single overlay (if any) should be shown
    String? targetOverlay;

    switch (state.phase) {
      case GamePhase.bidding:
        if (state.isMyTurn) targetOverlay = 'bid';
        break;
      case GamePhase.trumpSelection:
        if (state.bidderUid == state.myUid) targetOverlay = 'trump';
        break;
      case GamePhase.bidAnnouncement:
        targetOverlay = 'bidAnnouncement';
        break;
      case GamePhase.roundScoring:
        targetOverlay = 'roundResult';
        break;
      case GamePhase.gameOver:
        if (!delegate.isActive('gameOver')) {
          final myScore = state.scores[state.myTeam] ?? 0;
          final oppScore = state.scores[state.myTeam.opponent] ?? 0;
          if (myScore > oppScore) {
            soundManager?.playVictorySound();
          } else {
            soundManager?.playDefeatSound();
          }
        }
        targetOverlay = 'gameOver';
        break;
      default:
        break;
    }

    // Remove overlays that should not be shown
    for (final key in _allOverlays) {
      if (key != targetOverlay && delegate.isActive(key)) {
        delegate.remove(key);
      }
    }

    // Show the target overlay if not already visible
    if (targetOverlay != null && !delegate.isActive(targetOverlay)) {
      if (targetOverlay == 'roundResult') {
        previousScoreA = _lastScoreA;
        previousScoreB = _lastScoreB;

        final bt = state.bidderTeam;
        final bidValue = state.currentBid?.value ?? 0;
        final bidderTricks = bt != null ? (state.tricks[bt] ?? 0) : 0;
        final bidderWon = bidderTricks >= bidValue;
        final myTeamWon = (bt == state.myTeam) ? bidderWon : !bidderWon;

        if (myTeamWon) {
          soundManager?.playRoundWinSound();
        } else {
          soundManager?.playRoundLossSound();
        }
      }
      delegate.add(targetOverlay);
    }
  }
}
