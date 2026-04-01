import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/kout_theme.dart';

void main() {
  group('card presentation constants', () {
    test('card face is pure white', () {
      expect(KoutTheme.cardFace.value, 0xFFFFFFFF);
    });

    test('card border is dark gray', () {
      expect(KoutTheme.cardBorder.value, 0xFF2A2A2A);
    });

    test('card corner rank size exists and is 16', () {
      expect(KoutTheme.cardCornerRankSize, 16.0);
    });

    test('card corner suit size exists and is 14', () {
      expect(KoutTheme.cardCornerSuitSize, 14.0);
    });

    test('card center suit size exists and is 32', () {
      expect(KoutTheme.cardCenterSuitSize, 32.0);
    });

    test('card shadow constants exist', () {
      expect(KoutTheme.cardShadowBlur, 4.0);
      expect(KoutTheme.cardShadowOffsetX, 2.0);
      expect(KoutTheme.cardShadowOffsetY, 3.0);
      expect(KoutTheme.cardShadowColor.alpha, greaterThan(0));
    });

    test('joker color exists', () {
      expect(KoutTheme.jokerColor.value, 0xFF1A1A1A);
    });
  });
}
