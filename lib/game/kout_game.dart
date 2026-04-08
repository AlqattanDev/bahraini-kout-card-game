import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import '../app/models/client_game_state.dart';
import '../app/services/game_service.dart';
import '../shared/models/game_state.dart';
import 'components/card_component.dart';
import 'components/debug_opponent_hands_overlay.dart';
import 'components/hand_component.dart';
import 'components/perspective_table.dart';
import '../offline/game_input_sink.dart';
import '../shared/models/card.dart';
import '../shared/models/trick.dart';
import '../shared/logic/trick_resolver.dart';
import 'components/unified_hud.dart';
import 'components/trick_area.dart';
import 'managers/layout_manager.dart';
import 'managers/sound_manager.dart';
import 'managers/turn_timer_manager.dart';
import 'managers/overlay_controller.dart';
import 'managers/component_lifecycle_manager.dart';
import 'theme/kout_theme.dart';

class KoutGame extends FlameGame {
  final Stream<ClientGameState> stateStream;
  final GameInputSink inputSink;

  StreamSubscription<ClientGameState>? _stateSub;
  ClientGameState? currentState;
  late LayoutManager layout;

  // Extracted managers — lazy init so they're safe before onLoad()
  late final TurnTimerManager _turnTimer = TurnTimerManager();
  late final OverlayController _overlayController = OverlayController();
  late final ComponentLifecycleManager _lifecycle = ComponentLifecycleManager(game: this);

  // Lazily-created components
  HandComponent? _hand;
  TrickAreaComponent? _trickArea;
  UnifiedHudComponent? _unifiedHud;
  DebugOpponentHandsOverlay? _debugOpponentHands;

  // Sound
  SoundManager? soundManager;

  // Track previous trick play count to detect new card plays
  int _prevTrickPlayCount = 0;
  // Pause after trick completion so player can see all 4 cards
  double _trickPauseTimer = 0.0;
  ClientGameState? _deferredTrickState;

  // Connection status for online games
  ConnectionStatus connectionStatus = ConnectionStatus.connected;
  int reconnectAttempt = 0;
  final Stream<ConnectionStatus>? _connectionStream;
  StreamSubscription<ConnectionStatus>? _connectionSub;

  /// Safe area insets from the Flutter widget layer.
  EdgeInsets _safeArea = EdgeInsets.zero;

