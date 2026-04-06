import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../game/theme/kout_theme.dart';
import '../models/game_mode.dart';
import '../models/lobby_state.dart';
import '../services/game_service.dart';
import '../services/room_service.dart';

class RoomLobbyScreen extends StatefulWidget {
  const RoomLobbyScreen({super.key});

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  GameService? _gameService;
  RoomService? _roomService;
  LobbyState? _lobbyState;
  StreamSubscription<LobbyState>? _lobbySub;
  StreamSubscription<dynamic>? _stateSub;
  bool _initialized = false;
  bool _starting = false;
  String _gameId = '';
  String _roomCode = '';
  String _myUid = '';
  String _token = '';
  bool _isHost = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    _gameId = args['gameId'] as String;
    _roomCode = args['roomCode'] as String;
    _myUid = args['myUid'] as String;
    _token = args['token'] as String;
    _isHost = args['isHost'] as bool;
    _roomService = RoomService();

    _gameService = GameService(gameId: _gameId, myUid: _myUid, token: _token);

    _lobbySub = _gameService!.lobbyStream.listen((state) {
      if (mounted) setState(() => _lobbyState = state);
    });

    // Any gameState event means we left LOBBY — navigate to game
    _stateSub = _gameService!.stateStream.listen((_) {
      _navigateToGame();
    });

    _gameService!.startListening();
  }

  void _navigateToGame() {
    _lobbySub?.cancel();
    _stateSub?.cancel();
    _gameService?.dispose();
    _gameService = null;

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/game',
      arguments: RoomGameMode(
        gameId: _gameId,
        myUid: _myUid,
        token: _token,
        roomCode: _roomCode,
        isHost: _isHost,
      ),
    );
  }

  Future<void> _startGame() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _roomService!.startGame(_gameId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xFF5C1A1B),
          ),
        );
        setState(() => _starting = false);
      }
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _shareCode() {
    Clipboard.setData(
      ClipboardData(text: 'Join my Kout game! Code: $_roomCode'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share text copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _lobbySub?.cancel();
    _stateSub?.cancel();
    _gameService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoutTheme.table,
      appBar: AppBar(
        backgroundColor: KoutTheme.primary,
        title: Text(
          'Room $_roomCode',
          style: KoutTheme.headingStyle.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KoutTheme.accent),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Room code display — tap to copy
            Tooltip(
              message: 'Copy room code',
              child: Semantics(
                button: true,
                label: 'Tap to copy room code',
                child: GestureDetector(
                  onTap: _copyCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: KoutTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KoutTheme.accent, width: 2),
                    ),
                    child: Text(
                      _roomCode,
                      style: KoutTheme.headingStyle.copyWith(
                        fontSize: 36,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to copy',
              style: KoutTheme.bodyStyle.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 32),

            // Seat cards
            if (_lobbyState != null) ..._buildSeats(),
            if (_lobbyState == null)
              CircularProgressIndicator(color: KoutTheme.accent),

            const SizedBox(height: 32),

            // Action buttons
            if (_isHost) ...[
              _buildActionButton(label: 'Share Code', onPressed: _shareCode),
              const SizedBox(height: 12),
              _buildActionButton(
                label: _starting ? 'Starting...' : 'Start Game',
                onPressed: (_lobbyState?.isFull == true && !_starting)
                    ? _startGame
                    : null,
              ),
            ] else ...[
              Text(
                'Waiting for host to start...',
                style: KoutTheme.bodyStyle.copyWith(color: KoutTheme.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSeats() {
    return _lobbyState!.seats.map((seat) {
      final String label;
      final IconData icon;
      final Color color;

      if (seat.isBot) {
        label = 'Bot';
        icon = Icons.smart_toy;
        color = KoutTheme.accent.withValues(alpha: 0.6);
      } else if (seat.uid != null && seat.connected) {
        label = seat.uid == _myUid
            ? 'You'
            : (seat.seat == 0 ? 'Host' : 'Friend');
        icon = Icons.person;
        color = Colors.green;
      } else if (seat.uid != null && !seat.connected) {
        label = 'Disconnected';
        icon = Icons.person_off;
        color = Colors.orange;
      } else {
        label = 'Waiting...';
        icon = Icons.hourglass_empty;
        color = KoutTheme.accent.withValues(alpha: 0.3);
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KoutTheme.primary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Seat ${seat.seat}: $label',
                  style: KoutTheme.bodyStyle.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActionButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: 220,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: KoutTheme.primary,
          foregroundColor: KoutTheme.accent,
          disabledBackgroundColor: KoutTheme.primary.withValues(alpha: 0.5),
          disabledForegroundColor: KoutTheme.accent.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: onPressed != null
                  ? KoutTheme.accent
                  : KoutTheme.accent.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
