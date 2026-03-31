# Offline Single-Player Mode — Design Spec

**Date:** 2026-03-23
**Status:** Draft
**Depends on:** [Bahraini Kout Game Design](2026-03-22-bahraini-kout-game-design.md)

## Overview

Add a shippable offline single-player mode where 1 human player plays with 3 AI bots (4-player mode only). The game loop runs entirely client-side using the existing `shared/logic/` Dart modules — no network required. The Flame rendering layer requires minimal changes: `KoutGame.onAction` is replaced with a `GameInputSink` interface, and it continues to subscribe to a `Stream<ClientGameState>` regardless of whether the source is a WebSocket (online) or the local game controller (offline).

**Note:** Pass-and-play (multiple humans on one device) is out of scope for this iteration. The architecture supports it (via multiple `HumanPlayerController` instances and seat-filtered streams), but the UI flow and hand-secrecy transitions are deferred to a future spec.

## Goals

- True offline play with no server dependency
- Rule-based bot AI that plays sound Kout strategy
- Zero changes to the existing Flame rendering layer
- Reuse `shared/logic/` validators, resolvers, and scorer — no duplicated rules
- Enable fast programmatic testing via headless bot-vs-bot game simulation

## Non-Goals (Future Scope)

- 6-player variant support
- Tiered difficulty (Easy/Medium/Hard)
- Bot personality/playstyle variation
- Online + bot hybrid (filling disconnected seats with bots)
- Pass-and-play (multiple humans on one device) — architecture supports it but UI deferred

---

## Architecture

### New Components

```
lib/
├── offline/
│   ├── local_game_controller.dart    # Client-side game engine
│   ├── full_game_state.dart          # Server-equivalent state (all hands visible)
│   ├── player_controller.dart        # Abstract interface
│   ├── human_player_controller.dart  # Completer-based, resolves on UI input
│   ├── bot_player_controller.dart    # Heuristic AI engine
│   ├── bot/
│   │   ├── hand_evaluator.dart       # Hand strength scoring
│   │   ├── bid_strategy.dart         # Bid/pass decision logic
│   │   ├── trump_strategy.dart       # Trump suit selection
│   │   └── play_strategy.dart        # Card play heuristics
│   └── game_input_sink.dart          # Abstract input interface
├── app/
│   ├── models/
│   │   ├── game_mode.dart            # GameMode sealed class
│   │   └── seat_config.dart          # Per-seat configuration
│   ├── screens/
│   │   └── offline_lobby_screen.dart # Seat assignment UI
│   └── services/
│       └── game_service.dart         # (modified) implements GameInputSink
```

### Data Flow

```
┌─────────────────────────────────────────────────────┐
│                  OfflineGameScreen                    │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │          LocalGameController                  │   │
│  │                                               │   │
│  │  FullGameState (all 4 hands, scores, phase)  │   │
│  │          │                                    │   │
│  │          ▼                                    │   │
│  │  ┌─────────────────────┐                     │   │
│  │  │   State Machine     │                     │   │
│  │  │ DEAL→BID→TRUMP→PLAY │                     │   │
│  │  │     →SCORE→...      │                     │   │
│  │  └────────┬────────────┘                     │   │
│  │           │                                   │   │
│  │     ┌─────┴──────┐                           │   │
│  │     ▼            ▼                            │   │
│  │  Seat 0       Seats 1-3                      │   │
│  │  (Human)      (Bot/Human)                    │   │
│  │     │            │                            │   │
│  │     ▼            ▼                            │   │
│  │  HumanPlayer  BotPlayer                      │   │
│  │  Controller   Controller                     │   │
│  └──────┬───────────┬───────────────────────────┘   │
│         │           │                                │
│         ▼           │ (internal)                     │
│  Stream<ClientGameState>                             │
│         │                                            │
│         ▼                                            │
│     KoutGame (Flame) ◄── identical to online mode    │
└─────────────────────────────────────────────────────┘
```

