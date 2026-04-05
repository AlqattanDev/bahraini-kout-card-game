import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import '../app/models/client_game_state.dart';
import '../app/services/game_service.dart';
import '../shared/models/game_state.dart';
import 'components/ambient_decoration.dart';
import 'components/card_component.dart';
import 'components/hand_component.dart';
import 'components/opponent_hand_fan.dart';
import 'components/perspective_table.dart';
import '../offline/game_input_sink.dart';
import '../shared/models/card.dart';
import '../shared/models/trick.dart';
import '../shared/logic/trick_resolver.dart';
import 'components/opponent_name_label.dart';
import 'components/player_seat.dart';
import 'theme/kout_theme.dart';
import 'components/unified_hud.dart';
import 'components/table_background.dart';
import 'components/trick_area.dart';
import 'managers/layout_manager.dart';
import 'managers/animation_manager.dart';
import 'managers/sound_manager.dart';
import '../shared/constants/timing.dart';

class KoutGame extends FlameGame {
  final Stream<ClientGameState> stateStream;
  final GameInputSink inputSink;

  StreamSubscription<ClientGameState>? _stateSub;
  ClientGameState? currentState;
  late LayoutManager layout;

  // Managed components
  HandComponent? _hand;
  TrickAreaComponent? _trickArea;
  AmbientDecorationComponent? _ambientDecoration;
  final List<PlayerSeatComponent> _seats = [];
  final Map<int, OpponentHandFan> _opponentFans = {};
  final Map<int, OpponentNameLabel> _opponentLabels = {};
  OpponentNameLabel? _playerLabel;
  PerspectiveTableComponent? _perspectiveTable;
  UnifiedHudComponent? _unifiedHud;
  Stopwatch? _gameTimer;
  double _hudTickAccum = 0.0;

  // Animation manager
  late AnimationManager _animationManager;

  // Sound manager
  SoundManager? soundManager;

  // Track previous trick play count to detect new card plays
  int _prevTrickPlayCount = 0;

  bool _isLandscape = false;

  // Track previous phase to detect transitions (e.g. poison joker roundScoring)
  GamePhase? _prevPhase;

  // Previous scores for round result overlay (snapshot before round scoring)
  int previousScoreA = 0;
  int previousScoreB = 0;
  int _lastScoreA = 0;
  int _lastScoreB = 0;

  // Connection status for online games
  ConnectionStatus connectionStatus = ConnectionStatus.connected;
  int reconnectAttempt = 0;
  final Stream<ConnectionStatus>? _connectionStream;
  StreamSubscription<ConnectionStatus>? _connectionSub;

  // Turn timer tracking
  String? _lastCurrentPlayer;
  GamePhase? _lastTimerPhase;
  double _turnElapsed = 0.0;
  static final double _humanTimeout =
      GameTiming.humanTurnTimeout.inMilliseconds / 1000.0;
  static const double _botTimeout = 4.0; // average of 3-5s

  /// Safe area insets from the Flutter widget layer.
  EdgeInsets _safeArea = EdgeInsets.zero;

  void updateSafeArea(EdgeInsets insets) {
    _safeArea = insets;
    // Re-create layout with new insets
    if (hasLayout) {
      layout = LayoutManager(size, safeArea: _safeArea);
      _unifiedHud?.updateWidth(size.x);
      _perspectiveTable?.updateLayout(layout);
      _hand?.layout = layout;
      _trickArea?.layout = layout;
      if (layout.isLandscape) {
        _unifiedHud?.updateLayout(size.x, rightInset: _safeArea.right, topInset: _safeArea.top);
      }
    }
  }

  KoutGame({
    required this.stateStream,
    required this.inputSink,
    Stream<ConnectionStatus>? connectionStream,
  }) : _connectionStream = connectionStream;

  /// Whether the human player is forced to bid (last player, no existing bid).
  bool get isHumanForced {
    final state = currentState;
    if (state == null) return false;
    if (state.phase != GamePhase.bidding) return false;
    if (!state.isMyTurn) return false;
    final othersPassed = state.passedPlayers.length >= 3;
    final noBidYet = state.currentBid == null;
    return othersPassed && noBidYet;
  }

