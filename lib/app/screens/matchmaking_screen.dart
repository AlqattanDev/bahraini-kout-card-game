import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/matchmaking_service.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  late final MatchmakingService _matchmakingService;
  StreamSubscription<String>? _matchSub;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUser?.uid ?? '';
    _matchmakingService = MatchmakingService(myUid: uid);
    _joinAndListen(uid);
  }

  Future<void> _joinAndListen(String uid) async {
    await _matchmakingService.joinQueue(1000);
    _matchSub = _matchmakingService.listenForMatch().listen((gameId) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/game',
          arguments: {'gameId': gameId, 'myUid': uid},
        );
      }
    });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _matchmakingService.leaveQueue();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matchmaking')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Searching for opponents...'),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
