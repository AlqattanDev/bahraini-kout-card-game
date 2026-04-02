import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';

/// A floating speech-bubble badge that shows a player's last action.
class ActionBadgeComponent extends PositionComponent {
  String text;
  Color badgeColor;
  double autoDismissSeconds;

  double _elapsed = 0;
  double _opacity = 1.0;

  static const double _paddingH = 10.0;
  static const double _paddingV = 5.0;
  static const double _fontSize = 14.0;
  static const double _tailSize = 6.0;
  static const double _borderRadius = 8.0;

  ActionBadgeComponent({
    required this.text,
    this.badgeColor = DiwaniyaColors.actionBadgeBg,
    this.autoDismissSeconds = 0.0,
    super.position,
    super.anchor = Anchor.center,
  }) : super(size: Vector2(60, 30));

  void updateText(String newText, {Color? color}) {
    text = newText;
    if (color != null) badgeColor = color;
    _elapsed = 0;
    _opacity = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (autoDismissSeconds > 0) {
      _elapsed += dt;
      if (_elapsed > autoDismissSeconds - 0.5) {
        _opacity = ((autoDismissSeconds - _elapsed) / 0.5).clamp(0.0, 1.0);
      }
      if (_elapsed >= autoDismissSeconds) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (text.isEmpty) return;

    final pb = ParagraphBuilder(
      ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: _fontSize,
        fontFamily: 'IBMPlexMono',
      ),
    )
      ..pushStyle(TextStyle(
        color: DiwaniyaColors.cream.withValues(alpha: _opacity),
        fontWeight: FontWeight.bold,
      ))
      ..addText(text);
    final paragraph = pb.build();
    paragraph.layout(const ParagraphConstraints(width: 100));

    final textWidth = paragraph.longestLine;
    final textHeight = paragraph.height;
    final badgeW = textWidth + _paddingH * 2;
    final badgeH = textHeight + _paddingV * 2;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: badgeW, height: badgeH),
      Radius.circular(_borderRadius),
    );

    final bgPaint = Paint()..color = badgeColor.withValues(alpha: 0.9 * _opacity);
    canvas.drawRRect(badgeRect, bgPaint);

    final borderPaint = Paint()
      ..color = DiwaniyaColors.actionBadgeBorder.withValues(alpha: 0.6 * _opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(badgeRect, borderPaint);

    final tailPath = Path()
      ..moveTo(-_tailSize, badgeH / 2)
      ..lineTo(0, badgeH / 2 + _tailSize)
      ..lineTo(_tailSize, badgeH / 2);
    canvas.drawPath(tailPath, bgPaint);

    canvas.drawParagraph(
      paragraph,
      Offset(-textWidth / 2, -textHeight / 2),
    );
  }
}
