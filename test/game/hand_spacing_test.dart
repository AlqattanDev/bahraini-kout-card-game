import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/managers/layout_manager.dart';

void main() {
  group('LayoutManager hand positions', () {
    // Portrait: 600 wide × 800 tall
    final layout = LayoutManager(Vector2(600, 800));

    test('fewer cards get wider spacing than more cards', () {
      final pos4 = layout.handCardPositions(4);
      final pos8 = layout.handCardPositions(8);
      final spacing4 = (pos4[1].position.x - pos4[0].position.x).abs();
      final spacing8 = (pos8[1].position.x - pos8[0].position.x).abs();
      expect(spacing4, greaterThan(spacing8));
    });

    test('hand is horizontally centered on screen', () {
      for (final count in [3, 5, 8]) {
        final pos = layout.handCardPositions(count);
        final avgX = pos.map((p) => p.position.x).reduce((a, b) => a + b) / count;
        expect(avgX, closeTo(300, 30), reason: 'Hand of $count cards not centered');
      }
    });

    test('fan creates arc shape (center cards higher than edges)', () {
      final pos = layout.handCardPositions(8);
      final edgeY = pos.first.position.y;
      final midY = pos[3].position.y;
      expect(midY, lessThan(edgeY), reason: 'Center cards should be higher (lower Y)');
    });

    test('empty hand returns empty list', () {
      expect(layout.handCardPositions(0), isEmpty);
    });

    test('single card is centered with zero angle', () {
      final pos = layout.handCardPositions(1);
      expect(pos.length, 1);
      expect(pos[0].position.x, closeTo(300, 1));
      expect(pos[0].angle, 0.0);
    });

    test('angles are symmetric (left negative, right positive)', () {
      final pos = layout.handCardPositions(8);
      // First card angle should be negative (left tilt)
      expect(pos.first.angle, lessThan(0));
      // Last card angle should be positive (right tilt)
      expect(pos.last.angle, greaterThan(0));
      // They should be roughly symmetric
      expect(pos.first.angle, closeTo(-pos.last.angle, 0.01));
    });

    test('spacing stays within clamped range [44, 72]', () {
      for (int count = 1; count <= 8; count++) {
        final pos = layout.handCardPositions(count);
        if (pos.length < 2) continue;
        final spacing = (pos[1].position.x - pos[0].position.x).abs();
        expect(spacing, greaterThanOrEqualTo(44), reason: 'Spacing too tight for $count cards');
        expect(spacing, lessThanOrEqualTo(72), reason: 'Spacing too wide for $count cards');
      }
    });
  });

  group('LayoutManager landscape mode', () {
    // iPhone 15 Pro landscape: 852x393, safe area 59/59/0/21
    final landscapeLayout = LayoutManager(
      Vector2(852, 393),
      safeArea: const EdgeInsets.only(left: 59, right: 59, bottom: 21),
    );

    test('isLandscape is true when width > height', () {
      expect(landscapeLayout.isLandscape, isTrue);
    });

    test('safeRect excludes insets', () {
      expect(landscapeLayout.safeRect.left, 59);
      expect(landscapeLayout.safeRect.right, 852 - 59);
      expect(landscapeLayout.safeRect.bottom, 393 - 21);
      expect(landscapeLayout.safeRect.top, 0);
    });

    test('hand center is within safe rect horizontally', () {
      final hc = landscapeLayout.handCenter;
      expect(hc.x, greaterThan(landscapeLayout.safeRect.left));
      expect(hc.x, lessThan(landscapeLayout.safeRect.right));
    });

    test('trick center is within safe rect', () {
      final tc = landscapeLayout.trickCenter;
      expect(tc.x, greaterThan(landscapeLayout.safeRect.left));
      expect(tc.x, lessThan(landscapeLayout.safeRect.right));
      expect(tc.y, greaterThan(landscapeLayout.safeRect.top));
      expect(tc.y, lessThan(landscapeLayout.safeRect.bottom));
    });

    test('handCardScale is smaller on landscape phone', () {
      expect(landscapeLayout.handCardScale, lessThan(1.4));
      expect(landscapeLayout.handCardScale, greaterThan(0.5));
    });

    test('portrait layout is unchanged when no safe area', () {
      final portrait = LayoutManager(Vector2(600, 800));
      expect(portrait.isLandscape, isFalse);
      expect(portrait.handCenter, Vector2(300, 720));
      expect(portrait.handCardScale, 1.4);
    });
  });
}
