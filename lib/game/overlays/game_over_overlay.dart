import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/constants.dart';
import '../../shared/models/game_state.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_panel.dart';
import 'overlay_styles.dart';
import 'overlay_utils.dart';

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
  final _action = OneShotHapticAction();

  // Glow pulse animation (gold for victory, red for defeat)
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();

    final myTeam = widget.state.myTeam;
    final myScore = widget.state.scores[myTeam] ?? 0;
    _myTeamWon = myScore >= targetScore;

    if (_myTeamWon) {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );

      // Trigger victory particles after 200ms
      delayIfMounted(
        this,
        OverlayStyles.animNormal,
        () => widget.onVictoryAnimationReady?.call(),
      );
    } else {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );
      _glowAnimation = Tween<double>(begin: 2.0, end: 10.0).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );
    }

    // Start glow pulse after entry animation completes (~250ms)
    delayIfMounted(
      this,
      const Duration(milliseconds: 250),
      () => _glowController!.repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myTeam = widget.state.myTeam;
    final finalScore = widget.state.tugScore;
    final winner = widget.state.leadingTeam;

    final headlineText = _myTeamWon ? 'Victory!' : 'Defeat';
    final headlineColor = OverlayStyles.resultColor(_myTeamWon);

    return OverlayPanel(
      title: 'Game Over',
      titleStyle: const TextStyle(
        color: KoutTheme.textColor,
        fontSize: 14,
        letterSpacing: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      decoration: OverlayStyles.panelDecoration(
        alpha: 0.98,
        borderWidth: 2.5,
        borderRadius: 20.0,
        blurRadius: 32.0,
      ),
      constraints: const BoxConstraints(minWidth: 280),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeadline(headlineText, headlineColor),
          const SizedBox(height: 24),
          // Final score
          Container(
            padding: OverlayStyles.infoBoxPadding,
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
                  winner == myTeam ? 'Your Team wins!' : 'Opponent wins',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KoutTheme.textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  finalScore >= targetScore &&
                          widget.state.currentBid?.isKout == true
                      ? 'Won by Kout'
                      : 'Won by $finalScore points',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KoutTheme.textColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _runOnce(widget.onPlayAgain),
            style: OverlayStyles.primaryButton(
              borderRadius: 10.0,
              padding: OverlayStyles.buttonPadding,
            ),
            child: const Text(
              'Play Again',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _runOnce(widget.onReturnToMenu),
            style: OverlayStyles.secondaryButton(),
            child: const Text(
              'Back to Lobby',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _runOnce(VoidCallback action) {
    _action.run(action);
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

    if (_glowAnimation == null) {
      return textWidget;
    }

    final glowColor = _myTeamWon
        ? KoutTheme.accent.withValues(alpha: 0.6)
        : KoutTheme.lossColor.withValues(alpha: 0.4);

    return AnimatedBuilder(
      animation: _glowAnimation!,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: glowColor,
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
