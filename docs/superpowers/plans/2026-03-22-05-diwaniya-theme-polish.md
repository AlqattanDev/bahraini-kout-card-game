# Diwaniya Theme & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the Diwaniya aesthetic — wood grain table texture, Islamic geometric card backs, Arabic typography, ambient decorations, and visual polish to transform the functional game into an immersive Bahraini card table experience.

**Architecture:** Asset pipeline (generated textures/sprites) + themed component updates. No new game logic — purely visual layer on top of Plan 4's Flame components.

**Tech Stack:** Flutter/Flame, custom `Paint` rendering, Google Fonts (Arabic-friendly), Flame `SpriteComponent`, procedural texture generation

**Spec:** `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md` (UI/UX section)

**Depends on:** Plan 4 (Flame components to theme)

---

## File Structure

```
lib/
  game/
    theme/
      kout_theme.dart             # Already exists — extend with text styles
      textures.dart               # Procedural texture generators
      card_painter.dart           # Custom card face/back painters
      geometric_patterns.dart     # Islamic geometric pattern generator
    components/
      table_background.dart       # Wood grain table surface
      ambient_decoration.dart     # Tea glass, coffee cup decorations

assets/
  fonts/
    (Arabic-friendly font files or use Google Fonts package)
  images/
    (Generated sprite sheets if needed)
```

---

### Task 1: Table Background (Wood Grain)

**Files:**
- Create: `lib/game/theme/textures.dart`
- Create: `lib/game/components/table_background.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Implement procedural wood grain texture**

```dart
// lib/game/theme/textures.dart
import 'dart:math';
import 'dart:ui';

class TextureGenerator {
  /// Generates a wood grain texture as a Paint shader.
  static Paint woodGrainPaint(Rect bounds) {
    // Dark walnut base with radial gradient toward center
    return Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          const Color(0xFF4A2A1A), // lighter center
          const Color(0xFF3B2314), // walnut
          const Color(0xFF2A1808), // dark edges
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds);
  }
}
```

- [ ] **Step 2: Implement table background component**

Renders the wood grain as a full-screen background with subtle geometric pattern overlay at low opacity.

- [ ] **Step 3: Add to KoutGame as first child**
- [ ] **Step 4: Commit**

```bash
git add lib/game/theme/textures.dart lib/game/components/table_background.dart lib/game/kout_game.dart
git commit -m "feat: add wood grain table background with radial gradient"
```

---

### Task 2: Islamic Geometric Card Back

**Files:**
- Create: `lib/game/theme/geometric_patterns.dart`
- Create: `lib/game/theme/card_painter.dart`
- Modify: `lib/game/components/card_component.dart`

- [ ] **Step 1: Implement geometric pattern generator**

Draws a repeating 8-point star tessellation (common Islamic geometric pattern) in burgundy and gold. Uses `Canvas.drawPath` with rotational symmetry.

- [ ] **Step 2: Implement card painter**

```dart
// lib/game/theme/card_painter.dart
import 'dart:ui';
import 'kout_theme.dart';
import 'geometric_patterns.dart';

class CardPainter {
  /// Paints a card back with Islamic geometric pattern.
  static void paintBack(Canvas canvas, Rect rect) {
    // White border
    final borderPaint = Paint()..color = KoutTheme.cardBorder;
    final borderRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(borderRRect, borderPaint);

    // Inner area with burgundy fill
    final innerRect = rect.deflate(3);
    final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(4));
    canvas.drawRRect(innerRRect, Paint()..color = KoutTheme.cardBack);

    // Geometric pattern overlay
    canvas.save();
    canvas.clipRRect(innerRRect);
    GeometricPatterns.drawEightPointStarTessellation(
      canvas, innerRect,
      primaryColor: KoutTheme.primary,
      accentColor: KoutTheme.accent.withOpacity(0.3),
    );
    canvas.restore();

