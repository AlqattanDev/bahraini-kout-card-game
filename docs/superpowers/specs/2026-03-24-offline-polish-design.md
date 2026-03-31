# Offline Mode Polish — Design Spec

**Date:** 2026-03-24
**Scope:** Full polish pass for offline single-player mode
**Approach:** Incremental bottom-up (foundations → animations → sound → overlay content → screens)

---

## Decisions

- **Scope:** Full polish pass — all screens, overlays, components, animations, sound
- **Sound vibe:** Clean/digital — crisp taps, gentle chimes, modern mobile game feel
- **Home screen:** Minimal themed — apply KoutTheme colors/fonts to existing layout, no structural changes
- **Game over celebration:** Satisfying but contained — headline scale-in, gold glow pulse, enlarged particle burst, clean sound cue. No confetti.
- **Round result focus:** Score-focused — emphasize score delta, running total, progress bar toward 31
- **Overlay transitions:** Scale + fade — overlays scale from 0.8→1.0 and fade 0→1 opacity, snappy modern feel
- **Game over actions:** Both "Play Again" (instant restart) and "Back to Lobby" buttons

---

## 1. Sound System

### Package
`audioplayers` — mature, good platform support (iOS/Android/macOS/web).

### New class: `SoundManager`
Location: `lib/game/managers/sound_manager.dart`

Preloads all sound clips on game init. Exposes methods matching `AnimationManager` hook names. `KoutGame` wires both managers to the same game events.

### Sound Map

| Event | Method | Sound Description |
|-------|--------|-------------------|
| Card play | `playCardSound()` | Crisp tap/click |
| Deal start | `playDealSound()` | Quick shuffle riffle |
| Trick win | `playTrickWinSound()` | Short bright chime |
| Trick collect | `playTrickCollectSound()` | Soft whoosh/sweep |
| Round win | `playRoundWinSound()` | Ascending two-note chime |
| Round loss | `playRoundLossSound()` | Descending two-note tone |
| Game victory | `playVictorySound()` | Triumphant short fanfare |
| Game defeat | `playDefeatSound()` | Low muted tone |
| Poison joker | `playPoisonJokerSound()` | Warning buzzer |
| Bid placed | `playBidSound()` | Subtle click/confirm |
| Trump selected | `playTrumpSound()` | Subtle confirm |

### Sound Assets
Directory: `assets/sounds/`
Format: `.wav` or `.ogg`, 10-50KB each.

