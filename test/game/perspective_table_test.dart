import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/managers/layout_manager.dart';

void main() {
  group('LayoutManager table geometry', () {
    final layout = LayoutManager(Vector2(800, 600));

    test('table trapezoid has 4 vertices', () {
      final verts = layout.tableVertices;
      expect(verts.length, 4);
    });

    test('bottom edge is wider than top edge (perspective)', () {
      final verts = layout.tableVertices;
      final bottomWidth = (verts[3].dx - verts[2].dx).abs();
      final topWidth = (verts[1].dx - verts[0].dx).abs();
      expect(bottomWidth, greaterThan(topWidth));
    });

    test('table top edge starts below score panel', () {
      final verts = layout.tableVertices;
      expect(verts[0].dy, greaterThanOrEqualTo(60));
    });

    test('table bottom edge is above hand area', () {
      final verts = layout.tableVertices;
      expect(verts[2].dy, lessThan(600 - 80));
    });
  });
}