  @override
  Future<void> onLoad() async {
    // Use a safe fallback size when the canvas is not yet available (e.g. in tests).
    final safeSize = hasLayout ? size : Vector2(375, 812);
    layout = LayoutManager(safeSize, safeArea: _safeArea);
    _animationManager = AnimationManager(game: this);
    soundManager = SoundManager();
    await soundManager!.init();

    // Wood grain table background — rendered first (behind everything else)
    add(TableBackgroundComponent());

    // 3D perspective table surface (portrait only)
    _perspectiveTable = PerspectiveTableComponent(layout: layout);
    if (!layout.isLandscape) add(_perspectiveTable!);

    _stateSub = stateStream.listen((state) {
      currentState = state;
      _onStateUpdate(state);
    });

    // Listen for connection status changes (online games only)
    _connectionSub = _connectionStream?.listen((status) {
      connectionStatus = status;
      if (status == ConnectionStatus.reconnecting) {
        reconnectAttempt++;
      } else if (status == ConnectionStatus.connected) {
        reconnectAttempt = 0;
      }
      _updateConnectionOverlay(status);
    });
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    layout = LayoutManager(size, safeArea: _safeArea);
    _unifiedHud?.updateWidth(size.x);
    _perspectiveTable?.updateLayout(layout);
    _hand?.layout = layout;
    _trickArea?.layout = layout;
    if (layout.isLandscape) {
      _unifiedHud?.updateLayout(size.x, rightInset: _safeArea.right, topInset: _safeArea.top);
    }
    // Sync landscape flag with new layout (handles macOS window resize)
    if (currentState != null) _updateLandscapeVisibility();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Tick turn timer for active player's ring
    final state = currentState;
    if (state == null) return;

    final isActionPhase = state.phase == GamePhase.bidding ||
        state.phase == GamePhase.trumpSelection ||
        state.phase == GamePhase.playing;

    if (isActionPhase && state.currentPlayerUid != null) {
      // Reset timer when active player or phase changes
      if (state.currentPlayerUid != _lastCurrentPlayer ||
          state.phase != _lastTimerPhase) {
        _lastCurrentPlayer = state.currentPlayerUid;
        _lastTimerPhase = state.phase;
        _turnElapsed = 0.0;
      }
      _turnElapsed += dt;

      // Update the active seat's timer ring
      final isHuman = state.currentPlayerUid == state.myUid;
      final timeout = isHuman ? _humanTimeout : _botTimeout;
      final progress = (1.0 - (_turnElapsed / timeout)).clamp(0.0, 1.0);

      for (int i = 0; i < _seats.length; i++) {
        final uid = state.playerUids[i];
        if (uid == state.currentPlayerUid) {
          _seats[i].timerProgress = progress;
        } else {
          _seats[i].timerProgress = 0.0;
        }
      }
    } else {
      _lastCurrentPlayer = null;
      for (final seat in _seats) {
        seat.timerProgress = 0.0;
      }
    }

    // Tick game timer on HUD every second
    if (_gameTimer != null && _unifiedHud != null) {
      _hudTickAccum += dt;
      if (_hudTickAccum >= 1.0) {
        _hudTickAccum = 0.0;
        _unifiedHud!.updateTimer(_gameTimer!.elapsed);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // State update — wires all components and overlays to [ClientGameState]
  // ---------------------------------------------------------------------------

  void _updateLandscapeVisibility() {
    final landscape = layout.isLandscape;
    if (landscape == _isLandscape) return; // no change
    _isLandscape = landscape;

    // Toggle perspective table
    if (_perspectiveTable != null) {
      if (landscape && _perspectiveTable!.isMounted) {
        _perspectiveTable!.removeFromParent();
      } else if (!landscape && !_perspectiveTable!.isMounted) {
        add(_perspectiveTable!);
      }
    }

    // Toggle seats
    for (final seat in _seats) {
      if (landscape && seat.isMounted) {
        seat.removeFromParent();
      } else if (!landscape && !seat.isMounted) {
        add(seat);
      }
    }

    // Toggle ambient decoration
    if (_ambientDecoration != null) {
      if (landscape && _ambientDecoration!.isMounted) {
        _ambientDecoration!.removeFromParent();
      } else if (!landscape && !_ambientDecoration!.isMounted) {
        add(_ambientDecoration!);
      }
    }

    // Toggle opponent fans
    for (final fan in _opponentFans.values) {
      if (landscape && fan.isMounted) {
        fan.removeFromParent();
      } else if (!landscape && !fan.isMounted) {
        add(fan);
      }
    }

    // Update table background
    final tableBg = children.whereType<TableBackgroundComponent>().firstOrNull;
    if (tableBg != null) {
      tableBg.isLandscape = landscape;
    }
  }

  void _onStateUpdate(ClientGameState state) {
    _updateLandscapeVisibility();
    _updateLandscapeLabels(state);
    _updateScoreDisplay(state);
    _updateSeats(state);
    _updateBidderGlow(state);
    _updateHand(state);
    _updateTrickArea(state);
    _updateOverlays(state);
  }

  void _updateLandscapeLabels(ClientGameState state) {
    if (!_isLandscape) {
      // Remove labels in portrait
      for (final label in _opponentLabels.values) {
        if (label.isMounted) label.removeFromParent();
      }
      _opponentLabels.clear();
      if (_playerLabel != null) {
        if (_playerLabel!.isMounted) _playerLabel!.removeFromParent();
        _playerLabel = null;
      }
      return;
    }

    // Create or update labels for opponents in landscape
    for (int i = 0; i < 4; i++) {
      final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
      final pos = layout.seatPosition(i, state.mySeatIndex);

      if (relativeSeat == 0) {
        // Skip self — the user sees their own hand
        continue;
      }

      String? bidAction;
      if (state.phase == GamePhase.bidding || state.phase == GamePhase.trumpSelection) {
        for (final entry in state.bidHistory) {
          if (entry.playerUid == state.playerUids[i]) {
            bidAction = entry.action;
          }
        }
      }

      final showBidderGlow = state.phase != GamePhase.bidding &&
          state.phase != GamePhase.waiting &&
          state.phase != GamePhase.dealing;

      if (_opponentLabels.containsKey(i)) {
        _opponentLabels[i]!.updateState(
          name: _shortUid(state.playerUids[i]),
          teamA: i.isEven,
          active: state.currentPlayerUid == state.playerUids[i],
          cards: state.cardCounts[i] ?? 8,
          bidAction: bidAction,
          isBidder: showBidderGlow && state.playerUids[i] == state.bidderUid,
        );
        _opponentLabels[i]!.position = pos;
      } else {
        final placement = switch (relativeSeat) {
          1 => OpponentLabelPlacement.left,
          2 => OpponentLabelPlacement.top,
          3 => OpponentLabelPlacement.right,
          _ => OpponentLabelPlacement.top,
        };

        final label = OpponentNameLabel(
          playerName: _shortUid(state.playerUids[i]),
          isTeamA: i.isEven,
          bidAction: bidAction,
          isActive: state.currentPlayerUid == state.playerUids[i],
          cardCount: state.cardCounts[i] ?? 8,
          placement: placement,
          position: pos,
        );
        _opponentLabels[i] = label;
        add(label);
      }
    }

    // Player "You" label at bottom-right
    final myPos = layout.mySeat;
    if (_playerLabel == null) {
      _playerLabel = OpponentNameLabel(
        playerName: _shortUid(state.playerUids[state.mySeatIndex]),
        isTeamA: state.mySeatIndex.isEven,
        cardCount: 0,
        placement: OpponentLabelPlacement.right,
        position: myPos,
      );
      add(_playerLabel!);
    } else {
      _playerLabel!.updateState(
        name: _shortUid(state.playerUids[state.mySeatIndex]),
        teamA: state.mySeatIndex.isEven,
        active: state.currentPlayerUid == state.myUid,
        cards: 0,
      );
      _playerLabel!.position = myPos;
    }
  }

  void _updateScoreDisplay(ClientGameState state) {
    _gameTimer ??= Stopwatch()..start();

    if (_unifiedHud == null) {
      final w = hasLayout ? size.x : 375.0;
      _unifiedHud = UnifiedHudComponent(screenWidth: w);
      add(_unifiedHud!);
    }

    final teamAScore = state.scores[Team.a] ?? 0;
    final teamBScore = state.scores[Team.b] ?? 0;
    final roundNumber = (state.trickWinners.length ~/ 8) + 1;

    int? bidValue;
    Team? bidderTeam;
    int bidderTricks = 0;
    int opponentTricks = 0;
    int opponentTarget = 0;

    if (state.bidderUid != null && state.currentBid != null) {
      bidValue = state.currentBid!.value;
      final bidderSeat = state.playerUids.indexOf(state.bidderUid!);
      if (bidderSeat >= 0) {
        bidderTeam = teamForSeat(bidderSeat);
        bidderTricks = state.tricks[bidderTeam] ?? 0;
        opponentTricks = state.tricks[bidderTeam.opponent] ?? 0;
        opponentTarget = 9 - bidValue;
      }
    }

    _unifiedHud!.updateState(
      phase: state.phase,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      roundNumber: roundNumber,
      bidValue: bidValue,
      bidderTeam: bidderTeam,
      trumpSuit: state.trumpSuit,
      bidderTricks: bidderTricks,
      opponentTricks: opponentTricks,
      opponentTarget: opponentTarget,
    );

    _unifiedHud!.updateTimer(_gameTimer!.elapsed);

    // Track scores for round result overlay
    if (state.phase != GamePhase.roundScoring) {
      _lastScoreA = state.scores[Team.a] ?? 0;
      _lastScoreB = state.scores[Team.b] ?? 0;
    }
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
          avatarSeed: i,
          position: pos,
        );
        _seats.add(seat);
        if (!_isLandscape) add(seat);
      }

      // Ambient decoration layer (tea glass silhouettes + geometric overlay)
      // Added after seats so we have their positions
      _ambientDecoration = AmbientDecorationComponent(
        seatPositions: [
          for (int i = 0; i < 4; i++)
            layout.seatPosition(i, state.mySeatIndex),
        ],
      );
      if (!_isLandscape) add(_ambientDecoration!);

      // Create opponent card-back fans for non-player seats.
      // Each fan is a horizontal arc in local space, rotated via baseRotation
      // to point from the seat toward the table center.
      // Offset fans far enough from seat circles to avoid overlap.
      // Seat circle visual radius ~48px (36 + glow); fan extends ~99px
      // from its anchor, so 70px clears the circle edge comfortably.
      const fanOffset = 70.0;
      for (int i = 0; i < 4; i++) {
        if (i == state.mySeatIndex) continue;
        final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
        final seatPos = layout.seatPosition(i, state.mySeatIndex);

        final double rotation;
        final Vector2 offset;
        switch (relativeSeat) {
          case 1: // left opponent — fan rotated 90° CW, extends rightward
            rotation = math.pi / 2;
            offset = Vector2(fanOffset, -10);
          case 2: // top partner — fan rotated 180°, extends downward
            rotation = math.pi;
            offset = Vector2(0, fanOffset);
          case 3: // right opponent — fan rotated 90° CCW, extends leftward
            rotation = -math.pi / 2;
            offset = Vector2(-fanOffset, -10);
          default:
            continue;
        }

        final fan = OpponentHandFan(
          cardCount: 8,
          position: seatPos + offset,
          baseRotation: rotation,
        );
        _opponentFans[i] = fan;
        if (!_isLandscape) add(fan);
      }
    }

    for (int i = 0; i < state.playerUids.length && i < _seats.length; i++) {
      final uid = state.playerUids[i];

      // Find this player's bid action from history
      String? bidAction;
      if (state.phase == GamePhase.bidding || state.phase == GamePhase.trumpSelection) {
        for (final entry in state.bidHistory) {
          if (entry.playerUid == uid) {
            bidAction = entry.action;
          }
        }
      }

      _seats[i].updateState(
        name: _shortUid(uid),
        cards: state.cardCounts[i] ?? (i == state.mySeatIndex ? state.myHand.length : 8),
        active: state.currentPlayerUid == uid,
        teamA: i.isEven,
        bidAction: bidAction,
      );
      _seats[i].position = layout.seatPosition(i, state.mySeatIndex);

      // Update opponent fan card counts
      if (_opponentFans.containsKey(i)) {
        _opponentFans[i]!.updateCardCount(state.cardCounts[i] ?? 8);
      }
    }
  }

