import 'dart:async';
import 'package:flame/game.dart';
import '../app/models/client_game_state.dart';
import 'managers/layout_manager.dart';

class KoutGame extends FlameGame {
  final Stream<ClientGameState> stateStream;
  final void Function(String action, Map<String, dynamic> data) onAction;

  StreamSubscription<ClientGameState>? _stateSub;
  ClientGameState? currentState;
  late LayoutManager layout;

  KoutGame({required this.stateStream, required this.onAction});

  @override
  Future<void> onLoad() async {
    layout = LayoutManager(size);
    _stateSub = stateStream.listen((state) {
      currentState = state;
      _onStateUpdate(state);
    });
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    layout = LayoutManager(size);
  }

  void _onStateUpdate(ClientGameState state) {
    // Will add overlay management as components are built
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    super.onRemove();
  }
}
