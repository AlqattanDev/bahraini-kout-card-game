import 'dart:ui';

/// Shared text rendering utility for all Flame canvas components.
///
/// Eliminates duplicated ParagraphBuilder boilerplate across components.
/// All game text uses IBMPlexMono bold by default (matches KoutTheme convention).
class TextRenderer {
  TextRenderer._();

  /// Renders [text] at [offset] on [canvas].
  ///
  /// [align] controls horizontal alignment within [width].
  /// When [align] is [TextAlign.center], [offset] is treated as the
  /// center point and shifted left by half [width].
  static void draw(
    Canvas canvas,
    String text,
    Color color,
    Offset offset,
    double fontSize, {
    TextAlign align = TextAlign.center,
    double width = 80.0,
    String fontFamily = 'IBMPlexMono',
    FontWeight fontWeight = FontWeight.bold,
  }) {
    final builder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: align,
        fontSize: fontSize,
        fontFamily: fontFamily,
      ),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: fontWeight))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: width));

    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx = offset.dx - width / 2;
    }
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
  }

  /// Convenience: renders centered text where [center] is the visual midpoint.
  ///
  /// Vertically offsets by half the font size for approximate centering.
  static void drawCentered(
    Canvas canvas,
    String text,
    Color color,
    Offset center,
    double fontSize, {
    double width = 80.0,
    String fontFamily = 'IBMPlexMono',
    FontWeight fontWeight = FontWeight.bold,
  }) {
    draw(
      canvas,
      text,
      color,
      Offset(center.dx, center.dy - fontSize / 2),
      fontSize,
      align: TextAlign.center,
      width: width,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
    );
  }
}
