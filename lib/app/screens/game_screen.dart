import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../services/game_service.dart';
import '../services/presence_service.dart';
import '../../game/kout_game.dart';
import '../../game/overlays/bid_overlay.dart';
import '../../game/overlays/trump_selector.dart';
import '../../game/overlays/round_result_overlay.dart';
import '../../game/overlays/bid_announcement_overlay.dart';
import '../../game/overlays/connection_status_overlay.dart';
import '../../game/overlays/game_over_overlay.dart';
import '../../offline/local_game_controller.dart';
import '../../offline/human_player_controller.dart';
import '../../offline/bot_player_controller.dart';
import '../../offline/player_controller.dart';
import '../../shared/models/bid.dart';
import '../../shared/models/card.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameService? _gameService;
  PresenceService? _presenceService;
  LocalGameController? _localController;
  KoutGame? _koutGame;
  GameMode? _gameMode;
  StreamSubscription<String>? _errorSub;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is GameMode) {
      _initFromGameMode(args);
    } else if (args is Map<String, dynamic>) {
      // Legacy: online mode from route args map
      _initFromGameMode(OnlineGameMode(
        gameId: args['gameId'] as String? ?? '',
        myUid: args['myUid'] as String? ?? '',
        token: args['token'] as String? ?? '',
      ));
    }
  }

  void _initFromGameMode(GameMode mode) {
    _gameMode = mode;
    switch (mode) {
      case OnlineGameMode(:final gameId, :final myUid, :final token):
        _gameService = GameService(gameId: gameId, myUid: myUid, token: token);
        _presenceService = PresenceService();

        _koutGame = KoutGame(
          stateStream: _gameService!.stateStream,
          inputSink: _gameService!,
          connectionStream: _gameService!.connectionStream,
        );

        _gameService!.startListening();
        _presenceService!.start();

        _errorSub = _gameService!.errorStream.listen((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: const Color(0xFF5C1A1B),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });

      case OfflineGameMode(:final seats):
        final humanController = HumanPlayerController();
        final controllers = <int, PlayerController>{};
        for (final seat in seats) {
          controllers[seat.seatIndex] = seat.isBot
              ? BotPlayerController(seatIndex: seat.seatIndex)
              : humanController;
        }
        _localController = LocalGameController(
          seats: seats,
          controllers: controllers,
        );

        _koutGame = KoutGame(
          stateStream: _localController!.stateStream,
          inputSink: humanController,
        );

        _localController!.start();
    }
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _presenceService?.dispose();
    _gameService?.dispose();
    _localController?.dispose();
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
      body: Stack(
        children: [
          GameWidget(
            game: _koutGame!,
            overlayBuilderMap: {
          'bid': (context, game) {
            final koutGame = game as KoutGame;
            final state = koutGame.currentState;
            return BidOverlay(
              currentHighBid: state?.currentBid,
              isForced: koutGame.isHumanForced,
              onBid: (amount) {
                koutGame.soundManager?.playBidSound();
                koutGame.overlays.remove('bid');
                final bidAmount = BidAmount.fromValue(amount);
                if (bidAmount != null) {
                  koutGame.inputSink.placeBid(bidAmount);
                }
              },
              onPass: () {
                koutGame.soundManager?.playBidSound();
                koutGame.overlays.remove('bid');
                koutGame.inputSink.pass();
              },
            );
          },
          'trump': (context, game) {
            final koutGame = game as KoutGame;
            return TrumpSelectorOverlay(
              onSelect: (suit) {
                koutGame.soundManager?.playTrumpSound();
                koutGame.overlays.remove('trump');
                koutGame.inputSink.selectTrump(
                  Suit.values.firstWhere((e) => e.name == suit),
                );
              },
            );
          },
          'bidAnnouncement': (context, game) {
            final koutGame = game as KoutGame;
            final state = koutGame.currentState;
            if (state == null) return const SizedBox.shrink();
            return BidAnnouncementOverlay(state: state);
          },
          'roundResult': (context, game) {
            final koutGame = game as KoutGame;
            final state = koutGame.currentState;
            if (state == null) return const SizedBox.shrink();
            return RoundResultOverlay(
              state: state,
              previousScoreA: koutGame.previousScoreA,
              previousScoreB: koutGame.previousScoreB,
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
              onPlayAgain: () {
                koutGame.overlays.remove('gameOver');
                if (_gameMode is OfflineGameMode) {
                  Navigator.of(context).pushReplacementNamed(
                    '/game',
                    arguments: _gameMode,
                  );
                }
              },
              onReturnToMenu: () {
                koutGame.overlays.remove('gameOver');
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
              onVictoryAnimationReady: () {
                koutGame.spawnVictoryParticles();
              },
            );
          },
          'connectionStatus': (context, game) {
            final koutGame = game as KoutGame;
            return ConnectionStatusOverlay(
              status: koutGame.connectionStatus,
              reconnectAttempt: koutGame.reconnectAttempt,
              onReturnToMenu: () {
                koutGame.overlays.remove('connectionStatus');
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
            );
          },
        },
          ),
        ],
      ),
    );
  }
}
