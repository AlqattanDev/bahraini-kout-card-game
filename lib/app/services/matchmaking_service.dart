import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

class MatchmakingService {
  final String _token;
  WebSocketChannel? _lobbyChannel;

  MatchmakingService({required String token, required String myUid})
      : _token = token;

  Future<String?> joinQueue(int eloRating) async {
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/matchmaking/join'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'eloRating': eloRating}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to join queue: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] == 'matched') {
      return body['gameId'] as String;
    }

    return null; // Queued, wait for WS notification
  }

  Stream<String> listenForMatch() {
    final controller = StreamController<String>();

    _lobbyChannel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsUrl}/ws/matchmaking?token=$_token'),
    );

    _lobbyChannel!.stream.listen(
      (message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        if (data['event'] == 'matched') {
          final gameId = (data['data'] as Map<String, dynamic>)['gameId'] as String;
          controller.add(gameId);
          controller.close();
        }
      },
      onError: (error) {
        controller.addError(error as Object);
        controller.close();
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    return controller.stream;
  }

  Future<void> leaveQueue() async {
    _lobbyChannel?.sink.close();
    _lobbyChannel = null;

    await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/matchmaking/leave'),
      headers: {'Authorization': 'Bearer $_token'},
    );
  }

  void dispose() {
    _lobbyChannel?.sink.close();
    _lobbyChannel = null;
  }
}
