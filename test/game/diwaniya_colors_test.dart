import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/diwaniya_colors.dart';

void main() {
  group('DiwaniyaColors', () {
    test('background tile color is defined and opaque', () {
      expect(DiwaniyaColors.backgroundTile.alpha, 1.0);
    });
    test('table surface colors form a gradient (surface lighter than edge)', () {
      expect(
        DiwaniyaColors.tableSurfaceCenter.computeLuminance(),
        greaterThan(DiwaniyaColors.tableSurfaceEdge.computeLuminance()),
      );
    });
    test('active turn ring color is high contrast', () {
      expect(DiwaniyaColors.activeTurnRing.computeLuminance(), greaterThan(0.3));
    });
    test('all Diwaniya theme colors are non-null', () {
      expect(DiwaniyaColors.backgroundTile, isNotNull);
      expect(DiwaniyaColors.backgroundTileDark, isNotNull);
      expect(DiwaniyaColors.tableSurfaceCenter, isNotNull);
      expect(DiwaniyaColors.tableSurfaceEdge, isNotNull);
      expect(DiwaniyaColors.tableFelt, isNotNull);
      expect(DiwaniyaColors.goldAccent, isNotNull);
      expect(DiwaniyaColors.goldHighlight, isNotNull);
      expect(DiwaniyaColors.burgundy, isNotNull);
      expect(DiwaniyaColors.cream, isNotNull);
      expect(DiwaniyaColors.darkWood, isNotNull);
      expect(DiwaniyaColors.activeTurnRing, isNotNull);
      expect(DiwaniyaColors.actionBadgeBg, isNotNull);
    });
  });
}
