import 'package:flutter/material.dart';
import '../models/client_game_state.dart';
import '../services/game_service.dart';
import '../services/presence_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameService? _gameService;
  PresenceService? _presenceService;
  ClientGameState? _gameState;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final gameId = args?['gameId'] as String? ?? '';
    final myUid = args?['myUid'] as String? ?? '';

    _gameService = GameService(gameId: gameId, myUid: myUid);
    _presenceService = PresenceService(gameId: gameId, myUid: myUid);

    _gameService!.stateStream.listen((state) {
      if (mounted) setState(() => _gameState = state);
    });

    _gameService!.startListening();
    _presenceService!.start();
  }

  @override
  void dispose() {
    _presenceService?.dispose();
    _gameService?.dispose();
    super.dispose();
  }

  String _phaseLabel(ClientGameState state) {
    switch (state.phase.name) {
      case 'bidding':
        return 'Bidding phase';
      case 'trumpSelection':
        return 'Trump selection phase';
      case 'playing':
        return 'Playing phase';
      case 'scoring':
        return 'Scoring phase';
      default:
        return state.phase.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game')),
      body: Center(
        child: _gameState == null
            ? const CircularProgressIndicator()
            : Text(_phaseLabel(_gameState!)),
      ),
    );
  }
}