### Comparison: Online vs Offline

| Concern               | Online                          | Offline                          |
|------------------------|---------------------------------|----------------------------------|
| Game loop              | GameRoom Durable Object (TS)    | LocalGameController (Dart)       |
| State authority        | Server                          | LocalGameController              |
| Player input           | WebSocket message               | PlayerController.decideAction()  |
| State delivery         | WebSocket → Stream              | Controller → Stream              |
| Rendering              | KoutGame subscribes to stream   | KoutGame subscribes to stream    |
| Input sink             | GameService                     | HumanPlayerController            |
| Network required       | Yes                             | No                               |

---

## FullGameState

The local equivalent of the server's game document. Holds everything needed to run the game loop.

```dart
class FullGameState {
  GamePhase phase;
  List<SeatConfig> players;              // uid, displayName, isBot, seatIndex
  Map<int, List<GameCard>> hands;        // seat index → cards (all 4 visible)
  Map<Team, int> scores;
  Map<Team, int> trickCounts;
  List<({int seat, GameCard card})> currentTrickPlays;
  int dealerSeat;
  int currentSeat;
  BidAmount? bid;
  int? bidderSeat;
  Suit? trumpSuit;
  int consecutivePasses;
  int reshuffleCount;                    // 0 or 1 (Malzoom allows one reshuffle)
  int trickNumber;                       // 1–8 within a round
}
```

## LocalGameController

Orchestrates the game loop. Pure Dart, no Flame dependency.

### Public API

```dart
class LocalGameController {
  LocalGameController({
    required List<SeatConfig> seats,
    required Map<int, PlayerController> controllers,
  });

  /// Stream of client-visible state for the primary human seat.
  Stream<ClientGameState> get stateStream;

  /// Start the game loop. Runs asynchronously until GAME_OVER.
  Future<void> start();

  /// Dispose streams and resources.
  void dispose();
}
```

### State Machine Loop

```
loop per round:
  1. DEALING
     - Shuffle 32-card deck (31 standard + 1 Joker)
     - Deal 8 cards to each seat
     - Emit state (phase: DEALING)

  2. BIDDING
     - Start with seat after dealer, cycle clockwise
     - For each seat:
       - Call controller.decideAction(clientState) → BidAction | PassAction
       - Validate via bid_validator.dart
       - Track consecutive passes
     - End conditions:
       - 3 consecutive passes → bidder found
       - All 4 pass → increment reshuffleCount
         - reshuffleCount was 0 → reshuffle same 32-card deck, re-deal fresh hands, restart DEALING then BIDDING
         - reshuffleCount was 1 → Malzoom: dealer forced to bid 5, skip to TRUMP_SELECTION

  3. TRUMP_SELECTION
     - Call bidder's controller.decideAction(clientState) → TrumpAction
     - Set trumpSuit

  4. PLAYING (8 tricks)
     - First trick: seat after bidder leads
     - Per trick, cycle 4 seats starting with leader:
       - **Poison Joker check (before asking for action):** if player's hand is exactly [Joker], trigger instant loss (+10 penalty to opponent), skip to ROUND_SCORING
       - Call controller.decideAction(clientState) → PlayCardAction
       - Validate via play_validator.dart
     - Resolve trick winner via trick_resolver.dart
     - Winner leads next trick

  5. ROUND_SCORING
     - Compute result via scorer.dart
     - Update scores (tug-of-war: winner gains, loser unchanged, clamp to 0)
     - If any team >= 31 → GAME_OVER
     - Else rotate dealer clockwise, reset round state, next round
```

### ClientGameState Generation

`FullGameState` is internal to `LocalGameController` — it is never exposed. After each state mutation, the controller converts it to `ClientGameState` for the human seat and for each bot seat (bots consume theirs internally to make decisions).

