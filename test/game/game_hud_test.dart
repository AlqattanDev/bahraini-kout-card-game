import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/game_hud.dart';

void main() {
  group('GameHudComponent', () {
    test('starts at round 1, trick 0', () {
      final hud = GameHudComponent();
      expect(hud.roundNumber, 1);
      expect(hud.trickNumber, 0);
    });

    test('updateRound sets both round and trick', () {
      final hud = GameHudComponent();
      hud.updateRound(3, trick: 5);
      expect(hud.roundNumber, 3);
      expect(hud.trickNumber, 5);
    });

    test('updateRound defaults trick to 0 when omitted', () {
      final hud = GameHudComponent();
      hud.updateRound(2);
      expect(hud.trickNumber, 0);
    });

    test('positioned at top-left with margin', () {
      final hud = GameHudComponent();
      expect(hud.position.x, 12);
      expect(hud.position.y, 14);
    });

    test('size matches static dimensions', () {
      final hud = GameHudComponent();
      expect(hud.size.x, 90);
      expect(hud.size.y, 36);
    });
  });
}
