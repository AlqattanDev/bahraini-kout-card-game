import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/app/models/seat_config.dart';

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
