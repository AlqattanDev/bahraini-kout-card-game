import 'package:flutter/material.dart';
import '../../app/services/game_service.dart';
import '../theme/kout_theme.dart';

/// Banner overlay showing connection status during online games.
///
/// Shows at the top of the screen, independent of game phase overlays.
/// Auto-hides when connected; shows spinner when reconnecting;
/// shows "return to menu" button when reconnection fails.
class ConnectionStatusOverlay extends StatelessWidget {
  final ConnectionStatus status;
  final int reconnectAttempt;
  final VoidCallback onReturnToMenu;

  const ConnectionStatusOverlay({
    super.key,
    required this.status,
    required this.reconnectAttempt,
    required this.onReturnToMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildBanner(),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return switch (status) {
      ConnectionStatus.disconnected => _banner(
          'Connection lost',
          const Icon(Icons.wifi_off, color: KoutTheme.lossColor, size: 18),
        ),
      ConnectionStatus.reconnecting => _banner(
          'Reconnecting... (attempt $reconnectAttempt/5)',
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KoutTheme.accent,
            ),
          ),
        ),
      ConnectionStatus.reconnectFailed => _failedBanner(),
      ConnectionStatus.connected => const SizedBox.shrink(),
    };
  }

  Widget _banner(String text, Widget leading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: KoutTheme.primary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KoutTheme.accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: KoutTheme.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: KoutTheme.primary.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoutTheme.lossColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, color: KoutTheme.lossColor, size: 18),
              SizedBox(width: 10),
              Text(
                'Connection lost',
                style: TextStyle(
                  color: KoutTheme.lossColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onReturnToMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: KoutTheme.accent,
              foregroundColor: KoutTheme.buttonForeground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Return to Menu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