  void updateSafeArea(EdgeInsets insets) {
    _safeArea = insets;
    if (hasLayout) {
      layout = LayoutManager(size, safeArea: _safeArea);
      _unifiedHud?.updateWidth(size.x);
      _lifecycle.perspectiveTable?.updateLayout(layout);
      _hand?.layout = layout;
      _trickArea?.layout = layout;
      if (currentState != null && _debugOpponentHands != null) {
        _debugOpponentHands!.updateState(currentState!, layout);
      }
      if (layout.isLandscape) {
        _unifiedHud?.updateLayout(size.x, rightInset: _safeArea.right, topInset: _safeArea.top, landscape: true, leftInset: _safeArea.left);
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

  /// Previous scores for round result overlay (delegated to overlay controller).
  int get previousScoreA => _overlayController.previousScoreA;
  int get previousScoreB => _overlayController.previousScoreB;

  @override
  Future<void> onLoad() async {
    final safeSize = hasLayout ? size : Vector2(375, 812);
    layout = LayoutManager(safeSize, safeArea: _safeArea);
    soundManager = SoundManager();
    await soundManager!.init();

    _lifecycle.perspectiveTable = PerspectiveTableComponent(layout: layout);
    add(_lifecycle.perspectiveTable!);

    _stateSub = stateStream.listen((state) {
      currentState = state;
      _onStateUpdate(state);
    });

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
    _lifecycle.perspectiveTable?.updateLayout(layout);
    _hand?.layout = layout;
    _trickArea?.layout = layout;
    if (currentState != null && _debugOpponentHands != null) {
      _debugOpponentHands!.updateState(currentState!, layout);
    }
    if (layout.isLandscape) {
      _unifiedHud?.updateLayout(size.x, rightInset: _safeArea.right, topInset: _safeArea.top, landscape: true, leftInset: _safeArea.left);
    }
    if (currentState != null) _lifecycle.updateLandscapeVisibility(layout.isLandscape);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _turnTimer.tick(dt, currentState, _lifecycle.seats, hud: _unifiedHud);
    if (_trickPauseTimer > 0) {
      _trickPauseTimer -= dt;
      if (_trickPauseTimer <= 0 && _deferredTrickState != null) {
        _updateTrickArea(_deferredTrickState!);
        _deferredTrickState = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // State update — thin dispatcher
  // ---------------------------------------------------------------------------

  void _onStateUpdate(ClientGameState state) {
    _lifecycle.updateLandscapeVisibility(layout.isLandscape);
    _lifecycle.updateSeats(state, layout);
    _updateScoreDisplay(state);
    _updateHand(state);
    _updateDebugOpponentHands(state);
    if (_trickPauseTimer > 0) {
      _deferredTrickState = state;
    } else {
      _updateTrickArea(state);
    }
    _overlayController.trackScores(state);
    _overlayController.trackTrickSounds(state, soundManager);
    _overlayController.update(
      state,
      delegate: (
        isActive: overlays.isActive,
        add: overlays.add,
        remove: overlays.remove,
      ),
      soundManager: soundManager,
    );
  }

  void _updateScoreDisplay(ClientGameState state) {
    _turnTimer.ensureGameTimer();
    if (_unifiedHud == null) {
      final w = hasLayout ? size.x : 375.0;
      _unifiedHud = UnifiedHudComponent(screenWidth: w);
      add(_unifiedHud!);
    }
    _unifiedHud!.updateState(state);
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

  void _updateDebugOpponentHands(ClientGameState state) {
    if (state.debugAllHands == null) {
      _debugOpponentHands?.removeFromParent();
      _debugOpponentHands = null;
      return;
    }
    _debugOpponentHands ??= DebugOpponentHandsOverlay()..priority = 25;
    if (!_debugOpponentHands!.isMounted) {
      add(_debugOpponentHands!);
    }
    _debugOpponentHands!.updateState(state, layout);
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

    if (newCount == 4 && _prevTrickPlayCount < 4) {
      _flashTrickWinnerSeat(state);
      _trickPauseTimer = 1.0;
    }

    if (newCount == 0 && _prevTrickPlayCount > 0) {
      // Sound handled by overlay controller
    }

    if (newCount > _prevTrickPlayCount && newCount > 0) {
      final lastPlay = state.currentTrickPlays.last;
      final absoluteSeat = state.playerUids.indexOf(lastPlay.playerUid);
      if (absoluteSeat >= 0) {
        final relativeSeat = layout.toRelativeSeat(absoluteSeat, state.mySeatIndex);
        final target = layout.trickCardPosition(relativeSeat);

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

        final sourceScale = isFromHand ? (_hand?.handCardScale ?? 1.4) : 1.0;

        final tempCard = CardComponent(
          card: lastPlay.card,
          isFaceUp: true,
          position: origin,
          anchor: Anchor.center,
        )..scale = Vector2.all(sourceScale);
        add(tempCard);
        _animateCardPlay(tempCard, target).then((_) {
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
  // Victory particles & Animation
  // ---------------------------------------------------------------------------

  void spawnVictoryParticles() {
    final position = layout.trickCenter;
    const particleCount = 60;
    const durationSeconds = 2.0;

    for (int i = 0; i < particleCount; i++) {
      final angle = (math.pi * 2 / particleCount) * i;
      final particle = _GoldParticleComponent(
        startPosition: position.clone(),
        angle: angle,
        durationSeconds: durationSeconds,
      );
      add(particle);
    }
  }

  Future<void> _animateCardPlay(
    CardComponent card,
    Vector2 target, {
    double targetScale = 1.0,
  }) async {
    final moveCompleter = Completer<void>();
    final scaleCompleter = Completer<void>();

    // Use the visual size (base size * current scale) for the shadow
    final visualSize = Vector2(
      card.size.x * card.scale.x,
      card.size.y * card.scale.y,
    );

    // Attach a shadow component that fades out as the card lands
    final shadow = _CardShadowComponent(
      cardSize: visualSize,
      totalDistance: card.position.distanceTo(target),
    );
    card.add(shadow);

    card.add(
      MoveEffect.to(
        target,
        CurvedEffectController(0.3, Curves.easeOut),
        onComplete: () {
          shadow.removeFromParent();
          moveCompleter.complete();
        },
      ),
    );

    // Scale animation: slight pop above target, then settle to target scale.
    // This gives a satisfying "land" feel regardless of source scale.
    final popScale = targetScale * 1.08;
    card.add(
      ScaleEffect.to(
        Vector2.all(popScale),
        CurvedEffectController(0.15, Curves.easeOut),
        onComplete: () {
          card.add(
            ScaleEffect.to(
              Vector2.all(targetScale),
              CurvedEffectController(0.15, Curves.easeIn),
              onComplete: scaleCompleter.complete,
            ),
          );
        },
      ),
    );

    await Future.wait([moveCompleter.future, scaleCompleter.future]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _flashTrickWinnerSeat(ClientGameState state) {
    if (state.trumpSuit == null) return;
    if (state.currentTrickPlays.length != 4) return;

    final plays = state.currentTrickPlays.map((p) {
      final absoluteSeat = state.playerUids.indexOf(p.playerUid);
      return TrickPlay(playerIndex: absoluteSeat, card: p.card);
    }).toList();

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
    if (relativeSeat >= 0 && relativeSeat < _lifecycle.seats.length) {
      _lifecycle.seats[relativeSeat].flashTrickWin();
    }
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

// ---------------------------------------------------------------------------
// Drop shadow component
// ---------------------------------------------------------------------------

/// Renders a drop shadow beneath a card while it is in motion.
///
/// The shadow offset scales with [totalDistance]: at the start of flight the
/// shadow is largest (highest altitude), and it shrinks to zero as the card
/// lands.
class _CardShadowComponent extends PositionComponent {
  final Vector2 cardSize;
  final double totalDistance;
  double _elapsed = 0;
  static const double _flightDuration = 0.3; // matches MoveEffect duration

  _CardShadowComponent({
    required this.cardSize,
    required this.totalDistance,
  }) : super(position: Vector2.zero(), anchor: Anchor.topLeft);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed = (_elapsed + dt).clamp(0.0, _flightDuration);
  }

  @override
  void render(Canvas canvas) {
    final progress = _elapsed / _flightDuration; // 0.0 = start, 1.0 = landed
    final altitude = 1.0 - progress; // 1.0 = high, 0.0 = landed
    final maxOffset = math.min(totalDistance * 0.12, 14.0);
    final shadowOffset = maxOffset * altitude;

    if (shadowOffset < 0.5) return; // not worth drawing

    final shadowRect = Rect.fromLTWH(
      shadowOffset,
      shadowOffset,
      cardSize.x,
      cardSize.y,
    );
    final shadowPaint = Paint()
      ..color = const Color(0x55000000).withValues(alpha: 0.35 * altitude)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowOffset * 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(6)),
      shadowPaint,
    );
  }
}

// ---------------------------------------------------------------------------
// Gold particle component (trick win celebration)
// ---------------------------------------------------------------------------

/// A single expanding gold circle particle for the trick-win celebration.
class _GoldParticleComponent extends PositionComponent {
  @override
  final double angle;
  final double durationSeconds;
  double _elapsed = 0;

  static const double _speed = 80.0; // pixels per second
  static const double _maxRadius = 5.0;

  _GoldParticleComponent({
    required Vector2 startPosition,
    required this.angle,
    required this.durationSeconds,
  }) : super(position: startPosition, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    // Move outward
    position.x += math.cos(angle) * _speed * dt;
    position.y += math.sin(angle) * _speed * dt;

    if (_elapsed >= durationSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / durationSeconds).clamp(0.0, 1.0);
    final opacity = 1.0 - progress; // fade out
    final radius = _maxRadius * (0.3 + progress * 0.7); // grow slightly

    final paint = Paint()
      ..color = KoutTheme.accent.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}