    // Gold border line
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(5)),
      Paint()
        ..color = KoutTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Paints a card face with rank and suit.
  static void paintFace(Canvas canvas, Rect rect, String rankStr, String suitSymbol, Color suitColor) {
    // White face
    final faceRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(faceRRect, Paint()..color = KoutTheme.cardFace);

    // Border
    canvas.drawRRect(
      faceRRect,
      Paint()
        ..color = const Color(0xFFCCCCCC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Rank and suit text (top-left and bottom-right)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Top-left rank
    textPainter.text = TextSpan(
      text: '$rankStr\n$suitSymbol',
      style: TextStyle(color: suitColor, fontSize: 12, fontWeight: FontWeight.bold, height: 1.1),
    );
    textPainter.layout();
    textPainter.paint(canvas, rect.topLeft + const Offset(5, 4));

    // Center suit symbol (large)
    textPainter.text = TextSpan(
      text: suitSymbol,
      style: TextStyle(color: suitColor, fontSize: 32),
    );
    textPainter.layout();
    textPainter.paint(canvas, rect.center - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}
```

- [ ] **Step 3: Update card_component.dart to use CardPainter**
- [ ] **Step 4: Commit**

```bash
git add lib/game/theme/ lib/game/components/card_component.dart
git commit -m "feat: add Islamic geometric card back and themed card face rendering"
```

---

### Task 3: Arabic Typography & Bilingual Support

**Files:**
- Modify: `pubspec.yaml` (add google_fonts)
- Modify: `lib/game/theme/kout_theme.dart`
- Modify: `lib/game/components/score_display.dart`
- Modify: `lib/game/overlays/bid_overlay.dart`

- [ ] **Step 1: Add Google Fonts dependency**

```yaml
dependencies:
  google_fonts: ^6.0.0
```

- [ ] **Step 2: Extend KoutTheme with text styles**

```dart
// Add to kout_theme.dart
import 'package:google_fonts/google_fonts.dart';

static TextStyle get headingStyle => GoogleFonts.ibmPlexMono(
  color: textColor,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

static TextStyle get bodyStyle => GoogleFonts.ibmPlexMono(
  color: textColor,
  fontSize: 14,
);

static TextStyle get arabicHeadingStyle => GoogleFonts.notoKufiArabic(
  color: textColor,
  fontSize: 22,
  fontWeight: FontWeight.bold,
);

static TextStyle get arabicBodyStyle => GoogleFonts.notoKufiArabic(
  color: textColor,
  fontSize: 14,
);
```

- [ ] **Step 3: Add bilingual labels**

Create a simple localization map for game terms:
- "Bab" / "باب"
- "Kout" / "كوت"
- "Malzoom" / "ملزوم"
- "Pass" / "باس"
- "Trump" / "حكم"
- "Your turn" / "دورك"

- [ ] **Step 4: Update overlays and score display with bilingual text**
- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/game/theme/ lib/game/components/ lib/game/overlays/
git commit -m "feat: add Arabic typography with bilingual labels for game terms"
```

---

### Task 4: Player Seat Polish (Gold Rope, Glow)

**Files:**
- Modify: `lib/game/components/player_seat.dart`

- [ ] **Step 1: Add gold rope border to avatar frame**

Draw concentric circles with gold color and dashed stroke to simulate rope texture.

- [ ] **Step 2: Add active player glow pulse**

Use Flame's `OpacityEffect` with `InfiniteEffectController` to pulse a gold glow circle behind the active player's avatar.

- [ ] **Step 3: Add team color indicator**

Small colored dot (gold for Team A, copper for Team B) below the avatar.

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/player_seat.dart
git commit -m "feat: polish player seats with gold rope border, glow pulse, and team indicator"
```

---

### Task 5: Ambient Decorations

**Files:**
- Create: `lib/game/components/ambient_decoration.dart`
- Modify: `lib/game/kout_game.dart`

- [ ] **Step 1: Implement ambient decorations**

Small, subtle decorative elements near each player seat: a tea glass (istikana) silhouette rendered with simple shapes. Very low opacity, purely cosmetic. Positioned by LayoutManager.

- [ ] **Step 2: Add geometric pattern overlay on background**

Faint repeating geometric pattern drawn at 5% opacity over the wood grain table. Uses the same `GeometricPatterns` generator from Task 2.

- [ ] **Step 3: Add to KoutGame**
- [ ] **Step 4: Commit**

```bash
git add lib/game/components/ambient_decoration.dart lib/game/kout_game.dart
git commit -m "feat: add ambient diwaniya decorations — tea glass silhouettes and geometric overlay"
```

---

### Task 6: Animation Polish

**Files:**
- Modify: `lib/game/managers/animation_manager.dart`

- [ ] **Step 1: Add card shadow during movement**

Cards gain a drop shadow offset during `MoveEffect` that scales with distance from table. Creates depth illusion.

- [ ] **Step 2: Add dealing sound placeholder**

Add `AudioPool` setup (actual audio files added later). For now, just the hook points in the animation sequence.

- [ ] **Step 3: Add trick win celebration**

Brief gold particle burst at the trick winner's position when they collect cards.

- [ ] **Step 4: Commit**

```bash
git add lib/game/managers/animation_manager.dart
git commit -m "feat: polish animations — card shadows, dealing sequence, trick win particles"
```

---

### Task 7: Visual Verification

- [ ] **Step 1: Run app and screenshot each phase**

Manually verify on emulator/device:
- Home screen theming
- Matchmaking waiting screen
- Table background renders correctly
- Card backs show geometric pattern
- Card faces readable
- Hand fan layout correct
- Player seats have gold borders and glow
- Bid overlay styled correctly
- Trump selector styled correctly
- Score display readable
- Arabic text renders correctly

- [ ] **Step 2: Fix any visual issues found**
- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All PASS

- [ ] **Step 4: Commit any fixes**

```bash
git add .
git commit -m "fix: visual polish adjustments from manual verification"
```

---

## Summary

7 tasks. Produces:
- Wood grain table background with radial gradient
- Islamic geometric card back pattern
- Themed card faces with suit colors
- Arabic typography (Noto Kufi Arabic) with bilingual game labels
- Gold rope player seat borders with active glow
- Ambient diwaniya decorations (tea glass silhouettes, geometric overlay)
- Polished animations with shadows and particles
- IBM Plex Mono for Latin text, brutalist high-contrast aesthetic
