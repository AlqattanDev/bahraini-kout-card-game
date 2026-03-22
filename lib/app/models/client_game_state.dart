import '../../shared/models/card.dart';
import '../../shared/models/game_state.dart';
import '../../shared/models/bid.dart';
import '../../shared/models/enums.dart';

class ClientGameState {
  final GamePhase phase;
  final List<String> playerUids;
  final Map<Team, int> scores;
  final Map<Team, int> tricks;
  final String? currentPlayerUid;
  final String dealerUid;
  final Suit? trumpSuit;
  final BidAmount? currentBid;
  final String? bidderUid;
  final List<({String playerUid, GameCard card})> currentTrickPlays;
  final List<GameCard> myHand;
  final String myUid;

  ClientGameState({
    required this.phase,
    required this.playerUids,
    required this.scores,
    required this.tricks,
    required this.currentPlayerUid,
    required this.dealerUid,
    required this.trumpSuit,
    required this.currentBid,
    required this.bidderUid,
    required this.currentTrickPlays,
    required this.myHand,
    required this.myUid,
  });

  bool get isMyTurn => currentPlayerUid == myUid;
  int get mySeatIndex => playerUids.indexOf(myUid);
  Team get myTeam => teamForSeat(mySeatIndex);

  /// Creates a [ClientGameState] from a raw Firestore game document map plus
  /// the current player's hand (list of encoded card strings).
  factory ClientGameState.fromMap(
    Map<String, dynamic> gameData,
    String myUid,
    List<String> myHandEncoded,
  ) {
    final phaseName = gameData['phase'] as String;
    final phase = GamePhase.values.firstWhere((e) => e.name == phaseName);

    final playerUids = List<String>.from(gameData['playerUids'] as List);

    final rawScores = gameData['scores'] as Map<String, dynamic>;
    final scores = <Team, int>{
      Team.a: (rawScores['a'] as num).toInt(),
      Team.b: (rawScores['b'] as num).toInt(),
    };

    final rawTricks = gameData['tricks'] as Map<String, dynamic>;
    final tricks = <Team, int>{
      Team.a: (rawTricks['a'] as num).toInt(),
      Team.b: (rawTricks['b'] as num).toInt(),
    };

    final currentPlayerUid = gameData['currentPlayerUid'] as String?;
    final dealerUid = gameData['dealerUid'] as String;

    final trumpSuitName = gameData['trumpSuit'] as String?;
    final trumpSuit = trumpSuitName != null
        ? Suit.values.firstWhere((e) => e.name == trumpSuitName)
        : null;

    final currentBidValue = gameData['currentBid'] as int?;
    final currentBid = currentBidValue != null ? BidAmount.fromValue(currentBidValue) : null;

    final bidderUid = gameData['bidderUid'] as String?;

    final rawTrick = gameData['currentTrick'] as List<dynamic>?;
    final currentTrickPlays = rawTrick == null
        ? <({String playerUid, GameCard card})>[]
        : rawTrick
            .cast<Map<String, dynamic>>()
            .map((play) => (
                  playerUid: play['playerUid'] as String,
                  card: GameCard.decode(play['card'] as String),
                ))
            .toList();

    final myHand = myHandEncoded.map(GameCard.decode).toList();

    return ClientGameState(
      phase: phase,
      playerUids: playerUids,
      scores: scores,
      tricks: tricks,
      currentPlayerUid: currentPlayerUid,
      dealerUid: dealerUid,
      trumpSuit: trumpSuit,
      currentBid: currentBid,
      bidderUid: bidderUid,
      currentTrickPlays: currentTrickPlays,
      myHand: myHand,
      myUid: myUid,
    );
  }
}
