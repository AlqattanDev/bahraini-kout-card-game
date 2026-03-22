import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../app/models/client_game_state.dart';
import '../shared/models/game_state.dart';
import 'components/ambient_decoration.dart';
import 'components/card_component.dart';
import 'components/hand_component.dart';
import 'components/player_seat.dart';
import 'components/score_display.dart';
import 'components/table_background.dart';
import 'components/trick_area.dart';
import 'managers/layout_manager.dart';
import 'managers/animation_manager.dart';

class KoutGame extends FlameGame {
  final Stream<ClientGameState> stateStream;
  final void Function(String action, Map<String, dynamic> data) onAction;

  StreamSubscription<ClientGameState>? _stateSub;
  ClientGameState? currentState;
  late LayoutManager layout;

  // Managed components
  HandComponent? _hand;
  TrickAreaComponent? _trickArea;
  ScoreDisplayComponent? _scoreDisplay;
  AmbientDecorationComponent? _ambientDecoration;
  final List<PlayerSeatComponent> _seats = [];

  // Animation manager
  late AnimationManager _animationManager;

  // Track previous trick count to detect new trick plays
  int _prevTrickPlayCount = 0;

  KoutGame({required this.stateStream, required this.onAction});

  @override
  Future<void> onLoad() async {
    // Use a safe fallback size when the canvas is not yet available (e.g. in tests).
    final safeSize = hasLayout ? size : Vector2(375, 812);
    layout = LayoutManager(safeSize);
    _animationManager = AnimationManager(game: this);

    // Wood grain table background — rendered first (behind everything else)
    add(TableBackgroundComponent());
    _stateSub = stateStream.listen((state) {
      currentState = state;
      _onStateUpdate(state);
    });
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    layout = LayoutManager(newSize);
    _scoreDisplay?.updateWidth(newSize.x);
  }

  // ---------------------------------------------------------------------------
  // State update — wires all components and overlays to [ClientGameState]
  // ---------------------------------------------------------------------------

  void _onStateUpdate(ClientGameState state) {
    _updateScoreDisplay(state);
    _updateSeats(state);
    _updateHand(state);
    _updateTrickArea(state);
    _updateOverlays(state);
  }

  void _updateScoreDisplay(ClientGameState state) {
    if (_scoreDisplay == null) {
      final w = hasLayout ? size.x : 375.0;
      _scoreDisplay = ScoreDisplayComponent(screenWidth: w);
      add(_scoreDisplay!);
    }
    _scoreDisplay!.updateState(state);
  }

  void _updateSeats(ClientGameState state) {
    // Create seat components on first call; update thereafter
    if (_seats.isEmpty) {
      for (int i = 0; i < 4; i++) {
        final pos = layout.seatPosition(i, state.mySeatIndex);
        final seat = PlayerSeatComponent(
          playerName: _shortUid(state.playerUids[i]),
          cardCount: 0,
          isActive: false,
          isTeamA: i.isEven,
          isDealer: state.playerUids[i] == state.dealerUid,
          position: pos,
        );
        _seats.add(seat);
        add(seat);
      }

      // Ambient decoration layer (tea glass silhouettes + geometric overlay)
      // Added after seats so we have their positions
      _ambientDecoration = AmbientDecorationComponent(
        seatPositions: [
          for (int i = 0; i < 4; i++)
            layout.seatPosition(i, state.mySeatIndex),
        ],
      );
      add(_ambientDecoration!);
    }

    for (int i = 0; i < state.playerUids.length && i < _seats.length; i++) {
      final uid = state.playerUids[i];
      _seats[i].updateState(
        name: _shortUid(uid),
        cards: i == state.mySeatIndex ? state.myHand.length : 8,
        active: state.currentPlayerUid == uid,
        teamA: i.isEven,
        dealer: uid == state.dealerUid,
      );
      _seats[i].position = layout.seatPosition(i, state.mySeatIndex);
    }
  }

  void _updateHand(ClientGameState state) {
    if (_hand == null) {
      _hand = HandComponent(
        layout: layout,
        onCardTap: (code) => onAction('playCard', {'card': code}),
      );
      add(_hand!);
    }
    _hand!.updateState(state);
  }

  void _updateTrickArea(ClientGameState state) {
    if (_trickArea == null) {
      _trickArea = TrickAreaComponent(
        layout: layout,
        mySeatIndex: state.mySeatIndex,
      );
      add(_trickArea!);
    }

    final newCount = state.currentTrickPlays.length;

    // Animate newly played card if count increased
    if (newCount > _prevTrickPlayCount && newCount > 0) {
      final lastPlay = state.currentTrickPlays.last;
      final absoluteSeat = state.playerUids.indexOf(lastPlay.playerUid);
      if (absoluteSeat >= 0) {
        final target = layout.trickCardPosition(
          layout.toRelativeSeat(absoluteSeat, state.mySeatIndex),
        );
        final tempCard = CardComponent(
          card: lastPlay.card,
          isFaceUp: true,
          position: layout.seatPosition(absoluteSeat, state.mySeatIndex),
          anchor: Anchor.center,
        );
        add(tempCard);
        _animationManager.animateCardPlay(tempCard, target).then((_) {
          tempCard.removeFromParent();
          _trickArea!.updateState(state);
        });
      } else {
        _trickArea!.updateState(state);
      }
    } else {
      _trickArea!.updateState(state);
    }

    _prevTrickPlayCount = newCount;
  }

  // ---------------------------------------------------------------------------
  // Overlay management
  // ---------------------------------------------------------------------------

  void _updateOverlays(ClientGameState state) {
    const allOverlays = ['bid', 'trump', 'roundResult', 'gameOver'];

    // Determine which single overlay (if any) should be shown
    String? targetOverlay;

    switch (state.phase) {
      case GamePhase.bidding:
        if (state.isMyTurn) targetOverlay = 'bid';
        break;
      case GamePhase.trumpSelection:
        if (state.bidderUid == state.myUid) targetOverlay = 'trump';
        break;
      case GamePhase.roundScoring:
        targetOverlay = 'roundResult';
        break;
      case GamePhase.gameOver:
        targetOverlay = 'gameOver';
        break;
      default:
        break;
    }

    // Remove overlays that should not be shown
    for (final key in allOverlays) {
      if (key != targetOverlay && overlays.isActive(key)) {
        overlays.remove(key);
      }
    }

    // Show the target overlay if not already visible
    if (targetOverlay != null && !overlays.isActive(targetOverlay)) {
      overlays.add(targetOverlay);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _shortUid(String uid) {
    if (uid.length <= 6) return uid;
    return uid.substring(0, 6);
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    super.onRemove();
  }
}
