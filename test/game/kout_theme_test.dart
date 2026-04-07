import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/kout_theme.dart';
import 'package:koutbh/game/theme/diwaniya_colors.dart';

void main() {
  group('KoutTheme card dimensions', () {
    test('card aspect ratio is roughly 5:7', () {
      final ratio = KoutTheme.cardWidth / KoutTheme.cardHeight;
      expect(ratio, closeTo(5 / 7, 0.05));
    });

  });

  group('KoutTheme typography', () {
    test('heading style uses IBMPlexMono', () {
      expect(KoutTheme.headingStyle.fontFamily, 'IBMPlexMono');
    });

    test('heading font size is larger than body', () {
      expect(KoutTheme.headingStyle.fontSize!,
          greaterThan(KoutTheme.bodyStyle.fontSize!));
    });
  });

  group('KoutTheme DiwaniyaColors delegates', () {
    test('goldAccent delegates to DiwaniyaColors', () {
      expect(identical(KoutTheme.goldAccent, DiwaniyaColors.goldAccent), isTrue);
    });
  });

  group('KoutTheme shadow rendering', () {
    test('shadow offset Y is greater than X (light from upper-left)', () {
      expect(KoutTheme.cardShadowOffsetY, greaterThan(KoutTheme.cardShadowOffsetX));
    });

    test('shadow color has partial transparency', () {
      expect(KoutTheme.cardShadowColor.a, lessThan(1.0));
      expect(KoutTheme.cardShadowColor.a, greaterThan(0.0));
    });
  });

}
