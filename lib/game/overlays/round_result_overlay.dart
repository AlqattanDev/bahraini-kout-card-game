import 'package:flutter/material.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../../game/theme/kout_theme.dart';
import 'overlay_animation_wrapper.dart';
import 'overlay_styles.dart';

/// Flutter overlay shown during ROUND_SCORING phase.
///
/// Displays headline, trick breakdown, animated score change, progress bars
/// to 31, and a continue button.
class RoundResultOverlay extends StatefulWidget {
  final ClientGameState state;
  final int previousScoreA;
  final int previousScoreB;
  final VoidCallback onContinue;

  const RoundResultOverlay({
    super.key,
    required this.state,
    required this.previousScoreA,
    required this.previousScoreB,
    required this.onContinue,
  });

  @override
  State<RoundResultOverlay> createState() => _RoundResultOverlayState();
}

class _RoundResultOverlayState extends State<RoundResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    // Start the animation after a brief delay so the overlay entry finishes
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final myTeam = state.myTeam;
    final opponentTeam = myTeam.opponent;
    final myTricks = state.tricks[myTeam] ?? 0;
    final opponentTricks = state.tricks[opponentTeam] ?? 0;

    // Determine if the bidding team is my team
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : -1;
    final bidderTeam = bidderSeat >= 0 ? teamForSeat(bidderSeat) : null;
    final isMyTeamBidder = bidderTeam == myTeam;

    // Evaluate result: bidder needs to win at least their bid in tricks
    final bidValue = state.currentBid?.value ?? 0;
    final bidderTricks =
        bidderTeam != null ? (state.tricks[bidderTeam] ?? 0) : 0;
    final bidderWon = bidderTricks >= bidValue;

    final bool roundWon = isMyTeamBidder ? bidderWon : !bidderWon;
    final resultText = roundWon ? 'Round Won!' : 'Round Lost';
    final resultColor = OverlayStyles.resultColor(roundWon);

    // Bid status text
    final bidLabel = state.currentBid?.isKout == true
        ? 'Kout'
        : '${state.currentBid?.value ?? 0}';
    final bidStatusText = bidderWon ? 'Made' : 'Missed';
    final bidderLabel = isMyTeamBidder ? 'Your Team' : 'Opponent';

    // Tug-of-war: compute previous and current single score
    final prevScoreA = widget.previousScoreA;
    final prevScoreB = widget.previousScoreB;
    final prevTug = prevScoreA > 0 ? prevScoreA : prevScoreB;

    final curScoreA = state.scores[Team.a] ?? 0;
    final curScoreB = state.scores[Team.b] ?? 0;
    final curTug = curScoreA > 0 ? curScoreA : curScoreB;
    final Team? curLeader = curScoreA > 0
        ? Team.a
        : curScoreB > 0
            ? Team.b
            : null;

    return OverlayAnimationWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
        decoration: OverlayStyles.panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Headline
            Text(
              resultText,
              style: TextStyle(
                color: resultColor,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // 2. Trick breakdown box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: OverlayStyles.infoBoxDecoration(),
              child: Column(
                children: [
                  _trickRow(
                    'Your Team',
                    '$myTricks tricks',
                    KoutTheme.teamAColor,
                  ),
                  const SizedBox(height: 6),
                  _trickRow(
                    'Opponent',
                    '$opponentTricks tricks',
                    KoutTheme.teamBColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bid: $bidLabel ($bidderLabel) - $bidStatusText',
                    style: const TextStyle(
                      color: KoutTheme.textColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Tug-of-war score change
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, _) {
                final t = _progressAnimation.value;
                final displayScore =
                    (prevTug + (curTug - prevTug) * t).round();
                final scoreColor = curLeader == Team.a
                    ? KoutTheme.teamAColor
                    : curLeader == Team.b
                        ? KoutTheme.teamBColor
                        : KoutTheme.textColor;
                final leaderLabel = curLeader == null
                    ? 'Tied'
                    : curLeader == myTeam
                        ? 'Your Team leads'
                        : 'Opponent leads';
                return Column(
                  children: [
                    Text(
                      '$displayScore',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      leaderLabel,
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // 4. Single tug-of-war progress bar
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, _) {
                final t = _progressAnimation.value;
                final scoreColor = curLeader == Team.a
                    ? KoutTheme.teamAColor
                    : curLeader == Team.b
                        ? KoutTheme.teamBColor
                        : KoutTheme.textColor;
                return _progressBar(
                  label: 'Score',
                  fromScore: prevTug,
                  toScore: curTug,
                  t: t,
                  color: scoreColor,
                );
              },
            ),
            const SizedBox(height: 22),

            // 5. Continue button
            ElevatedButton(
              onPressed: widget.onContinue,
              style: OverlayStyles.primaryButton(),
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

  Widget _trickRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: KoutTheme.textColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _progressBar({
    required String label,
    required int fromScore,
    required int toScore,
    required double t,
    required Color color,
  }) {
    const maxScore = 31;
    final fromRatio = (fromScore / maxScore).clamp(0.0, 1.0);
    final toRatio = (toScore / maxScore).clamp(0.0, 1.0);
    final currentRatio = fromRatio + (toRatio - fromRatio) * t;
    final displayScore = (fromScore + (toScore - fromScore) * t).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$displayScore / $maxScore',
              style: const TextStyle(
                color: KoutTheme.textColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: CustomPaint(
              painter: _ProgressBarPainter(
                ratio: currentRatio,
                fillColor: color,
                backgroundColor: KoutTheme.progressBarBg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double ratio;
  final Color fillColor;
  final Color backgroundColor;

  _ProgressBarPainter({
    required this.ratio,
    required this.fillColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final fillPaint = Paint()..color = fillColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * ratio, size.height),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter old) =>
      old.ratio != ratio ||
      old.fillColor != fillColor ||
      old.backgroundColor != backgroundColor;
}
