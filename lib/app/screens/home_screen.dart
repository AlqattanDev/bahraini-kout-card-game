import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../game/theme/kout_theme.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      await _authService.signInAnonymously().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      // Auth failed or timed out — still show buttons so offline works
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoutTheme.table,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bahraini Kout',
              style: KoutTheme.headingStyle.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 48),
            if (_isLoading)
              Column(
                children: [
                  CircularProgressIndicator(
                    color: KoutTheme.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signing in...',
                    style: KoutTheme.bodyStyle.copyWith(color: KoutTheme.accent),
                  ),
                ],
              ),
            AnimatedOpacity(
              opacity: _isLoading ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: Column(
                children: [
                  if (!_isLoading)
                    _buildButton(
                      label: 'Play Online',
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/matchmaking',
                          arguments: {
                            'uid': _authService.currentUid,
                            'token': _authService.token,
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  if (!_isLoading)
                    _buildButton(
                      label: 'Play with Friend',
                      onPressed: _showRoomOptions,
                    ),
                  const SizedBox(height: 16),
                  if (!_isLoading)
                    _buildButton(
                      label: 'Play Offline',
                      onPressed: () => Navigator.pushNamed(context, '/offline-lobby'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KoutTheme.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Play with Friend',
                style: KoutTheme.headingStyle.copyWith(fontSize: 20)),
            const SizedBox(height: 24),
            _buildButton(
                label: 'Create Room',
                onPressed: () {
                  Navigator.pop(ctx);
                  _createRoom();
                }),
            const SizedBox(height: 12),
            _buildButton(
                label: 'Join Room',
                onPressed: () {
                  Navigator.pop(ctx);
                  _showJoinDialog();
                }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    final roomService = RoomService();
    try {
      final result = await roomService.createRoom();
      if (!mounted) return;
      Navigator.pushNamed(context, '/room-lobby', arguments: {
        'gameId': result.gameId,
        'roomCode': result.roomCode,
        'myUid': _authService.currentUid,
        'token': _authService.token,
        'isHost': true,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create room: $e')),
        );
      }
    }
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KoutTheme.primary,
        title: Text('Join Room',
            style: KoutTheme.headingStyle.copyWith(fontSize: 18)),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          style: KoutTheme.bodyStyle.copyWith(fontSize: 20, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: 'ENTER CODE',
            hintStyle: KoutTheme.bodyStyle
                .copyWith(color: KoutTheme.accent.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: KoutTheme.accent)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: KoutTheme.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: KoutTheme.bodyStyle),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinRoom(controller.text);
            },
            child: Text('Join',
                style: KoutTheme.bodyStyle
                    .copyWith(color: KoutTheme.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _joinRoom(String code) async {
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code must be 6 characters')),
      );
      return;
    }
    final roomService = RoomService();
    try {
      final gameId = await roomService.joinRoom(code);
      if (!mounted) return;
      Navigator.pushNamed(context, '/room-lobby', arguments: {
        'gameId': gameId,
        'roomCode': code.toUpperCase(),
        'myUid': _authService.currentUid,
        'token': _authService.token,
        'isHost': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: min(220.0, MediaQuery.sizeOf(context).width * 0.6),
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        style: KoutTheme.primaryButtonStyle,
        child: Text(label),
      ),
    );
  }
}
