import 'package:koutbh/app/models/seat_config.dart';

sealed class GameMode {}

class OnlineGameMode extends GameMode {
  final String gameId;
  final String myUid;
  final String token;

  OnlineGameMode({
    required this.gameId,
    required this.myUid,
    required this.token,
  });
}

class OfflineGameMode extends GameMode {
  final List<SeatConfig> seats;

  OfflineGameMode({required this.seats});
}

class RoomGameMode extends GameMode {
  final String gameId;
  final String myUid;
  final String token;
  final String roomCode;
  final bool isHost;

  RoomGameMode({
    required this.gameId,
    required this.myUid,
    required this.token,
    required this.roomCode,
    required this.isHost,
  });
}
