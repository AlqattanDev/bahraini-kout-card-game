class MatchmakingArgs {
  final String uid;
  final String token;

  const MatchmakingArgs({required this.uid, required this.token});

  static MatchmakingArgs? fromRouteArgs(dynamic args) {
    if (args is MatchmakingArgs) return args;
    if (args is Map<String, dynamic>) {
      final uid = args['uid'] as String?;
      final token = args['token'] as String?;
      if (uid != null && token != null) {
        return MatchmakingArgs(uid: uid, token: token);
      }
    }
    return null;
  }
}

class RoomLobbyArgs {
  final String gameId;
  final String roomCode;
  final String myUid;
  final String token;
  final bool isHost;

  const RoomLobbyArgs({
    required this.gameId,
    required this.roomCode,
    required this.myUid,
    required this.token,
    required this.isHost,
  });

  static RoomLobbyArgs? fromRouteArgs(dynamic args) {
    if (args is RoomLobbyArgs) return args;
    if (args is Map<String, dynamic>) {
      final gameId = args['gameId'] as String?;
      final roomCode = args['roomCode'] as String?;
      final myUid = args['myUid'] as String?;
      final token = args['token'] as String?;
      final isHost = args['isHost'] as bool?;
      if (gameId != null &&
          roomCode != null &&
          myUid != null &&
          token != null &&
          isHost != null) {
        return RoomLobbyArgs(
          gameId: gameId,
          roomCode: roomCode,
          myUid: myUid,
          token: token,
          isHost: isHost,
        );
      }
    }
    return null;
  }
}
