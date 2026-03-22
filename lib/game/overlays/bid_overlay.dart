import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';

/// Flutter overlay shown during the BIDDING phase when it is the local player's turn.
///
/// Displays bid buttons for 5/Bab, 6, 7, 8/Kout and a Pass button.
/// Styled with Diwaniya colors (burgundy background, gold buttons, cream text).
class BidOverlay extends StatelessWidget {
  final void Function(int amount) onBid;
  final VoidCallback onPass;

  const BidOverlay({super.key, required this.onBid, required this.onPass});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF5C1A1B).withOpacity(0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KoutTheme.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Place Your Bid',
              style: TextStyle(
                color: KoutTheme.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _bidButton('5\nBab', 5),
                const SizedBox(width: 12),
                _bidButton('6', 6),
                const SizedBox(width: 12),
                _bidButton('7', 7),
                const SizedBox(width: 12),
                _bidButton('8\nKout', 8),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onPass,
              style: TextButton.styleFrom(
                foregroundColor: KoutTheme.textColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                side: const BorderSide(color: KoutTheme.textColor, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Pass',
                style: TextStyle(fontSize: 14, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bidButton(String label, int amount) {
    return ElevatedButton(
      onPressed: () => onBid(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.accent,
        foregroundColor: const Color(0xFF3B1A1B),
        minimumSize: const Size(64, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }
}
