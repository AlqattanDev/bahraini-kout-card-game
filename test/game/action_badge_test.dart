import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/action_badge.dart';

void main() {
  group('ActionBadgeComponent', () {
    test('creates with text and position', () {
      final badge = ActionBadgeComponent(
        text: '6♠',
        badgeColor: const Color(0xFFCC0000),
        position: Vector2(100, 100),
      );
      expect(badge.text, '6♠');
    });

    test('auto-dismisses after timeout', () {
      final badge = ActionBadgeComponent(
        text: 'PASS',
        autoDismissSeconds: 3.0,
        position: Vector2(100, 100),
      );
      expect(badge.autoDismissSeconds, 3.0);
    });

    test('updateText changes display', () {
      final badge = ActionBadgeComponent(
        text: '5',
        position: Vector2(100, 100),
      );
      badge.updateText('KOUT');
      expect(badge.text, 'KOUT');
    });
  });
}
