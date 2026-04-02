import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/avatar_painter.dart';

void main() {
  group('AvatarTraits.fromSeed', () {
    test('same seed always produces identical traits', () {
      final a = AvatarTraits.fromSeed(42);
      final b = AvatarTraits.fromSeed(42);
      expect(a.skinTone, equals(b.skinTone));
      expect(a.hasGhutra, equals(b.hasGhutra));
      expect(a.eyeStyle, equals(b.eyeStyle));
      expect(a.mouthStyle, equals(b.mouthStyle));
      expect(a.hasSunglasses, equals(b.hasSunglasses));
      expect(a.hasBeard, equals(b.hasBeard));
      expect(a.ghutraColor, equals(b.ghutraColor));
    });

    test('all 4 player seats get visually distinct avatars', () {
      final traits = List.generate(4, AvatarTraits.fromSeed);
      // At minimum, skin tones should not all be identical
      final skinTones = traits.map((t) => t.skinTone).toSet();
      expect(skinTones.length, greaterThan(1));
      // At least one should have a ghutra and at least one shouldn't
      expect(traits.any((t) => t.hasGhutra), isTrue);
      expect(traits.any((t) => !t.hasGhutra), isTrue);
    });

    test('seed wraps around for values > preset count', () {
      // Seeds beyond the preset count should still produce valid traits
      final t100 = AvatarTraits.fromSeed(100);
      final tWrapped = AvatarTraits.fromSeed(100 % 4);
      expect(t100.skinTone, equals(tWrapped.skinTone));
      expect(t100.hasGhutra, equals(tWrapped.hasGhutra));
    });

    test('all presets have fully opaque skin tones', () {
      for (int i = 0; i < 4; i++) {
        final traits = AvatarTraits.fromSeed(i);
        expect(traits.skinTone.a, 1.0,
            reason: 'Preset $i skin tone should be fully opaque');
      }
    });

    test('ghutra wearers also have a valid ghutra color', () {
      for (int i = 0; i < 4; i++) {
        final traits = AvatarTraits.fromSeed(i);
        if (traits.hasGhutra) {
          expect(traits.ghutraColor.a, 1.0,
              reason: 'Preset $i ghutra color should be fully opaque');
        }
      }
    });

    test('sunglasses preset has sunglasses and no beard', () {
      // Preset 3 is the sunglasses archetype
      final t = AvatarTraits.fromSeed(3);
      expect(t.hasSunglasses, isTrue);
      // Sunglasses + beard would be visually crowded
      expect(t.hasBeard, isFalse);
    });
  });
}
