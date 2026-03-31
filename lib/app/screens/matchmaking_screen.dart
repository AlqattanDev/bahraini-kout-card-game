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
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final uid = args['uid'] as String;
    final token = args['token'] as String;

    _matchmakingService = MatchmakingService(token: token, myUid: uid);
    _startMatchmaking(uid, token);
  }

  Future<void> _startMatchmaking(String uid, String token) async {
    // Try immediate match
    final immediateGameId = await _matchmakingService.joinQueue(1000);
    if (immediateGameId != null) {
      _navigateToGame(immediateGameId, uid, token);
      return;
    }

    // Listen for async match via WebSocket
    _matchSub = _matchmakingService.listenForMatch().listen((gameId) {
      _navigateToGame(gameId, uid, token);
    });
  }

  void _navigateToGame(String gameId, String uid, String token) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/game',
      arguments: {'gameId': gameId, 'myUid': uid, 'token': token},
    );
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _matchmakingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text('Searching for opponents...'),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                _matchmakingService.leaveQueue();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
