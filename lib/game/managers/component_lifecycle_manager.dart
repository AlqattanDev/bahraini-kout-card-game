import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../components/ambient_decoration.dart';
import '../components/opponent_hand_fan.dart';
import '../components/opponent_name_label.dart';
import '../components/perspective_table.dart';
import '../components/player_seat.dart';
import '../components/table_background.dart';
import '../theme/kout_theme.dart';
import 'layout_manager.dart';

/// Manages creation, mounting, unmounting, and disposal of visual components
/// that toggle between portrait and landscape modes. Extracted from KoutGame.
class ComponentLifecycleManager {
  final FlameGame game;

  final List<PlayerSeatComponent> seats = [];
  final Map<int, OpponentHandFan> opponentFans = {};
  final Map<int, OpponentNameLabel> opponentLabels = {};
  OpponentNameLabel? playerLabel;
  AmbientDecorationComponent? ambientDecoration;
  PerspectiveTableComponent? perspectiveTable;

  bool _isLandscape = false;
  bool get isLandscape => _isLandscape;

  ComponentLifecycleManager({required this.game});

  /// Toggles visibility of portrait-only components based on current layout.
  /// Returns true if the landscape state changed.
  bool updateLandscapeVisibility(bool landscape) {
    if (landscape == _isLandscape) return false;
    _isLandscape = landscape;

    // Only ambient decoration is portrait-only
    _toggleVisibility(ambientDecoration, showInPortrait: true);

    // Update table background
    final tableBg =
        game.children.whereType<TableBackgroundComponent>().firstOrNull;
    if (tableBg != null) {
      tableBg.isLandscape = landscape;
    }

    return true;
  }

  /// Creates seats, fans, and ambient decoration on first state update.
  void initSeats(ClientGameState state, LayoutManager layout) {
    if (seats.isNotEmpty) return;

    for (int i = 0; i < 4; i++) {
      final pos = layout.seatPosition(i, state.mySeatIndex);
      final seat = PlayerSeatComponent(
        seatIndex: i,
        playerName: shortUid(state.playerUids[i]),
        cardCount: 0,
        isActive: false,
        team: teamForSeat(i),
        avatarSeed: i,
        position: pos,
      );
      seats.add(seat);
      game.add(seat);
    }

    ambientDecoration = AmbientDecorationComponent(
      seatPositions: [
        for (int i = 0; i < 4; i++) layout.seatPosition(i, state.mySeatIndex),
      ],
    );
    if (!_isLandscape) game.add(ambientDecoration!);

    for (int i = 0; i < 4; i++) {
      if (i == state.mySeatIndex) continue;
      final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
      final seatPos = layout.seatPosition(i, state.mySeatIndex);

      final double rotation;
      final Vector2 offset;
      switch (relativeSeat) {
        case 1:
          rotation = math.pi / 2;
          offset = _fanOffset(1);
        case 2:
          rotation = math.pi;
          offset = _fanOffset(2);
        case 3:
          rotation = -math.pi / 2;
          offset = _fanOffset(3);
        default:
          continue;
      }

      final fan = OpponentHandFan(
        cardCount: 8,
        position: seatPos + offset,
        baseRotation: rotation,
      );
      opponentFans[i] = fan;
      game.add(fan);
    }
  }

  /// Updates seat states, positions, bidder glow, and opponent fan counts.
  void updateSeats(ClientGameState state, LayoutManager layout) {
    initSeats(state, layout);

    for (int i = 0; i < state.playerUids.length && i < seats.length; i++) {
      final uid = state.playerUids[i];

      seats[i].updateState(state);
      seats[i].position = layout.seatPosition(i, state.mySeatIndex);

      final showGlow = state.phase != GamePhase.bidding &&
          state.phase != GamePhase.waiting &&
          state.phase != GamePhase.dealing;
      if (showGlow && uid == state.bidderUid) {
        seats[i].setBidderGlow(true, KoutTheme.teamColor(teamForSeat(i)));
      } else {
        seats[i].setBidderGlow(false, null);
      }

      if (opponentFans.containsKey(i)) {
        opponentFans[i]!.updateCardCount(state.cardCounts[i] ?? 8);
        final relativeSeat = layout.toRelativeSeat(i, state.mySeatIndex);
        final seatPos = layout.seatPosition(i, state.mySeatIndex);
        opponentFans[i]!.position = seatPos + _fanOffset(relativeSeat);
      }
    }
  }

  Vector2 _fanOffset(int relativeSeat) {
    const offset = 70.0;
    return switch (relativeSeat) {
      1 => Vector2(offset, -10),
      2 => Vector2(0, offset),
      3 => Vector2(-offset, -10),
      _ => Vector2.zero(),
    };
  }

  /// Seats handle identity in all orientations — clean up any leftover labels.
  void updateLandscapeLabels(ClientGameState state, LayoutManager layout) {
    for (final label in opponentLabels.values) {
      if (label.isMounted) label.removeFromParent();
    }
    opponentLabels.clear();
    if (playerLabel != null) {
      if (playerLabel!.isMounted) playerLabel!.removeFromParent();
      playerLabel = null;
    }
  }

  /// Adds or removes a component based on landscape state.
  void _toggleVisibility(Component? component, {required bool showInPortrait}) {
    if (component == null) return;
    final shouldShow = showInPortrait ? !_isLandscape : _isLandscape;
    if (shouldShow && !component.isMounted) {
      game.add(component);
    } else if (!shouldShow && component.isMounted) {
      component.removeFromParent();
    }
  }
}
