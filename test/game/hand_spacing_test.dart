import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/managers/layout_manager.dart';

void main() {
  group('LayoutManager hand positions', () {
    final layout = LayoutManager(Vector2(800, 600));

    test('hand card spacing is adaptive based on count', () {
      final pos8 = layout.handCardPositions(8);
      final pos4 = layout.handCardPositions(4);

      final spacing8 = (pos8[1].position.x - pos8[0].position.x).abs();
      final spacing4 = (pos4[1].position.x - pos4[0].position.x).abs();
      expect(spacing4, greaterThanOrEqualTo(spacing8));
    });

    test('hand cards are centered on screen width', () {
      final pos = layout.handCardPositions(5);
      final centerX = pos.map((p) => p.position.x).reduce((a, b) => a + b) / pos.length;
      expect(centerX, closeTo(400, 30));
    });

    test('hand fan produces arc shape', () {
      final pos = layout.handCardPositions(8);
      final centerY = pos[3].position.y;
      final edgeY = pos[0].position.y;
      expect(centerY, lessThan(edgeY));
    });
  });
}
