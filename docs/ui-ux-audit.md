# UI/UX Audit Report

## Critical (breaks usability)
- `lib/app/screens/home_screen.dart:40`: `const Duration(seconds: 3)` timeout on anonymous sign-in might be too short for slow network conditions, failing authentication silently and leaving user in unexpected state.

## High (feels broken/amateur) 
- `lib/app/screens/matchmaking_screen.dart:184`: Spinner rotation speed (`2 * math.pi` every 3s) is linear, lacks easing, and may feel jerky.
- `lib/game/components/player_seat.dart:450`: `_TrickWinFlashComponent` radius hardcoded to `1.5 * p1`. Doesn't adapt to component size.

## Medium (feels unpolished)
- `lib/app/screens/room_lobby_screen.dart:137`: Fixed width `220` for seat containers and action buttons. Won't adapt well to smaller screens or different text lengths.
- `lib/app/screens/offline_lobby_screen.dart:60`: Fixed width `300` and height `300` for table background stack. May overflow on very small devices.
- `lib/app/screens/home_screen.dart:58`: Button transitions lack easing curves, appearing linear and abrupt.
- `lib/game/components/unified_hud.dart:14`: Hardcoded `_hudWidth = 155.0` which might cause overflow on narrower devices.
- `lib/game/overlays/round_result_overlay.dart:14`: Hardcoded layout values `padding: const EdgeInsets.all(24)` which may overflow.
- `lib/game/managers/animation_manager.dart:95`: Shadow offset hardcoded logic `math.min(totalDistance * 0.12, 14.0)`, missing dynamic scaling based on resolution.

## Low (minor polish)
- `lib/app/screens/room_lobby_screen.dart:82`: Snackbars are lacking proper elevation and styling using theme constants. The color is hardcoded to `0xFF5C1A1B`.
- `lib/game/components/card_component.dart`: Hover and tap effects return to `restScale`, but lack a subtle color tint for interaction feedback.
- `lib/game/components/trick_area.dart:67`: Card flip animation missing, cards appear face up instantly when added to the trick area.
- `lib/game/components/player_seat.dart`: Glow animation uses `0.30` to `0.80` opacity hardcoded values instead of referencing a theme standard for consistency.

## Nice-to-have (future enhancements)
- Add distinct haptic feedback patterns for different types of interactions (e.g., error vs success).
- Implement a comprehensive layout system to replace hardcoded values with responsive constraints across all screens and components.
- Enhance animations with physics-based springs instead of simple easing curves for a more organic feel.
- Introduce skeleton loaders for data fetching states instead of generic circular progress indicators.
