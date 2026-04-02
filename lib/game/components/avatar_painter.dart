import 'dart:math' as math;
import 'dart:ui';

/// Traits that define a procedural character avatar's appearance.
class AvatarTraits {
  final Color skinTone;
  final Color hairColor;
  final bool hasGhutra;
  final bool hasBeard;
  final bool hasSunglasses;
  final int eyeStyle;
  final int mouthStyle;
  final Color ghutraColor;

  const AvatarTraits({
    required this.skinTone,
    required this.hairColor,
    required this.hasGhutra,
    required this.hasBeard,
    required this.hasSunglasses,
    required this.eyeStyle,
    required this.mouthStyle,
    required this.ghutraColor,
  });

  factory AvatarTraits.fromSeed(int seed) {
    const presets = [
      AvatarTraits(
        skinTone: Color(0xFFD4A574),
        hairColor: Color(0xFF2C1810),
        hasGhutra: false,
        hasBeard: false,
        hasSunglasses: false,
        eyeStyle: 0,
        mouthStyle: 1,
        ghutraColor: Color(0xFFFFFFFF),
      ),
      AvatarTraits(
        skinTone: Color(0xFFC68642),
        hairColor: Color(0xFFCCCCCC),
        hasGhutra: true,
        hasBeard: true,
        hasSunglasses: false,
        eyeStyle: 1,
        mouthStyle: 2,
        ghutraColor: Color(0xFFFFFFFF),
      ),
      AvatarTraits(
        skinTone: Color(0xFFBE8A60),
        hairColor: Color(0xFF1A1A1A),
        hasGhutra: true,
        hasBeard: true,
        hasSunglasses: false,
        eyeStyle: 2,
        mouthStyle: 0,
        ghutraColor: Color(0xFFCC3333),
      ),
      AvatarTraits(
        skinTone: Color(0xFFD4A574),
        hairColor: Color(0xFF1A1A1A),
        hasGhutra: true,
        hasBeard: false,
        hasSunglasses: true,
        eyeStyle: 0,
        mouthStyle: 1,
        ghutraColor: Color(0xFFFFFFFF),
      ),
    ];
    return presets[seed % presets.length];
  }
}

