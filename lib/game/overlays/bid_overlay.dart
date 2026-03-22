import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';

/// Flutter overlay shown during the BIDDING phase when it is the local player's turn.
///
/// Displays bid buttons for 5/Bab, 6, 7, 8/Kout and a Pass button.
/// Styled with Diwaniya colors (burgundy background, gold buttons, cream text).
/// Buttons show bilingual labels (English / Arabic).
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
            // Bilingual heading
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Place Your Bid',
                  style: KoutTheme.headingStyle.copyWith(
                    color: KoutTheme.accent,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ضع مزايدتك',
                  style: KoutTheme.arabicHeadingStyle.copyWith(
                    color: KoutTheme.accent,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _bidButton('5', KoutTheme.gameTerms['bab']!, 5),
                const SizedBox(width: 10),
                _bidButton('6', ('6', '٦'), 6),
                const SizedBox(width: 10),
                _bidButton('7', ('7', '٧'), 7),
                const SizedBox(width: 10),
                _bidButton('8', KoutTheme.gameTerms['kout']!, 8),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    KoutTheme.gameTerms['pass']!.$1,
                    style: KoutTheme.bodyStyle,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    KoutTheme.gameTerms['pass']!.$2,
                    style: KoutTheme.arabicBodyStyle,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bidButton(String number, (String, String) label, int amount) {
    return ElevatedButton(
      onPressed: () => onBid(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: KoutTheme.accent,
        foregroundColor: const Color(0xFF3B1A1B),
        minimumSize: const Size(68, 68),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label.$1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label.$2,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
