import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/enums.dart';
import '../../game/theme/kout_theme.dart';

/// Flutter overlay shown during ROUND_SCORING phase.
///
/// Displays "Round Won!" or "Round Lost" based on whether the bidding team
/// achieved their bid, along with the points scored this round.
class RoundResultOverlay extends StatelessWidget {
  final ClientGameState state;
  final VoidCallback onContinue;

  const RoundResultOverlay({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final myTeam = state.myTeam;
    final opponentTeam = myTeam.opponent;
    final myScore = state.scores[myTeam] ?? 0;
    final opponentScore = state.scores[opponentTeam] ?? 0;
    final myTricks = state.tricks[myTeam] ?? 0;

    // Determine if the bidding team is my team
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : -1;
    final bidderTeam = bidderSeat >= 0 ? teamForSeat(bidderSeat) : null;
    final iMyTeamBidder = bidderTeam == myTeam;

    // Evaluate result: bidder needs to win at least their bid in tricks
    final bidValue = state.currentBid?.value ?? 0;
    final bidderTricks = bidderTeam != null ? (state.tricks[bidderTeam] ?? 0) : 0;
    final bidderWon = bidderTricks >= bidValue;

    final bool roundWon = iMyTeamBidder ? bidderWon : !bidderWon;
    final resultText = roundWon ? 'Round Won!' : 'Round Lost';
    final resultColor = roundWon ? const Color(0xFF4CAF50) : const Color(0xFFE57373);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        constraints: const BoxConstraints(minWidth: 260),
        decoration: BoxDecoration(
          color: const Color(0xFF5C1A1B).withOpacity(0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KoutTheme.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              resultText,
              style: TextStyle(
                color: resultColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _scoreRow('My Team', myTricks, myScore, KoutTheme.teamAColor),
            const SizedBox(height: 6),
            _scoreRow(
              'Opponents',
              state.tricks[opponentTeam] ?? 0,
              opponentScore,
              KoutTheme.teamBColor,
            ),
            if (state.currentBid != null) ...[
              const SizedBox(height: 12),
              Text(
                'Bid: ${state.currentBid!.isKout ? "Kout" : state.currentBid!.value}',
                style: const TextStyle(
                  color: KoutTheme.textColor,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: KoutTheme.accent,
                foregroundColor: const Color(0xFF3B1A1B),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, int tricks, int points, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$tricks tricks',
          style: const TextStyle(color: KoutTheme.textColor, fontSize: 13),
        ),
        const SizedBox(width: 16),
        Text(
          '$points pts',
          style: const TextStyle(color: KoutTheme.textColor, fontSize: 13),
        ),
      ],
    );
  }
}