/// Paints a procedural character avatar onto a Canvas.
class AvatarPainter {
  static void paint(Canvas canvas, Offset center, double radius, AvatarTraits traits) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF8FBFE0));

    final headRadius = radius * 0.65;
    final headCenter = Offset(center.dx, center.dy + radius * 0.1);
    canvas.drawCircle(headCenter, headRadius, Paint()..color = traits.skinTone);

    final eyeY = headCenter.dy - headRadius * 0.15;
    final eyeSpacing = headRadius * 0.35;

    if (traits.hasSunglasses) {
      _drawSunglasses(canvas, headCenter, headRadius, eyeY, eyeSpacing);
    } else {
      _drawEyes(canvas, eyeY, headCenter.dx, eyeSpacing, headRadius, traits.eyeStyle);
    }

    _drawMouth(canvas, headCenter, headRadius, traits.mouthStyle);

    if (traits.hasBeard) {
      _drawBeard(canvas, headCenter, headRadius, traits.hairColor);
    }

    if (traits.hasGhutra) {
      _drawGhutra(canvas, headCenter, headRadius, traits.ghutraColor, radius);
    } else {
      _drawHair(canvas, headCenter, headRadius, traits.hairColor);
    }

    canvas.restore();
  }

  static void _drawEyes(Canvas canvas, double eyeY, double cx, double spacing, double headR, int style) {
    final eyePaint = Paint()..color = const Color(0xFF1A1A1A);
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    final eyeR = headR * (style == 2 ? 0.12 : style == 1 ? 0.08 : 0.10);
    final whiteR = eyeR * 1.6;

    for (final dx in [-spacing, spacing]) {
      canvas.drawOval(
        Rect.fromCircle(center: Offset(cx + dx, eyeY), radius: whiteR),
        whitePaint,
      );
      canvas.drawCircle(Offset(cx + dx, eyeY), eyeR, eyePaint);
      canvas.drawCircle(
        Offset(cx + dx + eyeR * 0.3, eyeY - eyeR * 0.3),
        eyeR * 0.35,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
  }

  static void _drawSunglasses(Canvas canvas, Offset headCenter, double headR, double eyeY, double spacing) {
    final lensR = headR * 0.22;
    final glassesPaint = Paint()..color = const Color(0xFF111111);
    final framePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(headCenter.dx - spacing + lensR, eyeY),
      Offset(headCenter.dx + spacing - lensR, eyeY),
      framePaint,
    );

    for (final dx in [-spacing, spacing]) {
      final lensRect = RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset(headCenter.dx + dx, eyeY), radius: lensR),
        Radius.circular(lensR * 0.4),
      );
      canvas.drawRRect(lensRect, glassesPaint);
      canvas.drawRRect(lensRect, framePaint);
    }
  }

  static void _drawMouth(Canvas canvas, Offset headCenter, double headR, int style) {
    final mouthY = headCenter.dy + headR * 0.35;
    final mouthPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final mouthW = headR * 0.3;
    switch (style) {
      case 1:
        final path = Path()
          ..moveTo(headCenter.dx - mouthW, mouthY)
          ..quadraticBezierTo(headCenter.dx, mouthY + headR * 0.15, headCenter.dx + mouthW, mouthY);
        canvas.drawPath(path, mouthPaint);
      case 2:
        canvas.drawLine(
          Offset(headCenter.dx - mouthW, mouthY),
          Offset(headCenter.dx + mouthW, mouthY),
          mouthPaint,
        );
      default:
        final path = Path()
          ..moveTo(headCenter.dx - mouthW * 0.8, mouthY)
          ..quadraticBezierTo(headCenter.dx, mouthY + headR * 0.05, headCenter.dx + mouthW * 0.8, mouthY);
        canvas.drawPath(path, mouthPaint);
    }
  }

  static void _drawBeard(Canvas canvas, Offset headCenter, double headR, Color color) {
    final beardPath = Path();
    final beardTop = headCenter.dy + headR * 0.2;
    final beardBot = headCenter.dy + headR * 0.85;
    final beardW = headR * 0.55;

    beardPath.moveTo(headCenter.dx - beardW, beardTop);
    beardPath.quadraticBezierTo(
      headCenter.dx - beardW * 0.8, beardBot,
      headCenter.dx, beardBot + headR * 0.1,
    );
    beardPath.quadraticBezierTo(
      headCenter.dx + beardW * 0.8, beardBot,
      headCenter.dx + beardW, beardTop,
    );

    canvas.drawPath(beardPath, Paint()..color = color.withValues(alpha: 0.7));
  }

  static void _drawGhutra(Canvas canvas, Offset headCenter, double headR, Color color, double circleRadius) {
    final ghutraPath = Path();
    final topY = headCenter.dy - headR * 1.0;
    final drapeSide = headR * 1.1;

    ghutraPath.moveTo(headCenter.dx - drapeSide, headCenter.dy - headR * 0.3);
    ghutraPath.lineTo(headCenter.dx - drapeSide * 0.8, topY);
    ghutraPath.quadraticBezierTo(headCenter.dx, topY - headR * 0.2, headCenter.dx + drapeSide * 0.8, topY);
    ghutraPath.lineTo(headCenter.dx + drapeSide, headCenter.dy - headR * 0.3);
    ghutraPath.lineTo(headCenter.dx + drapeSide * 0.9, headCenter.dy + headR * 0.5);
    ghutraPath.lineTo(headCenter.dx - drapeSide * 0.9, headCenter.dy + headR * 0.5);
    ghutraPath.close();

    canvas.drawPath(ghutraPath, Paint()..color = color);

    final agalY = headCenter.dy - headR * 0.55;
    final agalPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(headCenter.dx - headR * 0.7, agalY),
      Offset(headCenter.dx + headR * 0.7, agalY),
      agalPaint,
    );
    canvas.drawLine(
      Offset(headCenter.dx - headR * 0.65, agalY + 4),
      Offset(headCenter.dx + headR * 0.65, agalY + 4),
      agalPaint..strokeWidth = 2.0,
    );

    if (color.red > 150 && color.green < 100) {
      final checkPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      for (double dy = topY; dy < headCenter.dy + headR * 0.5; dy += 6) {
        canvas.drawLine(
          Offset(headCenter.dx - drapeSide * 0.7, dy),
          Offset(headCenter.dx + drapeSide * 0.7, dy),
          checkPaint,
        );
      }
    }
  }

  static void _drawHair(Canvas canvas, Offset headCenter, double headR, Color color) {
    final hairPath = Path();
    final topY = headCenter.dy - headR * 0.9;
    final hairW = headR * 0.85;

    hairPath.addArc(
      Rect.fromCenter(center: Offset(headCenter.dx, topY + headR * 0.3), width: hairW * 2, height: headR * 1.2),
      math.pi,
      math.pi,
    );

    canvas.drawPath(hairPath, Paint()..color = color);
  }
}
