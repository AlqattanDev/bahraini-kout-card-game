import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/kout_theme.dart';

/// Displays a player seat: circular avatar frame, name, card count badge,
/// team color dot, and an active-turn glow.
class PlayerSeatComponent extends PositionComponent {
  String playerName;
  int cardCount;
  bool isActive;
  bool isTeamA; // true = Team A, false = Team B
  bool isDealer;

  static const double _radius = 36.0;
  static const double _badgeRadius = 12.0;

  PlayerSeatComponent({
    required this.playerName,
    required this.cardCount,
    required this.isActive,
    required this.isTeamA,
    this.isDealer = false,
    super.position,
    super.anchor = Anchor.center,
  }) : super(size: Vector2.all(_radius * 2 + 20));

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);

    // Glow when active
    if (isActive) {
      final glowPaint = Paint()
        ..color = KoutTheme.accent.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, _radius + 8, glowPaint);
    }

    // Outer ring — team color
    final teamColor = isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor;
    final ringPaint = Paint()
      ..color = teamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, _radius, ringPaint);

    // Circle fill
    final fillPaint = Paint()..color = KoutTheme.secondary.withOpacity(0.85);
    canvas.drawCircle(center, _radius - 2, fillPaint);

    // Active border highlight
    if (isActive) {
      final activePaint = Paint()
        ..color = KoutTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, _radius, activePaint);
    }

    // Dealer dot
    if (isDealer) {
      final dealerPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawCircle(Offset(center.dx + _radius - 6, center.dy - _radius + 6), 5, dealerPaint);
    }

    // Player name
    _drawText(
      canvas,
      _truncateName(playerName),
      KoutTheme.textColor,
      Offset(center.dx, center.dy - 6),
      11,
    );

    // Card count badge (bottom-right of circle)
    final badgeCenter = Offset(center.dx + _radius - 4, center.dy + _radius - 4);
    final badgePaint = Paint()..color = KoutTheme.primary;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgePaint);
    final badgeBorderPaint = Paint()
      ..color = KoutTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgeBorderPaint);
    _drawText(
      canvas,
      '$cardCount',
      KoutTheme.textColor,
      badgeCenter,
      10,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Color color,
    Offset center,
    double fontSize,
  ) {
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ParagraphConstraints(width: 80));

    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - 40, center.dy - fontSize / 2),
    );
  }

  String _truncateName(String name) {
    if (name.length <= 8) return name;
    return '${name.substring(0, 7)}…';
  }

  void updateState({
    required String name,
    required int cards,
    required bool active,
    required bool teamA,
    bool dealer = false,
  }) {
    playerName = name;
    cardCount = cards;
    isActive = active;
    isTeamA = teamA;
    isDealer = dealer;
  }
}
