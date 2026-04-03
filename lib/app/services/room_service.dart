import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/auth_service.dart';

class RoomService {
  final AuthService _auth;

  RoomService({AuthService? auth}) : _auth = auth ?? AuthService();

  Future<({String roomCode, String gameId})> createRoom() async {
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/rooms/create'),
      headers: {
        'Authorization': 'Bearer ${_auth.token}',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create room: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      roomCode: data['roomCode'] as String,
      gameId: data['gameId'] as String,
    );
  }

  Future<String> joinRoom(String code) async {
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/rooms/join'),
      headers: {
        'Authorization': 'Bearer ${_auth.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code.toUpperCase()}),
    );
    if (response.statusCode == 404) throw Exception('Room not found');
    if (response.statusCode == 409) throw Exception('Room is full');
    if (response.statusCode == 410) throw Exception('Game already started');
    if (response.statusCode != 200) {
      throw Exception('Failed to join room: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['gameId'] as String;
  }

  Future<void> startGame(String gameId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.workerUrl}/api/rooms/start'),
      headers: {
        'Authorization': 'Bearer ${_auth.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'gameId': gameId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to start game: ${response.body}');
    }
  }
}
