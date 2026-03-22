import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/client_game_state.dart';
import '../services/game_service.dart';
import '../services/presence_service.dart';
import '../../game/kout_game.dart';
import '../../game/overlays/bid_overlay.dart';
import '../../game/overlays/trump_selector.dart';
import '../../game/overlays/round_result_overlay.dart';
import '../../game/overlays/game_over_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameService? _gameService;
  PresenceService? _presenceService;
  KoutGame? _koutGame;
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

    _koutGame = KoutGame(
      stateStream: _gameService!.stateStream,
      onAction: (action, data) => _handleAction(action, data),
    );

    _gameService!.startListening();
    _presenceService!.start();
  }

  void _handleAction(String action, Map<String, dynamic> data) {
    if (_gameService == null) return;
    switch (action) {
      case 'playCard':
        _gameService!.sendPlayCard(data['card'] as String);
        break;
      case 'bid':
        _gameService!.sendBid(data['bidAmount'] as int);
        break;
      case 'pass':
        _gameService!.sendPass();
        break;
      case 'selectTrump':
        _gameService!.sendTrumpSelection(data['suit'] as String);
        break;
    }
  }

  @override
  void dispose() {
    _presenceService?.dispose();
    _gameService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_koutGame == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: GameWidget(
        game: _koutGame!,
        overlayBuilderMap: {
          'bid': (context, game) {
            final koutGame = game as KoutGame;
            return BidOverlay(
              onBid: (amount) {
                koutGame.overlays.remove('bid');
                koutGame.onAction('bid', {'bidAmount': amount});
              },
              onPass: () {
                koutGame.overlays.remove('bid');
                koutGame.onAction('pass', {});
              },
            );
          },
          'trump': (context, game) {
            final koutGame = game as KoutGame;
            return TrumpSelectorOverlay(
              onSelect: (suit) {
                koutGame.overlays.remove('trump');
                koutGame.onAction('selectTrump', {'suit': suit});
              },
            );
          },
          'roundResult': (context, game) {
            final koutGame = game as KoutGame;
            final state = koutGame.currentState;
            if (state == null) return const SizedBox.shrink();
            return RoundResultOverlay(
              state: state,
              onContinue: () {
                koutGame.overlays.remove('roundResult');
              },
            );
          },
          'gameOver': (context, game) {
            final koutGame = game as KoutGame;
            final state = koutGame.currentState;
            if (state == null) return const SizedBox.shrink();
            return GameOverOverlay(
              state: state,
              onReturnToMenu: () {
                koutGame.overlays.remove('gameOver');
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
            );
          },
        },
      ),
    );
  }
}
