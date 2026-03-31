import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/game/components/opponent_hand_fan.dart';

void main() {
  test('OpponentHandFan stores initial card count', () {
    final fan = OpponentHandFan(
      cardCount: 6,
      position: Vector2.zero(),
      fanDirection: FanDirection.right,
    );
    expect(fan.cardCount, 6);
  });

  test('OpponentHandFan updates card count', () {
    final fan = OpponentHandFan(
      cardCount: 8,
      position: Vector2.zero(),
      fanDirection: FanDirection.above,
    );
    fan.updateCardCount(3);
    expect(fan.cardCount, 3);
  });

  test('all FanDirection values exist', () {
    expect(FanDirection.values.length, 3);
    expect(FanDirection.left, isNotNull);
    expect(FanDirection.right, isNotNull);
    expect(FanDirection.above, isNotNull);
  });
}
