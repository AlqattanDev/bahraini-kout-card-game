import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/score_hud.dart';

void main() {
  group('ScoreHudComponent', () {
    test('creates with screen dimensions', () {
      final hud = ScoreHudComponent(screenWidth: 800);
      expect(hud.size.x, greaterThan(0));
    });

    test('formats trick pips correctly', () {
      expect(ScoreHudComponent.computePips(bidValue: 5, tricksTaken: 3), 3);
      expect(ScoreHudComponent.computePips(bidValue: 8, tricksTaken: 8), 8);
      expect(ScoreHudComponent.computePips(bidValue: 5, tricksTaken: 0), 0);
    });
  });
}
