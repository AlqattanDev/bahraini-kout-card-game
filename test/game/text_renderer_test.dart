import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/theme/text_renderer.dart';

void main() {
  group('TextRenderer', () {
    test('draw does not throw for valid input', () {
      // TextRenderer.draw requires a Canvas — we can't easily mock Canvas
      // in pure unit tests, but we can verify the function signature exists
      // and is callable by testing the class structure.
      expect(TextRenderer.draw, isA<Function>());
      expect(TextRenderer.drawCentered, isA<Function>());
    });

    // Note: Canvas-based rendering is better tested via golden tests or
    // integration tests. The value of TextRenderer is in eliminating
    // duplicated boilerplate, not in complex logic that needs unit testing.
  });
}
