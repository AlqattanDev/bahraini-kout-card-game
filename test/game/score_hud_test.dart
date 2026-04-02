import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/score_hud.dart';

void main() {
  group('ScoreHudComponent', () {
    test('positions itself at top-right with 12px margin', () {
      final hud = ScoreHudComponent(screenWidth: 800);
      // Should be at x = 800 - 140 - 12 = 648
      expect(hud.position.x, closeTo(648, 1));
      expect(hud.position.y, 10);
    });

    test('updateWidth repositions for new screen width', () {
      final hud = ScoreHudComponent(screenWidth: 800);
      hud.updateWidth(1024);
      expect(hud.position.x, closeTo(1024 - 140 - 12, 1));
    });
  });

  group('ScoreHudComponent.computePips', () {
    test('clamps to target (bidder who took all tricks)', () {
      expect(ScoreHudComponent.computePips(target: 5, tricksTaken: 8), 5);
    });

    test('returns actual tricks when under target', () {
      expect(ScoreHudComponent.computePips(target: 6, tricksTaken: 3), 3);
    });

    test('returns 0 for zero tricks', () {
      expect(ScoreHudComponent.computePips(target: 5, tricksTaken: 0), 0);
    });

    test('clamps negative tricks to 0', () {
      expect(ScoreHudComponent.computePips(target: 5, tricksTaken: -1), 0);
    });

    test('kout bid (target=8) with all tricks returns 8', () {
      expect(ScoreHudComponent.computePips(target: 8, tricksTaken: 8), 8);
    });
  });
}
