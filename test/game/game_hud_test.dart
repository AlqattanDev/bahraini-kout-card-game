import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/game_hud.dart';

void main() {
  group('GameHudComponent', () {
    test('creates with initial values', () {
      final hud = GameHudComponent();
      expect(hud.roundNumber, 1);
      expect(hud.trickNumber, 0);
    });

    test('update changes values', () {
      final hud = GameHudComponent();
      hud.updateRound(3, trick: 5);
      expect(hud.roundNumber, 3);
      expect(hud.trickNumber, 5);
    });
  });
}
