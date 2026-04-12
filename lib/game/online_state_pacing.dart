import 'dart:async';

import '../app/models/client_game_state.dart';
import '../app/services/game_service.dart';
import '../shared/constants/timing.dart';
import '../shared/models/game_state.dart';

/// Max buffered states before dropping oldest (catch-up after backlog).
const int _maxQueueBacklog = 64;

/// Delay before emitting [incoming] after [prev] during play (offline parity).
///
/// Exposed for unit tests.
Duration? onlinePlayPacingDelay(
  ClientGameState? prev,
  ClientGameState incoming,
) {
  if (incoming.phase != GamePhase.playing) return null;
  if (prev == null || prev.phase != GamePhase.playing) return null;

  final pl = prev.currentTrickPlays.length;
  final il = incoming.currentTrickPlays.length;

  if (pl == 4 && il == 0) return GameTiming.trickResolutionDelay;
  if (pl == 4 && il == 1) return GameTiming.trickResolutionDelay;

  if (il > pl && pl < 4 && il <= 4) return GameTiming.cardPlayDelay;

  if (pl == 0 && il == 1) return GameTiming.cardPlayDelay;

  return null;
}

/// Spaces [source] like offline [LocalGameController] card/trick pauses.
///
/// When [incoming.currentPlayerUid] == [myUid], pending timers are cancelled and
/// the queue is flushed so the 15s server [human_timeout] is not eaten by UI delay.
///
/// On [ConnectionStatus.connected], pending delays are skipped and queued states
/// are emitted immediately.
Stream<ClientGameState> paceOnlineGameStates(
  Stream<ClientGameState> source, {
  required String myUid,
  Stream<ConnectionStatus>? connectionStream,
}) {
  final queue = <ClientGameState>[];
  ClientGameState? lastEmitted;
  Timer? pendingTimer;
  StreamSubscription<ClientGameState>? sourceSub;
  StreamSubscription<ConnectionStatus>? connSub;

  late final StreamController<ClientGameState> controller;

  void flushQueueImmediate() {
    pendingTimer?.cancel();
    pendingTimer = null;
    while (queue.isNotEmpty) {
      final s = queue.removeAt(0);
      lastEmitted = s;
      controller.add(s);
    }
  }

  void drainQueue() {
    if (queue.isEmpty) return;
    if (pendingTimer != null) return;
    final next = queue.first;
    if (next.currentPlayerUid == myUid) {
      flushQueueImmediate();
      return;
    }
    final delay = onlinePlayPacingDelay(lastEmitted, next);
    if (delay == null || delay == Duration.zero) {
      final s = queue.removeAt(0);
      lastEmitted = s;
      controller.add(s);
      drainQueue();
      return;
    }
    pendingTimer = Timer(delay, () {
      pendingTimer = null;
      final s = queue.removeAt(0);
      lastEmitted = s;
      controller.add(s);
      drainQueue();
    });
  }

  void enqueue(ClientGameState incoming) {
    queue.add(incoming);
    while (queue.length > _maxQueueBacklog) {
      queue.removeAt(0);
    }
  }

  controller = StreamController<ClientGameState>(
    onListen: () {
      sourceSub = source.listen(
        (incoming) {
          enqueue(incoming);
          drainQueue();
        },
        onError: controller.addError,
        onDone: () {
          pendingTimer?.cancel();
          controller.close();
        },
      );
      connSub = connectionStream?.listen((status) {
        if (status == ConnectionStatus.connected) {
          pendingTimer?.cancel();
          pendingTimer = null;
          while (queue.isNotEmpty) {
            final s = queue.removeAt(0);
            lastEmitted = s;
            controller.add(s);
          }
        }
      });
    },
    onCancel: () {
      sourceSub?.cancel();
      connSub?.cancel();
      pendingTimer?.cancel();
    },
  );

  return controller.stream;
}
