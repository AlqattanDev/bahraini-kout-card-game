import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/managers/layout_manager.dart';

void main() {
  group('LayoutManager table geometry', () {
    final layout = LayoutManager(Vector2(800, 600));

    test('trapezoid has 4 vertices in correct order (TL, TR, BL, BR)', () {
      final verts = layout.tableVertices;
      expect(verts.length, 4);
      // Top-left.x < top-right.x
      expect(verts[0].dx, lessThan(verts[1].dx));
      // Bottom-left.x < bottom-right.x
      expect(verts[2].dx, lessThan(verts[3].dx));
      // Top-left.y == top-right.y (same row)
      expect(verts[0].dy, verts[1].dy);
      // Bottom-left.y == bottom-right.y (same row)
      expect(verts[2].dy, verts[3].dy);
    });

    test('bottom edge is wider than top (perspective foreshortening)', () {
      final verts = layout.tableVertices;
      final topWidth = verts[1].dx - verts[0].dx;
      final botWidth = verts[3].dx - verts[2].dx;
      expect(botWidth, greaterThan(topWidth));
      // Specifically: 85% vs 55% of screen width
      expect(topWidth, closeTo(800 * 0.55, 1));
      expect(botWidth, closeTo(800 * 0.85, 1));
    });

    test('table top clears score panel area (>= 60px)', () {
      final verts = layout.tableVertices;
      expect(verts[0].dy, greaterThanOrEqualTo(60));
    });

    test('table bottom leaves room for hand area', () {
      final verts = layout.tableVertices;
      // Hand center is at height - 80, table should end before that
      expect(verts[2].dy, lessThan(600 - 80));
    });

    test('table center is centroid of all 4 vertices', () {
      final verts = layout.tableVertices;
      final expectedCx = (verts[0].dx + verts[1].dx + verts[2].dx + verts[3].dx) / 4;
      final expectedCy = (verts[0].dy + verts[1].dy + verts[2].dy + verts[3].dy) / 4;
      expect(layout.tableCenter.dx, closeTo(expectedCx, 0.01));
      expect(layout.tableCenter.dy, closeTo(expectedCy, 0.01));
    });

    test('table is horizontally centered on screen', () {
      final verts = layout.tableVertices;
      final topMidX = (verts[0].dx + verts[1].dx) / 2;
      final botMidX = (verts[2].dx + verts[3].dx) / 2;
      expect(topMidX, closeTo(400, 1));
      expect(botMidX, closeTo(400, 1));
    });

    test('scales proportionally with screen size', () {
      final small = LayoutManager(Vector2(400, 300));
      final large = LayoutManager(Vector2(1200, 900));
      final smallTop = small.tableVertices[1].dx - small.tableVertices[0].dx;
      final largeTop = large.tableVertices[1].dx - large.tableVertices[0].dx;
      expect(largeTop / smallTop, closeTo(3.0, 0.1));
    });
  });
}