Sound sourcing is a separate task. Implementation starts with programmatically generated placeholder tones (using `audioplayers`' `BytesSource` with simple sine wave buffers). Real sound assets are swapped in later without code changes — just drop files in `assets/sounds/` matching the expected filenames:
`card_play.wav`, `deal.wav`, `trick_win.wav`, `trick_collect.wav`, `round_win.wav`, `round_loss.wav`, `victory.wav`, `defeat.wav`, `poison_joker.wav`, `bid.wav`, `trump.wav`

### Integration
- `KoutGame` creates `SoundManager` alongside `AnimationManager`
- Game event handlers call both managers
- `SoundManager` has a `muted` toggle (persisted in SharedPreferences)
- Mute button: small speaker icon in top-right corner of the game screen (above the Flame game widget), toggles `SoundManager.muted`
- `SoundManager.dispose()` must be called from `KoutGame.onRemove()` to release `AudioPlayer` instances

---

## 2. Overlay Animation System

### New mixin or utility: `OverlayAnimationMixin`
Shared animation logic for all overlay widgets. Applied to overlay StatefulWidgets.

### Entry Animation
- Duration: 250ms
- Curve: `Curves.easeOutBack`
- Scale: 0.8 → 1.0
- Opacity: 0.0 → 1.0
- Background scrim fades in simultaneously (black at 40% opacity)

### Exit Animation
- Duration: 150ms
- Curve: `Curves.easeIn`
- Scale: 1.0 → 0.9
- Opacity: 1.0 → 0.0

### Exit Animation Mechanism
Flame overlays are removed via `game.overlays.remove()` which instantly removes the widget. To support exit animations, overlay widgets will use an internal `_dismissing` state:
1. Instead of calling `game.overlays.remove()` directly, callers invoke a `dismiss()` method on the overlay (via a callback or key).
2. `dismiss()` sets `_dismissing = true` and starts the reverse animation.
3. On animation completion, the overlay calls `game.overlays.remove()` to actually remove itself.
4. For overlays removed by game logic (not user action), `KoutGame` calls the dismiss callback and waits for completion before proceeding.

### Application
All 4 overlays get this treatment:
- `BidOverlay` — scale+fade in when it's human's turn to bid
- `TrumpSelectorOverlay` — scale+fade in when human selects trump
- `RoundResultOverlay` — scale+fade in after round ends
- `GameOverOverlay` — scale+fade in after game ends, with additional celebration effects

---

## 3. Home Screen Theming

### Changes to `HomeScreen`
Minimal theme application — no layout restructuring:

- **Background:** `KoutTheme.table` solid color (or subtle radial gradient dark brown → darker brown, matching table)
- **Title "Bahraini Kout":** `KoutTheme.textColor` (cream), IBM Plex Mono font, larger size. Add Arabic subtitle "كوت البحريني" in Noto Kufi Arabic below.
- **Buttons:** Burgundy (`KoutTheme.primary`) fill with gold (`KoutTheme.accent`) text/border. Rounded corners.
- **Loading spinner:** Gold (`KoutTheme.accent`) colored instead of default blue
- **Font bundling:** Ensure IBM Plex Mono and Noto Kufi Arabic font files are bundled in `assets/fonts/` and declared in `pubspec.yaml` so they work offline (not relying on `google_fonts` runtime download).

No geometric patterns, no animations, no structural changes.

---

## 4. Offline Lobby Screen Polish

### Changes to `OfflineLobbyScreen`
Light polish pass:

- **Background:** Match home screen (dark brown)
- **Table preview:** Increase size slightly, add geometric pattern overlay at 8% opacity
- **Seat circles:** Add subtle gold glow on human player's seat
- **Start Game button:** Match home screen button style (burgundy + gold)
- **Typography:** Apply KoutTheme fonts and colors throughout

---

## 5. Round Result Overlay Enhancement

### Layout Redesign
Replace current simple text layout with score-focused design:

```
┌──────────────────────────────────┐
│                                  │
│     "Round Won!" / "Round Lost"  │  ← Scale+fade animated headline
│     (green/gold or red)          │
│                                  │
│  ┌────────────────────────────┐  │
│  │ Your Team: 5 tricks        │  │  ← Trick count
│  │ Opponent:  3 tricks        │  │
│  │ Bid: 5 (Bab) ✓ Made it    │  │  ← Bid result
│  └────────────────────────────┘  │
│                                  │
│  Score Change: +5                │  ← Animated count-up
│                                  │
│  ┌──── Progress to 31 ───────┐  │
│  │ Team A: ████████░░░░ 18   │  │  ← Gold progress bar
│  │ Team B: █████░░░░░░░ 12   │  │  ← Brown progress bar
│  └────────────────────────────┘  │
│                                  │
│        [ Continue ]              │  ← Gold button
│                                  │
└──────────────────────────────────┘
```

### Previous Score Data
The round result overlay needs both previous and current scores to animate the delta and progress bars. `KoutGame` will snapshot the current scores (from the last `ClientGameState`) before the `roundScoring` phase and pass `previousScoreA` / `previousScoreB` as parameters when building the overlay. This avoids changing `ClientGameState` — the snapshot is local to `KoutGame`.

### Animations
- Headline: scale+fade entry (shared overlay animation)
- Score delta: count-up animation from 0 to value (300ms)
- Progress bars: animate width from previous score to new score (400ms, easeOut)
- Sound: round win chime or round loss tone on entry

---

## 6. Game Over Overlay Enhancement

### Layout

```
┌──────────────────────────────────┐
│                                  │
│        ✦ "Victory!" ✦           │  ← Scale-in + gold glow pulse
│    or  "Defeat"                  │  ← Fade-in, muted
│                                  │
│  ┌────────────────────────────┐  │
│  │ Final Scores               │  │
│  │ Team A: 31                 │  │
│  │ Team B: 18                 │  │
│  └────────────────────────────┘  │
│                                  │
│     [ Play Again ]               │  ← Restarts with same setup
│     [ Back to Lobby ]            │  ← Returns to OfflineLobbyScreen
│                                  │
└──────────────────────────────────┘
```

### Victory Celebration
- Headline scales in with `easeOutBack` (slight overshoot), then pulses glow (gold shadow oscillation, repeating)
- Gold particle burst — same system as trick-win particles but 2x count (24 particles), larger radius
- Victory fanfare sound on entry
- Particle burst fires 200ms after headline appears

### Defeat
- Headline fades in normally, red/muted color
- No particles, no pulse
- Defeat sound on entry

### Buttons
- "Play Again": gold filled, prominent
- "Back to Lobby": bordered/outlined, secondary

### Play Again Behavior
- `GameOverOverlay` receives two callbacks: `onPlayAgain` and `onReturnToMenu` (currently only has `onReturnToMenu`).
- `GameScreen` stores the `OfflineGameMode` (seat configs) as state so it can be reused.
- `onPlayAgain` handler in `GameScreen`: calls `Navigator.pushReplacementNamed(context, '/game', arguments: originalGameMode)`. This creates a fresh `GameScreen` instance which initializes a new `LocalGameController` with the same seats.
- `onReturnToMenu` handler: unchanged, navigates to `/`.

---

## 7. Component Polish

### Score Display (`ScoreDisplayComponent`)
- Animate score text on change: brief scale pulse (1.0 → 1.3 → 1.0, 200ms) with gold flash
- Add small progress indicator (thin 3px bar under each team's score showing progress to 31). Panel height increases from 44px to 52px to accommodate. `LayoutManager` hand/seat positions shift down accordingly.

### Hand Component (`HandComponent`)
- Touch-down effect (mobile): when finger contacts a playable card, it scales up 1.15x and lifts (y - 8px). On finger release without completing a tap, it springs back. This uses Flame's `TapCallbacks` — distinguish `onTapDown` (lift preview) from `onTapUp` (play card).
- Pointer hover effect (desktop/web): same lift effect on mouse hover via Flame's `HoverCallbacks` mixin on `CardComponent`. Only applied when `kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux`.
- The existing `onTap` callback that plays the card fires on `onTapUp`, after the lift preview.

### Bid Overlay (`BidOverlay`)
- Add scale+fade entry animation
- Button press: brief scale-down (0.95) on tap, then action fires
- Play bid sound on selection

### Trump Selector (`TrumpSelectorOverlay`)
- Add scale+fade entry animation
- Button press animation same as bid
- Play trump sound on selection

### Player Seat (`PlayerSeatComponent`)
- Make active player glow more pronounced (increase glow radius and opacity)
- Brief flash when a player wins a trick

---

## 8. File Changes Summary

### New Files
- `lib/game/managers/sound_manager.dart` — Sound loading and playback
- `assets/sounds/*.wav` — 11 sound effect files

### Modified Files
- `pubspec.yaml` — Add `audioplayers` dependency, declare `assets/sounds/`
- `lib/game/kout_game.dart` — Create and wire `SoundManager`, trigger sounds on events
- `lib/app/screens/home_screen.dart` — Apply KoutTheme colors/fonts
- `lib/app/screens/offline_lobby_screen.dart` — Light theme polish
- `lib/game/overlays/bid_overlay.dart` — Scale+fade animation, button press feedback, sound
- `lib/game/overlays/trump_selector.dart` — Scale+fade animation, button press feedback, sound
- `lib/game/overlays/round_result_overlay.dart` — Redesign with progress bars, animations, sound
- `lib/game/overlays/game_over_overlay.dart` — Celebration effects, Play Again button, sound
- `lib/game/components/score_display.dart` — Score change animation, progress indicators
- `lib/game/components/hand_component.dart` — Hover/touch card lift effect
- `lib/game/components/player_seat.dart` — Enhanced glow, trick-win flash
- `lib/app/screens/game_screen.dart` — Pass Play Again callback, wire sound mute toggle

### Unchanged
- Card rendering, table background, ambient decorations, geometric patterns, textures, layout manager — already well-polished, no changes needed.

---

## 9. Dependencies

### New
- `audioplayers: ^6.0.0` — Cross-platform audio playback

### Existing (unchanged)
- `flame` — Game engine
- `flutter` — Framework