```dart
ClientGameState _toClientState(FullGameState full, int forSeat) {
  return ClientGameState(
    phase: full.phase,
    playerUids: full.players.map((p) => p.uid).toList(),
    scores: full.scores,
    tricks: full.trickCounts,
    currentPlayerUid: full.players[full.currentSeat].uid,
    dealerUid: full.players[full.dealerSeat].uid,
    trumpSuit: full.trumpSuit,
    currentBid: full.bid,
    bidderUid: full.bidderSeat != null ? full.players[full.bidderSeat!].uid : null,
    currentTrickPlays: full.currentTrickPlays.map(
      (p) => (playerUid: full.players[p.seat].uid, card: p.card),
    ).toList(),
    myHand: full.hands[forSeat]!,  // Only this seat's cards
    myUid: full.players[forSeat].uid,
  );
}
```

The human seat's `ClientGameState` is pushed to `stateStream` (consumed by `KoutGame`). Bot seats receive theirs as arguments to `decideAction()`.

---

## PlayerController

### Abstract Interface

```dart
abstract class PlayerController {
  Future<GameAction> decideAction(ClientGameState state, ActionContext context);
}

sealed class GameAction {}
class BidAction extends GameAction { final BidAmount amount; }
class PassAction extends GameAction {}
class TrumpAction extends GameAction { final Suit suit; }
class PlayCardAction extends GameAction { final GameCard card; }

/// Context telling the controller what type of action is expected.
sealed class ActionContext {}
class BidContext extends ActionContext { final BidAmount? currentHighBid; }
class TrumpContext extends ActionContext {}
class PlayContext extends ActionContext { final Suit? ledSuit; }
```

### HumanPlayerController

```dart
class HumanPlayerController implements PlayerController, GameInputSink {
  Completer<GameAction>? _pending;

  @override
  Future<GameAction> decideAction(ClientGameState state, ActionContext context) {
    _pending = Completer<GameAction>();
    return _pending!.future;
  }

  // GameInputSink implementation — called by UI
  @override
  void playCard(GameCard card) => _pending?.complete(PlayCardAction(card));

  @override
  void placeBid(BidAmount amount) => _pending?.complete(BidAction(amount));

  @override
  void pass() => _pending?.complete(PassAction());

  @override
  void selectTrump(Suit suit) => _pending?.complete(TrumpAction(suit));
}
```

### GameInputSink

```dart
abstract class GameInputSink {
  void playCard(GameCard card);
  void placeBid(BidAmount amount);
  void pass();
  void selectTrump(Suit suit);
}
```

Both `GameService` (online) and `HumanPlayerController` (offline) implement this. `KoutGame` holds a `GameInputSink` — agnostic to which mode is active.

---

## BotPlayerController

Orchestrates the bot strategy modules based on the `ActionContext` it receives.

```dart
class BotPlayerController implements PlayerController {
  @override
  Future<GameAction> decideAction(ClientGameState state, ActionContext context) async {
    return switch (context) {
      BidContext(:final currentHighBid) =>
        BidStrategy.decideBid(state.myHand, currentHighBid),
      TrumpContext() =>
        TrumpAction(TrumpStrategy.selectTrump(state.myHand)),
      PlayContext(:final ledSuit) =>
        PlayStrategy.selectCard(
          hand: state.myHand,
          trickPlays: state.currentTrickPlays,
          trumpSuit: state.trumpSuit,
          ledSuit: ledSuit,
          mySeat: _seatIndex,
        ),
    };
  }
}
```

---

## Bot AI — Heuristic Engine

All bot logic lives in `lib/offline/bot/`. Each strategy module is a pure function: state in, decision out. No side effects.

### Hand Evaluator (`hand_evaluator.dart`)

Scores a hand's trick-taking strength on a 0–8 scale.

**Scoring rules:**
- Joker: +1.0 (guaranteed winner)
- Ace: +0.9
- King in a suit with 3+ cards: +0.7 (protected king)
- King in a suit with 1-2 cards: +0.4 (vulnerable)
- Queen in a suit with 4+ cards: +0.4
- Trump cards (after trump is known): +0.3 bonus each for non-honor trump
- Long suit (4+ cards): +0.3 bonus for suit control
- Void suit: +0.2 bonus (trumping opportunity)

