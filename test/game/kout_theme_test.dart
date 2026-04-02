import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/kout_theme.dart';
import 'package:koutbh/game/theme/diwaniya_colors.dart';

void main() {
  group('KoutTheme card dimensions', () {
    test('card aspect ratio is roughly 5:7', () {
      final ratio = KoutTheme.cardWidth / KoutTheme.cardHeight;
      expect(ratio, closeTo(5 / 7, 0.05));
    });

    test('large card dimensions maintain same aspect ratio', () {
      final stdRatio = KoutTheme.cardWidth / KoutTheme.cardHeight;
      final lgRatio = KoutTheme.cardWidthLarge / KoutTheme.cardHeightLarge;
      expect(lgRatio, closeTo(stdRatio, 0.02));
    });

    test('large cards are actually larger than standard', () {
      expect(KoutTheme.cardWidthLarge, greaterThan(KoutTheme.cardWidth));
      expect(KoutTheme.cardHeightLarge, greaterThan(KoutTheme.cardHeight));
    });
  });

  group('KoutTheme typography', () {
    test('heading style uses IBMPlexMono', () {
      expect(KoutTheme.headingStyle.fontFamily, 'IBMPlexMono');
    });

    test('arabic heading style uses NotoKufiArabic', () {
      expect(KoutTheme.arabicHeadingStyle.fontFamily, 'NotoKufiArabic');
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

  group('KoutTheme game terms', () {
    test('bilingual terms cover essential game actions', () {
      expect(KoutTheme.gameTerms, contains('bab'));
      expect(KoutTheme.gameTerms, contains('kout'));
      expect(KoutTheme.gameTerms, contains('pass'));
      expect(KoutTheme.gameTerms, contains('trump'));
    });

    test('each game term has both English and Arabic', () {
      for (final entry in KoutTheme.gameTerms.entries) {
        final (en, ar) = entry.value;
        expect(en.isNotEmpty, isTrue, reason: '${entry.key} English label empty');
        expect(ar.isNotEmpty, isTrue, reason: '${entry.key} Arabic label empty');
      }
    });
  });
}
