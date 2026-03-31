import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

/// Flutter overlay shown during GAME_OVER phase.
///
/// Shows "Victory!" or "Defeat" with celebration effects, final scores for
/// both teams, and "Play Again" / "Back to Lobby" buttons.
class GameOverOverlay extends StatefulWidget {
  final ClientGameState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onReturnToMenu;

  /// Optional callback fired after entry animation completes for victory.
  /// Used by the game screen to trigger particle effects.
  final VoidCallback? onVictoryAnimationReady;

  const GameOverOverlay({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onReturnToMenu,
    this.onVictoryAnimationReady,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with TickerProviderStateMixin {
  late final bool _myTeamWon;

  // Gold glow pulse animation (victory only)
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();

    final myTeam = widget.state.myTeam;
    final myScore = widget.state.scores[myTeam] ?? 0;
    _myTeamWon = myScore >= 31;

    if (_myTeamWon) {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );

      // Start glow pulse after entry animation completes (~250ms)
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _glowController!.repeat(reverse: true);
        }
      });

      // Trigger victory particles after 200ms
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onVictoryAnimationReady?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myTeam = widget.state.myTeam;
    final scoreA = widget.state.scores[Team.a] ?? 0;
    final scoreB = widget.state.scores[Team.b] ?? 0;
    final finalScore = scoreA > 0 ? scoreA : scoreB;
    final Team? winner = scoreA >= 31
        ? Team.a
        : scoreB >= 31
            ? Team.b
            : null;

    final headlineText = _myTeamWon ? 'Victory!' : 'Defeat';
    final headlineColor = OverlayStyles.resultColor(_myTeamWon);

    return OverlayAnimationWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        constraints: const BoxConstraints(minWidth: 280),
        decoration: OverlayStyles.panelDecoration(
          alpha: 0.98,
          borderWidth: 2.5,
          borderRadius: 20.0,
          blurRadius: 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Headline with optional glow
            _buildHeadline(headlineText, headlineColor),
            const SizedBox(height: 8),
            const Text(
              'Game Over',
              style: TextStyle(
                color: KoutTheme.textColor,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            // Final score
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: OverlayStyles.infoBoxDecoration(),
              child: Column(
                children: [
                  Text(
                    '$finalScore',
                    style: TextStyle(
                      color: winner == Team.a
                          ? KoutTheme.teamAColor
                          : KoutTheme.teamBColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    winner == myTeam
                        ? 'Your Team wins!'
                        : 'Opponent wins',
                    style: const TextStyle(
                      color: KoutTheme.textColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Play Again button (filled gold)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onPlayAgain,
                style: OverlayStyles.primaryButton(
                  borderRadius: 10.0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 14),
                ),
                child: const Text(
                  'Play Again',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Back to Lobby button (outlined gold)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onReturnToMenu,
                style: OverlayStyles.secondaryButton(),
                child: const Text(
                  'Back to Lobby',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadline(String text, Color color) {
    final textWidget = Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );

    if (!_myTeamWon || _glowAnimation == null) {
      return textWidget;
    }

    return AnimatedBuilder(
      animation: _glowAnimation!,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: KoutTheme.accent.withValues(alpha: 0.6),
                blurRadius: _glowAnimation!.value,
                spreadRadius: _glowAnimation!.value * 0.3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: textWidget,
    );
  }

}