**Output:** `HandStrength` with `expectedWinners` (double) and `strongestSuit` (Suit).

### Bid Strategy (`bid_strategy.dart`)

```dart
GameAction decideBid(List<GameCard> hand, BidAmount? currentHighBid) {
  final strength = evaluateHand(hand);
  final maxBid = _strengthToBid(strength.expectedWinners);
  // maxBid: 4.5+ → bid 5, 5.5+ → bid 6, 6.5+ → bid 7, 7.5+ → bid 8
  if (currentHighBid == null && maxBid >= BidAmount.five) return BidAction(BidAmount.five);
  if (currentHighBid != null && maxBid > currentHighBid) return BidAction(maxBid);
  return PassAction();
}
```

Partner contribution is assumed at ~1.5 tricks and baked into the threshold values.

### Trump Strategy (`trump_strategy.dart`)

```dart
Suit selectTrump(List<GameCard> hand) {
  // Pick suit with most cards; break ties by highest card strength.
  // If holding Joker, slightly prefer a suit with length but weaker
  // individual cards (trump promotes them).
}
```

### Play Strategy (`play_strategy.dart`)

Priority-based card selection. Inputs: bot's hand, current trick plays, trump suit, led suit, bot's seat index (to identify partner at `(mySeat + 2) % 4`).

**When leading a trick:**
1. If bidding team and hold trump: lead highest trump to flush opponent trump (first 1-2 tricks only)
2. Lead from longest non-trump suit, highest card, to establish control
3. Never lead Joker (illegal)
4. If only Joker remains: Poison Joker — this state should not occur with correct earlier play, but the controller handles it

**When following suit:**
1. Can follow suit and can win → play lowest winning card
2. Can follow suit and cannot win → play lowest card in suit
3. Void in led suit and have trump → play lowest trump that beats current best (if opponent winning)
4. Void in led suit, partner winning → dump lowest card from weakest suit
5. Void and no trump → dump lowest card from weakest suit

**Joker play:**
- Play Joker to win a critical trick: when opponents are about to win and trick count is contested
- Prioritize playing Joker before it becomes the last card (Poison Joker prevention)
- Heuristic: if holding Joker with ≤2 other cards, play Joker next opportunity

**Partner awareness:**
- If partner's card is currently winning the trick, do not overtake — dump low
- If partner bid, support their led suit by playing high to help establish it

---

## GameMode & Screen Integration

### GameMode

```dart
sealed class GameMode {}

class OnlineGameMode extends GameMode {
  final String roomId;
  OnlineGameMode({required this.roomId});
}

class OfflineGameMode extends GameMode {
  final List<SeatConfig> seats;
  OfflineGameMode({required this.seats});
}
```

### SeatConfig

```dart
class SeatConfig {
  final int seatIndex;
  final String uid;            // Generated locally for bots: "bot_0", "bot_1", etc.
  final String displayName;    // "You", "Bot Khalid", "Bot Fatima", "Player 2"
  final bool isBot;
}
```

### GameScreen Wiring

```dart
// In GameScreen.build():
switch (widget.gameMode) {
  case OnlineGameMode(:final roomId):
    final gameService = GameService(roomId: roomId);
    return KoutGame(
      stateStream: gameService.stateStream,
      inputSink: gameService,
    );

  case OfflineGameMode(:final seats):
    final humanController = HumanPlayerController();
    final controllers = <int, PlayerController>{};
    for (final seat in seats) {
      controllers[seat.seatIndex] = seat.isBot
          ? BotPlayerController()
          : humanController;
    }
    final localController = LocalGameController(
      seats: seats,
      controllers: controllers,
    );
    localController.start();
    return KoutGame(
      stateStream: localController.stateStream,
      inputSink: humanController,
    );
}
```

### Required Modifications to Existing Code

