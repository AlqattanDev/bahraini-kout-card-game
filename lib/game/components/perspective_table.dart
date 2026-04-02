import 'dart:ui';
import 'package:flame/components.dart';
import '../managers/layout_manager.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/geometric_patterns.dart';

/// Renders a 3D perspective table surface as a trapezoid.
class PerspectiveTableComponent extends PositionComponent {
  LayoutManager layout;

  PerspectiveTableComponent({required this.layout})
      : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize;
  }

  void updateLayout(LayoutManager newLayout) {
    layout = newLayout;
  }

  @override
  void render(Canvas canvas) {
    final verts = layout.tableVertices;

    final bodyPath = Path()
      ..moveTo(verts[0].dx, verts[0].dy)
      ..lineTo(verts[1].dx, verts[1].dy)
      ..lineTo(verts[3].dx, verts[3].dy)
      ..lineTo(verts[2].dx, verts[2].dy)
      ..close();

    final center = layout.tableCenter;
    final tableRect = Rect.fromPoints(verts[0], verts[3]);
    final radius = tableRect.longestSide * 0.6;

    final feltShader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: const [
        DiwaniyaColors.tableSurfaceCenter,
        DiwaniyaColors.tableSurfaceEdge,
      ],
      stops: const [0.0, 1.0],
    ).createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    canvas.drawPath(bodyPath, Paint()..shader = feltShader);

    final borderPaint = Paint()
      ..color = DiwaniyaColors.tableBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bodyPath, borderPaint);

    final insetVerts = _insetVertices(verts, 8.0);
    final insetPath = Path()
      ..moveTo(insetVerts[0].dx, insetVerts[0].dy)
      ..lineTo(insetVerts[1].dx, insetVerts[1].dy)
      ..lineTo(insetVerts[3].dx, insetVerts[3].dy)
      ..lineTo(insetVerts[2].dx, insetVerts[2].dy)
      ..close();

    final accentPaint = Paint()
      ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(insetPath, accentPaint);

    // Decorative geometric motif along the top edge of the table
    GeometricPatterns.drawStarTessellation(
      canvas,
      Rect.fromLTWH(verts[0].dx, verts[0].dy - 2, verts[1].dx - verts[0].dx, 12),
      opacity: 0.15,
      cellSize: 24.0,
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
