import 'dart:ui';
import 'package:flutter/painting.dart';

/// Procedural texture generators for the Diwaniya table theme.
class TextureGenerator {
  /// Creates a warm wood-grain radial gradient paint for the table background.
  static Paint woodGrainPaint(Rect bounds) {
    return Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Color(0xFF4A2A1A),
          Color(0xFF3B2314),
          Color(0xFF2A1808),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds);
  }
}