**`KoutGame`:** Replace `void Function(String action, Map<String, dynamic> data) onAction` with `GameInputSink inputSink`. Currently `HandComponent` calls `onAction('playCard', {'card': code})` — this changes to `inputSink.playCard(GameCard.decode(code))`. The `stateStream` parameter stays identical.

```dart
// Before:
KoutGame({required this.stateStream, required this.onAction});

// After:
KoutGame({required this.stateStream, required this.inputSink});
```

**`GameService`:** Implement `GameInputSink` interface. Map each `GameInputSink` method to the existing WebSocket send:

```dart
class GameService implements GameInputSink {
  @override
  void playCard(GameCard card) => _send('playCard', {'card': card.encode()});

  @override
  void placeBid(BidAmount amount) => _send('placeBid', {'amount': amount.value});

  @override
  void pass() => _send('pass', {});

  @override
  void selectTrump(Suit suit) => _send('selectTrump', {'suit': suit.name});
}
```

**`HandComponent`:** Change card tap handler:

```dart
// Before:
onCardTap: (code) => onAction('playCard', {'card': code})

// After:
onCardTap: (code) => inputSink.playCard(GameCard.decode(code))
```

**`BidOverlay`:** Accept `GameInputSink` instead of raw callbacks. Route bids through `inputSink.placeBid()` and passes through `inputSink.pass()`.

**`TrumpSelectorOverlay`:** Accept `GameInputSink`. Route trump selection through `inputSink.selectTrump()`.

**`GameScreen`:** Add `GameMode gameMode` parameter. Switch on mode to wire either `GameService` (online) or `LocalGameController` + `HumanPlayerController` (offline). See "GameScreen Wiring" section above.

**`HomeScreen`:** Add "Play Offline" button navigating to `OfflineLobbyScreen`.

No changes to: `CardComponent`, `TrickAreaComponent`, `ScoreDisplayComponent`, `PlayerSeatComponent`, `AnimationManager`, `LayoutManager`, `RoundResultOverlay`, `GameOverOverlay`, theme, `shared/logic/*`.

---

## Offline Lobby Screen

### Layout

Top-down Diwaniya table view (reuse `TableBackgroundComponent` aesthetic) with 4 seat positions arranged in the standard seating:

```
        Seat 2 (top)
         Partner

Seat 1              Seat 3
(left)              (right)
Opponent            Opponent

        Seat 0 (bottom)
          You
```

### Seat Interaction

- **Seat 0 (bottom):** Always the human player. Shows "You" label. Not toggleable.
- **Seats 1–3:** All bots for this iteration. Show flavor names: "Bot Khalid" (seat 1), "Bot Fatima" (seat 2), "Bot Ahmed" (seat 3). Not toggleable in v1, but the UI is built to support future toggling.
- Team labels visible: "Team A" for seats 0 & 2, "Team B" for seats 1 & 3.

### Start Button

Bottom of screen. Creates `OfflineGameMode` with the fixed `List<SeatConfig>` (1 human + 3 bots) and navigates to `GameScreen`.

---

## Bot Turn Timing

Bot actions are instant by default. A configurable delay can be enabled via a settings toggle (stored in shared preferences):

```dart
// In BotPlayerController
@override
Future<GameAction> decideAction(ClientGameState state, ActionContext context) async {
  final action = _computeAction(state, context); // Synchronous heuristic
  // No delay — instant by default
  return action;
}
```

Delay, if added later, would be a simple `await Future.delayed(duration)` before returning. Not implemented at launch.

---

## Testing Strategy

### Unit Tests — Bot Heuristics

**`test/offline/bot/hand_evaluator_test.dart`:**
- Strong hand (3 aces + Joker) → expectedWinners ≥ 4.0
- Weak hand (all 7s and 8s, no Joker) → expectedWinners < 3.0
- Void suit detection

