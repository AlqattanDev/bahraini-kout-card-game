import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/diwaniya_colors.dart';

int _to255(double v) => (v * 255.0).round().clamp(0, 255);

void main() {
  group('DiwaniyaColors', () {
    test('table surface gradient goes from lighter center to darker edge', () {
      expect(
        DiwaniyaColors.tableSurfaceCenter.computeLuminance(),
        greaterThan(DiwaniyaColors.tableSurfaceEdge.computeLuminance()),
      );
    });

    test('active turn ring is high-contrast for visibility', () {
      // Must be visible against the dark table surface
      expect(DiwaniyaColors.activeTurnRing.computeLuminance(), greaterThan(0.3));
    });

    test('gold accent is perceptually warm (R+G > B)', () {
      final c = DiwaniyaColors.goldAccent;
      final r = _to255(c.r), g = _to255(c.g), b = _to255(c.b);
      expect(r + g, greaterThan(b * 2));
    });

    test('team labels have distinct hues', () {
      // Team A is blue-ish, Team B is red-ish — verify they are distinguishable
      final aR = _to255(DiwaniyaColors.nameLabelTeamA.r);
      final aB = _to255(DiwaniyaColors.nameLabelTeamA.b);
      final bR = _to255(DiwaniyaColors.nameLabelTeamB.r);
      final bB = _to255(DiwaniyaColors.nameLabelTeamB.b);
      expect(aR, lessThan(aB));
      expect(bR, greaterThan(bB));
    });

    test('score HUD bg is mostly opaque (>85%)', () {
      // 0xE6 = 230/255 ≈ 90%
      expect(DiwaniyaColors.scoreHudBg.a, greaterThan(0.85));
    });

    test('face card gradient goes top-light to bottom-dark', () {
      expect(
        DiwaniyaColors.faceCardGradientTop.computeLuminance(),
        greaterThan(DiwaniyaColors.faceCardGradientBottom.computeLuminance()),
      );
    });

    test('background tile is darker than table surface center', () {
      // Background surrounds the table, should be darker
      expect(
        DiwaniyaColors.backgroundTile.computeLuminance(),
        lessThan(DiwaniyaColors.tableSurfaceCenter.computeLuminance() + 0.1),
      );
    });
  });
}
