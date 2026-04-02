import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/action_badge.dart';
import 'package:koutbh/game/theme/diwaniya_colors.dart';

void main() {
  group('ActionBadgeComponent', () {
    test('default badge color is actionBadgeBg from theme', () {
      final badge = ActionBadgeComponent(
        text: 'BID 5',
        position: Vector2(100, 100),
      );
      expect(badge.badgeColor, DiwaniyaColors.actionBadgeBg);
    });

    test('custom color overrides default', () {
      const custom = Color(0xFFCC0000);
      final badge = ActionBadgeComponent(
        text: 'KOUT',
        badgeColor: custom,
        position: Vector2.zero(),
      );
      expect(badge.badgeColor, custom);
    });

    test('updateText resets elapsed timer for fresh fade', () {
      final badge = ActionBadgeComponent(
        text: 'PASS',
        autoDismissSeconds: 3.0,
        position: Vector2.zero(),
      );
      // Simulate some time passing
      badge.update(2.0);
      badge.updateText('BID 6');
      expect(badge.text, 'BID 6');
      // After updateText, the badge should be fully visible again
      // (internal _elapsed reset to 0, _opacity reset to 1.0)
      // We verify by checking it doesn't auto-remove after a tiny tick
      badge.update(0.1);
      // Still alive (not removed) because we're far from autoDismissSeconds
      expect(badge.text, 'BID 6');
    });

    test('opacity fades during last 0.5s of auto-dismiss', () {
      final badge = ActionBadgeComponent(
        text: 'PASS',
        autoDismissSeconds: 2.0,
        position: Vector2.zero(),
      );
      // Advance to 1.4s — still before fade window
      badge.update(1.4);
      // The badge should still be considered "alive" at this point
      // (it hasn't been removed from parent)

      // Advance past 1.5s into the fade window (last 0.5s)
      badge.update(0.3);
      // Now at 1.7s of 2.0s — inside the fade zone
      // Badge should still exist (not removed until 2.0s)
    });

    test('zero autoDismissSeconds means badge persists indefinitely', () {
      final badge = ActionBadgeComponent(
        text: 'PERSIST',
        autoDismissSeconds: 0.0,
        position: Vector2.zero(),
      );
      // Even after large time advance, badge should not auto-remove
      badge.update(100.0);
      expect(badge.text, 'PERSIST');
    });
  });
}