**`test/offline/bot/bid_strategy_test.dart`:**
- Strong hand → bids appropriately
- Weak hand → passes
- Respects current high bid (won't underbid)
- Kout threshold only on very strong hands

**`test/offline/bot/trump_strategy_test.dart`:**
- Picks longest suit
- Breaks ties by card strength
- Joker influence on selection

**`test/offline/bot/play_strategy_test.dart`:**
- Follows suit when holding suit cards
- Trumps in when void in led suit
- Doesn't overtake partner
- Dumps lowest when can't win
- Plays Joker before it becomes last card
- Leading: flushes trump when appropriate

### Integration Tests — LocalGameController

**`test/offline/local_game_controller_test.dart`:**
- Full game simulation (4 bots) → reaches GAME_OVER with valid scores
- Scores never go below 0
- Kout bid → instant win/loss (score = 31)
- Malzoom trigger: 4 weak-hand bots, verify reshuffle then forced bid
- Poison Joker: engineered hand, verify instant loss penalty
- Dealer rotates each round
- ClientGameState stream emits correct phases in order
- Human seat's ClientGameState only contains that seat's hand

### Integration Test — Stream Swap

**`test/offline/stream_integration_test.dart`:**
- Create LocalGameController with 3 bots + 1 HumanPlayerController
- Feed scripted actions into HumanPlayerController
- Assert ClientGameState stream matches expected game progression

### Headless Game Runner (Dev Tool)

**`tool/headless_game_runner.dart`:**
- CLI-invocable: `dart run tool/headless_game_runner.dart --games=1000`
- Runs N full bot-vs-bot games
- Reports: average game length (rounds), bid distribution, win rate per starting position, any rule violations (assertions)
- Useful for tuning heuristic thresholds and catching edge cases at scale

---

## File Inventory

### New Files

| File | Purpose |
|------|---------|
| `lib/offline/local_game_controller.dart` | Client-side game engine, state machine |
| `lib/offline/full_game_state.dart` | Full game state (all hands) |
| `lib/offline/player_controller.dart` | Abstract interface + GameAction types |
| `lib/offline/human_player_controller.dart` | Completer-based human input |
| `lib/offline/bot_player_controller.dart` | Orchestrates bot strategies |
| `lib/offline/bot/hand_evaluator.dart` | Hand strength scoring |
| `lib/offline/bot/bid_strategy.dart` | Bid/pass heuristics |
| `lib/offline/bot/trump_strategy.dart` | Trump suit selection |
| `lib/offline/bot/play_strategy.dart` | Card play heuristics |
| `lib/offline/game_input_sink.dart` | Abstract input interface |
| `lib/app/models/game_mode.dart` | GameMode sealed class |
| `lib/app/models/seat_config.dart` | Seat configuration model |
| `lib/app/screens/offline_lobby_screen.dart` | Seat assignment UI |
| `test/offline/bot/hand_evaluator_test.dart` | Hand evaluator tests |
| `test/offline/bot/bid_strategy_test.dart` | Bid strategy tests |
| `test/offline/bot/trump_strategy_test.dart` | Trump strategy tests |
| `test/offline/bot/play_strategy_test.dart` | Play strategy tests |
| `test/offline/local_game_controller_test.dart` | Game loop integration tests |
| `test/offline/stream_integration_test.dart` | Stream swap verification |
| `tool/headless_game_runner.dart` | Bulk bot-vs-bot simulation |

### Modified Files

| File | Change |
|------|--------|
| `lib/game/kout_game.dart` | Accept `GameInputSink` parameter |
| `lib/game/components/hand_component.dart` | Route taps through `GameInputSink` |
| `lib/game/overlays/bid_overlay.dart` | Route bids through `GameInputSink` |
| `lib/game/overlays/trump_selector.dart` | Route trump selection through `GameInputSink` |
| `lib/app/services/game_service.dart` | Implement `GameInputSink` interface |
| `lib/app/screens/game_screen.dart` | Handle `GameMode` switch |
| `lib/app/screens/home_screen.dart` | Add "Play Offline" button |
