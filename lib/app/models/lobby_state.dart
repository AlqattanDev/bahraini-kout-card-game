class LobbyState {
  final List<LobbySeat> seats;
  final String roomCode;
  final bool isHost;

  const LobbyState({
    required this.seats,
    required this.roomCode,
    required this.isHost,
  });

  bool get isFull => seats.every((s) => s.isBot || s.uid != null);

  factory LobbyState.fromMap(Map<String, dynamic> data) {
    final rawSeats = data['seats'] as List<dynamic>;
    final seats = rawSeats.cast<Map<String, dynamic>>().map((s) => LobbySeat(
          seat: s['seat'] as int,
          uid: s['uid'] as String?,
          isBot: s['isBot'] as bool,
          connected: s['connected'] as bool? ?? false,
        )).toList();

    return LobbyState(
      seats: seats,
      roomCode: data['roomCode'] as String? ?? '',
      isHost: data['isHost'] as bool? ?? false,
    );
  }
}

class LobbySeat {
  final int seat;
  final String? uid;
  final bool isBot;
  final bool connected;

  const LobbySeat({
    required this.seat,
    required this.uid,
    required this.isBot,
    required this.connected,
  });
}
