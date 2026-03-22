import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../../game/theme/kout_theme.dart';

/// Flutter overlay shown during GAME_OVER phase.
///
/// Shows "Victory!" or "Defeat", final scores for both teams, and a
/// "Return to Menu" button.
class GameOverOverlay extends StatelessWidget {
  final ClientGameState state;
  final VoidCallback onReturnToMenu;

  const GameOverOverlay({
    super.key,
    required this.state,
    required this.onReturnToMenu,
  });

  @override
  Widget build(BuildContext context) {
    final myTeam = state.myTeam;
    final opponentTeam = myTeam.opponent;
    final myScore = state.scores[myTeam] ?? 0;
    final opponentScore = state.scores[opponentTeam] ?? 0;

    // Winner is the team with higher score; 31 is the winning threshold in Kout
    final myTeamWon = myScore > opponentScore;
    final headlineText = myTeamWon ? 'Victory!' : 'Defeat';
    final headlineColor =
        myTeamWon ? const Color(0xFFC9A84C) : const Color(0xFFE57373);

    final myTeamLabel = myTeam == Team.a ? 'Team A (You)' : 'Team B (You)';
    final opponentLabel = opponentTeam == Team.a ? 'Team A' : 'Team B';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        constraints: const BoxConstraints(minWidth: 280),
        decoration: BoxDecoration(
          color: const Color(0xFF5C1A1B).withOpacity(0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KoutTheme.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.7),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headlineText,
              style: TextStyle(
                color: headlineColor,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _finalScoreRow(myTeamLabel, myScore, KoutTheme.teamAColor),
                  const SizedBox(height: 10),
                  _finalScoreRow(opponentLabel, opponentScore, KoutTheme.teamBColor),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onReturnToMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: KoutTheme.accent,
                foregroundColor: const Color(0xFF3B1A1B),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Return to Menu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finalScoreRow(String label, int score, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 32),
        Text(
          '$score pts',
          style: const TextStyle(
            color: KoutTheme.textColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
