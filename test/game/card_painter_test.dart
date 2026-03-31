import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/game/theme/card_painter.dart';
import 'package:bahraini_kout/game/theme/kout_theme.dart';

void main() {
  test('paintFace renders without error for pip card', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintFace(canvas, rect, '7', '♠', const Color(0xFF111111));
    recorder.endRecording();
  });

  test('paintFace renders without error for face card', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintFace(canvas, rect, 'K', '♠', const Color(0xFF111111));
    recorder.endRecording();
  });

  test('paintJoker static method exists and renders without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintJoker(canvas, rect);
    recorder.endRecording();
  });

  test('paintBack still renders without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    CardPainter.paintBack(canvas, rect);
    recorder.endRecording();
  });
}
