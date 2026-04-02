import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'card_tracker.dart';
import 'bot_difficulty.dart';

class GameContext {
  final int mySeat;
  final Team myTeam;
  final Map<Team, int> scores;
  final BidAmount? currentBid;
  final int? bidderSeat;
  final bool isBiddingTeam;
  final bool isForcedBid;
  final Map<Team, int> trickCounts;
  final List<Team> trickWinners;
  final Suit? trumpSuit;
  final CardTracker? tracker;
  final BotDifficulty difficulty;

  const GameContext({
    required this.mySeat,
    required this.myTeam,
    required this.scores,
    required this.currentBid,
    required this.bidderSeat,
    required this.isBiddingTeam,
    required this.isForcedBid,
    required this.trickCounts,
    required this.trickWinners,
    this.trumpSuit,
    this.tracker,
    this.difficulty = BotDifficulty.balanced,
  });

  Team get opponentTeam => myTeam.opponent;
  int get partnerSeat => (mySeat + 2) % 4;
  int get myTricks => trickCounts[myTeam] ?? 0;
  int get opponentTricks => trickCounts[opponentTeam] ?? 0;
  int get tricksPlayed => trickWinners.length;

  /// How many more tricks the bidding team needs to make the bid.
  int get tricksNeededForBid {
    final biddingTeam =
        bidderSeat != null ? teamForSeat(bidderSeat!) : myTeam;
    final won = trickCounts[biddingTeam] ?? 0;
    return (currentBid?.value ?? 5) - won;
  }

  factory GameContext.fromClientState(
    ClientGameState state,
    int seatIndex, {
    CardTracker? tracker,
    bool isForcedBid = false,
    BotDifficulty difficulty = BotDifficulty.balanced,
  }) {
    final myTeam = teamForSeat(seatIndex);
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : null;
    return GameContext(
      mySeat: seatIndex,
      myTeam: myTeam,
      scores: state.scores,
      currentBid: state.currentBid,
      bidderSeat: bidderSeat,
      isBiddingTeam: bidderSeat != null && teamForSeat(bidderSeat) == myTeam,
      isForcedBid: isForcedBid,
      trickCounts: state.tricks,
      trickWinners: state.trickWinners,
      trumpSuit: state.trumpSuit,
      tracker: tracker,
      difficulty: difficulty,
    );
  }
}
