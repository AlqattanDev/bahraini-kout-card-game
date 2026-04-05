import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/app/models/seat_config.dart';

/// Offline game state holder for [LocalGameController].
///
/// MUTABILITY CONTRACT:
/// This class intentionally uses mutable fields (not const, not immutable types)
/// for offline engine performance. The [LocalGameController] modifies state in-place
/// during game loops to avoid allocation overhead.
///
/// Safety guarantee: [LocalGameController._toClientState()] creates defensive copies
/// (using spread operators and List.unmodifiable) before emitting to UI. Consumers
/// of [ClientGameState] receive immutable snapshots and are safe from mutations.
///
/// Never expose [FullGameState] directly; always convert via [LocalGameController._toClientState()].
class FullGameState {
  GamePhase phase;
  List<SeatConfig> players;
  Map<int, List<GameCard>> hands;
  Map<Team, int> scores;
  Map<Team, int> trickCounts;
  List<({int seat, GameCard card})> currentTrickPlays;
  int dealerSeat;
  int currentSeat;
  BidAmount? bid;
  int? bidderSeat;
  Suit? trumpSuit;
  List<int> passedPlayers;
  List<({int seat, String action})> bidHistory;
  int trickNumber;
  List<Team> trickWinners;

  FullGameState({
    required this.phase,
    required this.players,
    required this.hands,
    required this.scores,
    required this.trickCounts,
    this.currentTrickPlays = const [],
    required this.dealerSeat,
    required this.currentSeat,
    this.bid,
    this.bidderSeat,
    this.trumpSuit,
    this.passedPlayers = const [],
    this.bidHistory = const [],
    this.trickNumber = 1,
    this.trickWinners = const [],
  });
}