  void _updateBidderGlow(ClientGameState state) {
    final showGlow = state.phase != GamePhase.bidding &&
        state.phase != GamePhase.waiting &&
        state.phase != GamePhase.dealing;

    for (int i = 0; i < _seats.length; i++) {
      final uid = state.playerUids[i];
      if (showGlow && uid == state.bidderUid) {
        final teamColor = i.isEven ? KoutTheme.teamAColor : KoutTheme.teamBColor;
        _seats[i].setBidderGlow(true, teamColor);
      } else {
        _seats[i].setBidderGlow(false, null);
      }
    }
  }

  void _updateHand(ClientGameState state) {
    if (_hand == null) {
      _hand = HandComponent(
        layout: layout,
        onCardTap: (code) => inputSink.playCard(GameCard.decode(code)),
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

    // Trick complete: all 4 cards played → trick win sound + flash winning seat
    if (newCount == 4 && _prevTrickPlayCount < 4) {
      soundManager?.playTrickWinSound();
      _flashTrickWinnerSeat(state);
    }

    // Trick collected: trick cleared after being full → trick collect sound
    if (newCount == 0 && _prevTrickPlayCount > 0) {
      soundManager?.playTrickCollectSound();
    }

    // Animate newly played card if count increased
    if (newCount > _prevTrickPlayCount && newCount > 0) {
      final lastPlay = state.currentTrickPlays.last;
      final absoluteSeat = state.playerUids.indexOf(lastPlay.playerUid);
      if (absoluteSeat >= 0) {
        final relativeSeat = layout.toRelativeSeat(absoluteSeat, state.mySeatIndex);
        final target = layout.trickCardPosition(relativeSeat);

        // For the human player (relative seat 0), start from the card's
        // actual position in the hand fan — not the generic seat center.
        // Check previousCardPositions first (card was removed before rebuild).
        Vector2 origin;
        final bool isFromHand = relativeSeat == 0;
        if (isFromHand && _hand != null) {
          final cardCode = lastPlay.card.encode();
          origin = _hand!.previousCardPositions[cardCode] ??
              _hand!.cardPositions[cardCode] ??
              layout.seatPosition(absoluteSeat, state.mySeatIndex);
        } else {
          origin = layout.seatPosition(absoluteSeat, state.mySeatIndex);
        }

        // Match the source scale: hand cards are scaled up, opponent cards are 1.0
        final sourceScale = isFromHand ? (_hand?.handCardScale ?? 1.4) : 1.0;

        final tempCard = CardComponent(
          card: lastPlay.card,
          isFaceUp: true,
          position: origin,
          anchor: Anchor.center,
        )..scale = Vector2.all(sourceScale);
        add(tempCard);
        soundManager?.playCardSound();
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
    // Detect poison joker: transition from playing → roundScoring when the
    // player's sole remaining card is the Joker (never actually played).
    if (state.phase == GamePhase.roundScoring &&
        _prevPhase == GamePhase.playing &&
        state.myHand.length == 1 &&
        state.myHand.first.isJoker) {
      soundManager?.playPoisonJokerSound();
    }
    _prevPhase = state.phase;

    const allOverlays = ['bid', 'trump', 'bidAnnouncement', 'roundResult', 'gameOver'];

    // Determine which single overlay (if any) should be shown
    String? targetOverlay;

    switch (state.phase) {
      case GamePhase.bidding:
        if (state.isMyTurn) targetOverlay = 'bid';
        break;
      case GamePhase.trumpSelection:
        if (state.bidderUid == state.myUid) targetOverlay = 'trump';
        break;
      case GamePhase.bidAnnouncement:
        targetOverlay = 'bidAnnouncement';
        break;
      case GamePhase.roundScoring:
        targetOverlay = 'roundResult';
        break;
      case GamePhase.gameOver:
        if (!overlays.isActive('gameOver')) {
          final myScore = state.scores[state.myTeam] ?? 0;
          final oppScore = state.scores[state.myTeam.opponent] ?? 0;
          if (myScore > oppScore) {
            soundManager?.playVictorySound();
          } else {
            soundManager?.playDefeatSound();
          }
        }
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
      // Snapshot previous scores and play sound when showing round result
      if (targetOverlay == 'roundResult') {
        previousScoreA = _lastScoreA;
        previousScoreB = _lastScoreB;

        // Determine if my team won the round
        final myTeam = state.myTeam;
        final bidderSeat = state.bidderUid != null
            ? state.playerUids.indexOf(state.bidderUid!)
            : -1;
        final bidderTeam = bidderSeat >= 0 ? teamForSeat(bidderSeat) : null;
        final isMyTeamBidder = bidderTeam == myTeam;
        final bidValue = state.currentBid?.value ?? 0;
        final bidderTricks =
            bidderTeam != null ? (state.tricks[bidderTeam] ?? 0) : 0;
        final bidderWon = bidderTricks >= bidValue;
        final myTeamWon = isMyTeamBidder ? bidderWon : !bidderWon;

        if (myTeamWon) {
          soundManager?.playRoundWinSound();
        } else {
          soundManager?.playRoundLossSound();
        }
      }
      overlays.add(targetOverlay);
    }
  }

  // ---------------------------------------------------------------------------
  // Victory particles
  // ---------------------------------------------------------------------------

  /// Spawns a large gold particle burst at the center of the table for victory.
  void spawnVictoryParticles() {
    _animationManager.animateTrickWin(
      layout.trickCenter,
      particleCount: 24,
      durationSeconds: 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves the trick winner from [state] and flashes that player's seat.
  ///
  /// Requires trumpSuit to be set and exactly 4 plays in currentTrickPlays.
  /// Silently skips if either condition is not met.
  void _flashTrickWinnerSeat(ClientGameState state) {
    if (state.trumpSuit == null) return;
    if (state.currentTrickPlays.length != 4) return;

    // Build TrickPlay list using absolute seat indices
    final plays = state.currentTrickPlays.map((p) {
      final absoluteSeat = state.playerUids.indexOf(p.playerUid);
      return TrickPlay(playerIndex: absoluteSeat, card: p.card);
    }).toList();

    // Need the lead player index (first play)
    final leadSeat = state.playerUids.indexOf(
      state.currentTrickPlays.first.playerUid,
    );
    if (plays.any((p) => p.playerIndex < 0) || leadSeat < 0) return;

    final trick = Trick(leadPlayerIndex: leadSeat, plays: plays);
    final winnerAbsoluteSeat = TrickResolver.resolve(
      trick,
      trumpSuit: state.trumpSuit!,
    );

    final relativeSeat = layout.toRelativeSeat(
      winnerAbsoluteSeat,
      state.mySeatIndex,
    );
    if (relativeSeat >= 0 && relativeSeat < _seats.length) {
      _seats[relativeSeat].flashTrickWin();
    }
  }

  String _shortUid(String uid) {
    if (uid.length <= 6) return uid;
    return uid.substring(0, 6);
  }

  void _updateConnectionOverlay(ConnectionStatus status) {
    if (status == ConnectionStatus.connected) {
      if (overlays.isActive('connectionStatus')) {
        overlays.remove('connectionStatus');
      }
    } else {
      if (!overlays.isActive('connectionStatus')) {
        overlays.add('connectionStatus');
      }
    }
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    _connectionSub?.cancel();
    soundManager?.dispose();
    super.onRemove();
  }
}
