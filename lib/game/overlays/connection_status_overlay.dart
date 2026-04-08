import 'package:flutter/material.dart';
import '../../app/services/game_service.dart';
import '../theme/kout_theme.dart';
import 'overlay_styles.dart';

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
          child: _buildBanner(context),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return switch (status) {
      ConnectionStatus.disconnected => _banner(
        context,
        'Connection lost',
        const Icon(Icons.wifi_off, color: KoutTheme.lossColor, size: 18),
      ),
      ConnectionStatus.reconnecting => _banner(
        context,
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
      ConnectionStatus.reconnectFailed => _failedBanner(context),
      ConnectionStatus.connected => const SizedBox.shrink(),
    };
  }

  Widget _banner(BuildContext context, String text, Widget leading) {
    final maxW = MediaQuery.sizeOf(context).width - 24;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: OverlayStyles.bannerDecoration(),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: KoutTheme.textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failedBanner(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width - 24;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: OverlayStyles.bannerDecoration(isFailed: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wifi_off,
                  color: KoutTheme.lossColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Connection lost',
                    style: const TextStyle(
                      color: KoutTheme.lossColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: onReturnToMenu,
              style: OverlayStyles.primaryButton(
                borderRadius: 8.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Return to Menu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
