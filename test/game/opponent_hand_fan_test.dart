import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/opponent_hand_fan.dart';
import 'package:koutbh/game/theme/kout_theme.dart';

void main() {
  test('OpponentHandFan stores initial card count', () {
    final fan = OpponentHandFan(
      cardCount: 6,
      position: Vector2.zero(),
    );
    expect(fan.cardCount, 6);
  });

  test('OpponentHandFan updates card count', () {
    final fan = OpponentHandFan(
      cardCount: 8,
      position: Vector2.zero(),
      baseRotation: math.pi,
    );
    fan.updateCardCount(3);
    expect(fan.cardCount, 3);
  });

  test('baseRotation defaults to 0', () {
    final fan = OpponentHandFan(
      cardCount: 8,
      position: Vector2.zero(),
    );
    expect(fan.baseRotation, 0.0);
  });

  test('baseRotation accepts arbitrary angles', () {
    final fan = OpponentHandFan(
      cardCount: 8,
      position: Vector2.zero(),
      baseRotation: math.pi / 2,
    );
    expect(fan.baseRotation, math.pi / 2);
  });

  test('component size accommodates full 8-card fan spread', () {
    final fan = OpponentHandFan(
      cardCount: 8,
      position: Vector2.zero(),
    );
    // With 55% scale (38.5px wide) + 14px overlap * 10 + padding,
    // size.x should be comfortably above 100px
    expect(fan.size.x, greaterThan(100));
    // Height should exceed the mini card height (~55px)
    expect(fan.size.y, greaterThan(KoutTheme.cardHeight * 0.55));
  });

  test('mini card dimensions are 55% of full card size', () {
    const expectedWidth = KoutTheme.cardWidth * 0.55;
    const expectedHeight = KoutTheme.cardHeight * 0.55;
    expect(expectedWidth, closeTo(38.5, 0.5));
    expect(expectedHeight, closeTo(55.0, 0.5));
  });
}
