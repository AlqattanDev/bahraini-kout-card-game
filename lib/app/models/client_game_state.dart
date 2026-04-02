import '../../shared/models/card.dart';
import '../../shared/models/game_state.dart';
import '../../shared/models/bid.dart';

/// Map of phase strings to Dart enum values.
/// Supports both Worker format (UPPER_SNAKE) and camelCase.
const _phaseMap = {
  // Worker format
  'WAITING': GamePhase.waiting,
  'DEALING': GamePhase.dealing,
  'BIDDING': GamePhase.bidding,
  'TRUMP_SELECTION': GamePhase.trumpSelection,
  'BID_ANNOUNCEMENT': GamePhase.bidAnnouncement,
  'PLAYING': GamePhase.playing,
  'ROUND_SCORING': GamePhase.roundScoring,
  'GAME_OVER': GamePhase.gameOver,
  // camelCase format
  'waiting': GamePhase.waiting,
  'dealing': GamePhase.dealing,
  'bidding': GamePhase.bidding,
  'trumpSelection': GamePhase.trumpSelection,
  'bidAnnouncement': GamePhase.bidAnnouncement,
  'playing': GamePhase.playing,
  'roundScoring': GamePhase.roundScoring,
  'gameOver': GamePhase.gameOver,
};

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
  final List<int> passedPlayers;
  final List<({String playerUid, String action})> bidHistory;
  final List<Team> trickWinners;
  final Map<int, int> cardCounts;

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
    this.passedPlayers = const [],
    this.bidHistory = const [],
    this.trickWinners = const [],
    this.cardCounts = const {},
  });

  bool get isMyTurn => currentPlayerUid == myUid;
  int get mySeatIndex => playerUids.indexOf(myUid);
  Team get myTeam => teamForSeat(mySeatIndex);

  /// Creates a [ClientGameState] from a Worker WebSocket game state message
  /// plus the current player's hand (list of encoded card strings).
  factory ClientGameState.fromMap(
    Map<String, dynamic> gameData,
    String myUid,
    List<String> myHandEncoded,
  ) {
    // Phase: Worker sends "BIDDING", Dart enum is GamePhase.bidding
    final phaseName = gameData['phase'] as String;
    final phase = _phaseMap[phaseName] ?? GamePhase.waiting;

    // Players: Worker sends "players", old Firestore used "playerUids"
    final playerUids = List<String>.from(
      (gameData['players'] ?? gameData['playerUids']) as List,
    );

    // Scores: Worker sends {teamA: N, teamB: N}, old Firestore used {a: N, b: N}
    final rawScores = gameData['scores'] as Map<String, dynamic>;
    final scores = <Team, int>{
      Team.a: (rawScores['teamA'] ?? rawScores['a'] ?? 0 as num).toInt(),
      Team.b: (rawScores['teamB'] ?? rawScores['b'] ?? 0 as num).toInt(),
    };

    // Tricks: same format as scores
    final rawTricks = gameData['tricks'] as Map<String, dynamic>;
    final tricks = <Team, int>{
      Team.a: (rawTricks['teamA'] ?? rawTricks['a'] ?? 0 as num).toInt(),
      Team.b: (rawTricks['teamB'] ?? rawTricks['b'] ?? 0 as num).toInt(),
    };

    // Current player: Worker sends "currentPlayer", old used "currentPlayerUid"
    final currentPlayerUid =
        (gameData['currentPlayer'] ?? gameData['currentPlayerUid']) as String?;

    // Dealer: Worker sends "dealer", old used "dealerUid"
    final dealerUid =
        (gameData['dealer'] ?? gameData['dealerUid']) as String;

    // Trump suit
    final trumpSuitName = gameData['trumpSuit'] as String?;
    final trumpSuit = trumpSuitName != null
        ? Suit.values.firstWhere((e) => e.name == trumpSuitName)
        : null;

    // Bid: Worker sends {player, amount}, old used separate fields
    int? currentBidValue;
    String? bidderUid;
    final bidData = gameData['bid'];
    if (bidData is Map<String, dynamic>) {
      currentBidValue = (bidData['amount'] as num?)?.toInt();
      bidderUid = bidData['player'] as String?;
    } else {
      currentBidValue = gameData['currentBid'] as int?;
      bidderUid = gameData['bidderUid'] as String?;
    }
    final currentBid =
        currentBidValue != null ? BidAmount.fromValue(currentBidValue) : null;

    // Current trick: Worker sends {lead, plays: [{player, card}]}
    List<({String playerUid, GameCard card})> currentTrickPlays = [];
    final rawTrick = gameData['currentTrick'];
    if (rawTrick is Map<String, dynamic>) {
      // Worker format: {lead: "uid", plays: [{player: "uid", card: "SA"}]}
      final plays = rawTrick['plays'] as List<dynamic>?;
      if (plays != null) {
        currentTrickPlays = plays
            .cast<Map<String, dynamic>>()
            .map((play) => (
                  playerUid: play['player'] as String,
                  card: GameCard.decode(play['card'] as String),
                ))
            .toList();
      }
    } else if (rawTrick is List<dynamic>) {
      // Old Firestore format: [{playerUid, card}]
      currentTrickPlays = rawTrick
          .cast<Map<String, dynamic>>()
          .map((play) => (
                playerUid: play['playerUid'] as String,
                card: GameCard.decode(play['card'] as String),
              ))
          .toList();
    }

    final myHand = myHandEncoded.map(GameCard.decode).toList();

    final passedPlayers = List<int>.from(
      gameData['passedPlayers'] ?? gameData['passed_players'] ?? [],
    );
    final rawTrickWinners = gameData['trickWinners'] as List<dynamic>? ?? [];
    final trickWinners = rawTrickWinners
        .map((tw) => (tw as String) == 'teamA' ? Team.a : Team.b)
        .toList();

    final rawBidHistory = gameData['bidHistory'] ?? gameData['bid_history'];
    final bidHistory = rawBidHistory != null
        ? (rawBidHistory as List)
            .cast<Map<String, dynamic>>()
            .map((e) => (
                  playerUid: e['player'] as String,
                  action: e['action'] as String,
                ))
            .toList()
        : <({String playerUid, String action})>[];

    final rawCardCounts = gameData['cardCounts'] as Map<String, dynamic>?;
    final cardCounts = rawCardCounts != null
        ? rawCardCounts.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()))
        : <int, int>{};

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
      passedPlayers: passedPlayers,
      bidHistory: bidHistory,
      trickWinners: trickWinners,
      cardCounts: cardCounts,
    );
  }
}
