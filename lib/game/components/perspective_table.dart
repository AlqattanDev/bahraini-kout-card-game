import 'dart:ui';
import 'package:flame/components.dart';
import '../managers/layout_manager.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/geometric_patterns.dart';
import '../theme/textures.dart';

/// Renders a 3D perspective table surface as a trapezoid.
class PerspectiveTableComponent extends PositionComponent {
  LayoutManager layout;

  PerspectiveTableComponent({required this.layout})
      : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  void updateLayout(LayoutManager newLayout) {
    layout = newLayout;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    TextureGenerator.drawTileTexture(canvas, rect);
    TextureGenerator.drawVignette(canvas, rect,
        intensity: layout.isLandscape ? 0.35 : 0.5);

    final verts = layout.tableVertices;

    final bodyPath = Path()
      ..moveTo(verts[0].dx, verts[0].dy)
      ..lineTo(verts[1].dx, verts[1].dy)
      ..lineTo(verts[3].dx, verts[3].dy)
      ..lineTo(verts[2].dx, verts[2].dy)
      ..close();

    final center = layout.tableCenter;
    // Proper bounding rect from all 4 vertices
    final allX = verts.map((v) => v.dx);
    final allY = verts.map((v) => v.dy);
    final tableRect = Rect.fromLTRB(
      allX.reduce((a, b) => a < b ? a : b),
      allY.reduce((a, b) => a < b ? a : b),
      allX.reduce((a, b) => a > b ? a : b),
      allY.reduce((a, b) => a > b ? a : b),
    );
    final radius = tableRect.longestSide * 0.6;

    // 3-stop radial gradient for depth: bright center → mid → dark edge
    final feltShader = Gradient.radial(
      center,
      radius,
      [
        DiwaniyaColors.tableSurfaceCenter,
        DiwaniyaColors.tableSurfaceEdge,
        const Color(0xFF252525),
      ],
      [0.0, 0.6, 1.0],
    );

    canvas.drawPath(bodyPath, Paint()..shader = feltShader);

    // Subtle inner shadow for recessed feel
    final innerShadowPaint = Paint()
      ..shader = Gradient.radial(
        center,
        radius * 1.1,
        [const Color(0x00000000), const Color(0x00000000), const Color(0x40000000)],
        [0.0, 0.7, 1.0],
      );
    canvas.drawPath(bodyPath, innerShadowPaint);

    // Outer border — dark wood rail
    final borderPaint = Paint()
      ..color = DiwaniyaColors.tableBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, borderPaint);

    // Second outer border — lighter wood highlight for 3D rail effect
    final railHighlight = Paint()
      ..color = DiwaniyaColors.tableBorder.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    final outerRailVerts = _insetVertices(verts, -2.0);
    final outerRailPath = Path()
      ..moveTo(outerRailVerts[0].dx, outerRailVerts[0].dy)
      ..lineTo(outerRailVerts[1].dx, outerRailVerts[1].dy)
      ..lineTo(outerRailVerts[3].dx, outerRailVerts[3].dy)
      ..lineTo(outerRailVerts[2].dx, outerRailVerts[2].dy)
      ..close();
    canvas.drawPath(outerRailPath, railHighlight);

    // Inner accent border — gold inlay
    final insetVerts = _insetVertices(verts, 12.0);
    final insetPath = Path()
      ..moveTo(insetVerts[0].dx, insetVerts[0].dy)
      ..lineTo(insetVerts[1].dx, insetVerts[1].dy)
      ..lineTo(insetVerts[3].dx, insetVerts[3].dy)
      ..lineTo(insetVerts[2].dx, insetVerts[2].dy)
      ..close();

    final accentPaint = Paint()
      ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(insetPath, accentPaint);

    // Subtle center glow where trick cards land
    final glowPaint = Paint()
      ..shader = Gradient.radial(
        center,
        radius * 0.3,
        [
          DiwaniyaColors.goldAccent.withValues(alpha: 0.06),
          const Color(0x00000000),
        ],
      );
    canvas.drawPath(bodyPath, glowPaint);

    // Decorative geometric motif along the top edge
    GeometricPatterns.drawStarTessellation(
      canvas,
      Rect.fromLTWH(verts[0].dx, verts[0].dy - 2, verts[1].dx - verts[0].dx, 16),
      opacity: 0.18,
      cellSize: 20.0,
    );

    // Geometric motif along bottom edge
    GeometricPatterns.drawStarTessellation(
      canvas,
      Rect.fromLTWH(verts[2].dx, verts[2].dy - 14, verts[3].dx - verts[2].dx, 16),
      opacity: 0.12,
      cellSize: 20.0,
    );
  }

  List<Offset> _insetVertices(List<Offset> verts, double amount) {
    final cx = (verts[0].dx + verts[1].dx + verts[2].dx + verts[3].dx) / 4;
    final cy = (verts[0].dy + verts[1].dy + verts[2].dy + verts[3].dy) / 4;
    final centroid = Offset(cx, cy);

    return verts.map((v) {
      final dir = centroid - v;
      final len = dir.distance;
      if (len < 1.0) return v;
      return v + dir / len * amount;
    }).toList();
  }
}
