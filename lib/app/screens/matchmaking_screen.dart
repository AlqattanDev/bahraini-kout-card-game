import 'dart:async';
import 'package:flutter/material.dart';
import '../services/matchmaking_service.dart';
import '../app_routes.dart';
import '../models/game_mode.dart';
import '../models/navigation_args.dart';
import '../../game/theme/kout_theme.dart';
import 'dart:math' as math;
import '../widgets/app_action_button.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  /// Null when route arguments are missing — do not call [dispose] helpers on it until set.
  MatchmakingService? _matchmakingService;
  StreamSubscription? _matchSub;
  Timer? _tickTimer;
  bool _initialized = false;
  int _elapsedSeconds = 0;
  bool _timedOut = false;
  String? _error;
  String _uid = '';
  String _token = '';
  late AnimationController _spinnerController;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = MatchmakingArgs.fromRouteArgs(
      ModalRoute.of(context)!.settings.arguments,
    );
    if (args == null) {
      _error = 'Missing matchmaking arguments';
      return;
    }
    _uid = args.uid;
    _token = args.token;

    _matchmakingService = MatchmakingService(token: _token);
    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    final service = _matchmakingService;
    if (service == null) return;

    setState(() {
      _elapsedSeconds = 0;
      _timedOut = false;
      _error = null;
    });

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });

    try {
      final immediateGameId = await service.joinQueue(1000);
      if (immediateGameId != null) {
        _navigateToGame(immediateGameId);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      _tickTimer?.cancel();
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      return;
    }

    _matchSub?.cancel();
    _matchSub = service.listenForMatch().listen(
      (gameId) => _navigateToGame(gameId),
      onDone: () {
        // Stream closed without match = timeout
        if (!mounted) return;
        _tickTimer?.cancel();
        setState(() => _timedOut = true);
      },
      onError: (e) {
        if (!mounted) return;
        _tickTimer?.cancel();
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      },
    );
  }

  void _navigateToGame(String gameId) {
    _tickTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.game,
      arguments: OnlineGameMode(gameId: gameId, myUid: _uid, token: _token),
    );
  }

  void _retry() {
    if (_matchmakingService == null) {
      Navigator.pop(context);
      return;
    }
    _matchSub?.cancel();
    _startMatchmaking();
  }

  void _cancel() {
    _tickTimer?.cancel();
    _matchSub?.cancel();
    _matchmakingService?.leaveQueue();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _tickTimer?.cancel();
    _matchSub?.cancel();
    _matchmakingService?.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildIcon(IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(icon, size: 48, color: color),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoutTheme.table,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0x00000000), Color(0x88000000)],
            radius: 1.0,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_error != null) ...[
                  _buildIcon(Icons.error_outline, KoutTheme.lossColor),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: KoutTheme.bodyStyle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    width: 200,
                    label: 'Retry',
                    onPressed: _retry,
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(label: 'Back', onPressed: _cancel),
                ] else if (_timedOut) ...[
                  _buildIcon(Icons.hourglass_disabled, KoutTheme.accent),
                  const SizedBox(height: 16),
                  Text(
                    'No match found',
                    style: KoutTheme.bodyStyle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waited ${_formatElapsed()}',
                    style: KoutTheme.bodyStyle.copyWith(
                      color: KoutTheme.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    width: 200,
                    label: 'Try Again',
                    onPressed: _retry,
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(label: 'Back', onPressed: _cancel),
                ] else ...[
                  AnimatedBuilder(
                    animation: _spinnerController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _spinnerController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(64, 64),
                          painter: _StarSpinnerPainter(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Searching for opponents...',
                    style: KoutTheme.bodyStyle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usually takes less than a minute',
                    style: KoutTheme.bodyStyle.copyWith(
                      fontSize: 12,
                      color: KoutTheme.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _formatElapsed(),
                    style: const TextStyle(
                      fontFamily: KoutTheme.monoFontFamily,
                      fontSize: 14,
                      color: KoutTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSecondaryButton(
                    width: 200,
                    label: 'Cancel',
                    onPressed: _cancel,
                    withBorder: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarSpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final path = Path();
    const points = 8;
    const angleStep = math.pi * 2 / points;
    const innerRatio = 0.45;

    final outerRadius = radius;
    final innerRadius = radius * innerRatio;

    for (int i = 0; i < points * 2; i++) {
      final angle = i * angleStep / 2 - math.pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = KoutTheme.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
