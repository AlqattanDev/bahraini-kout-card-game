import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/avatar_painter.dart';

void main() {
  group('AvatarPainter', () {
    test('generates consistent avatar for same seed', () {
      final traits1 = AvatarTraits.fromSeed(42);
      final traits2 = AvatarTraits.fromSeed(42);
      expect(traits1.skinTone, equals(traits2.skinTone));
      expect(traits1.hasGhutra, equals(traits2.hasGhutra));
      expect(traits1.eyeStyle, equals(traits2.eyeStyle));
    });

    test('different seeds produce different traits', () {
      final traits0 = AvatarTraits.fromSeed(0);
      final traits1 = AvatarTraits.fromSeed(1);
      final traits2 = AvatarTraits.fromSeed(2);
      final traits3 = AvatarTraits.fromSeed(3);
      final allSame = traits0.skinTone == traits1.skinTone &&
          traits1.skinTone == traits2.skinTone &&
          traits2.skinTone == traits3.skinTone;
      expect(allSame, isFalse);
    });

    test('all 4 preset traits have valid colors', () {
      for (int i = 0; i < 4; i++) {
        final traits = AvatarTraits.fromSeed(i);
        expect(traits.skinTone.alpha, 1.0);
      }
    });
  });
}
