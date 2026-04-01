import 'dart:async';
import 'package:flutter/material.dart';
import '../services/matchmaking_service.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  late MatchmakingService _matchmakingService;
  StreamSubscription? _matchSub;
  Timer? _tickTimer;
  bool _initialized = false;
  int _elapsedSeconds = 0;
  bool _timedOut = false;
  String? _error;
  late String _uid;
  late String _token;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _uid = args['uid'] as String;
    _token = args['token'] as String;

    _matchmakingService = MatchmakingService(token: _token, myUid: _uid);
    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    setState(() {
      _elapsedSeconds = 0;
      _timedOut = false;
      _error = null;
    });

    // Start elapsed timer
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });

    try {
      final immediateGameId = await _matchmakingService.joinQueue(1000);
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
    _matchSub = _matchmakingService.listenForMatch().listen(
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
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
      },
    );
  }

  void _navigateToGame(String gameId) {
    _tickTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/game',
      arguments: {'gameId': gameId, 'myUid': _uid, 'token': _token},
    );
  }

  void _retry() {
    _matchSub?.cancel();
    _startMatchmaking();
  }

  void _cancel() {
    _tickTimer?.cancel();
    _matchSub?.cancel();
    _matchmakingService.leaveQueue();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _matchSub?.cancel();
    _matchmakingService.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null) ...[
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _retry, child: const Text('Retry')),
              const SizedBox(height: 12),
              TextButton(onPressed: _cancel, child: const Text('Back')),
            ] else if (_timedOut) ...[
              const Icon(Icons.hourglass_disabled, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('No match found', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Waited ${_formatElapsed()}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _retry, child: const Text('Try Again')),
              const SizedBox(height: 12),
              TextButton(onPressed: _cancel, child: const Text('Back')),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text('Searching for opponents... ${_formatElapsed()}',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              TextButton(onPressed: _cancel, child: const Text('Cancel')),
            ],
          ],
        ),
      ),
    );
  }
}
