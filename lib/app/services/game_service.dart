import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/client_game_state.dart';
import '../models/lobby_state.dart';
import '../../offline/game_input_sink.dart';
import '../../shared/models/card.dart';
import '../../shared/models/bid.dart';

enum ConnectionStatus { connected, disconnected, reconnecting, reconnectFailed }

class GameService implements GameInputSink {
  final String _gameId;
  final String _myUid;
  final String _token;

  WebSocketChannel? _channel;
  final _stateController = StreamController<ClientGameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  final _lobbyController = StreamController<LobbyState>.broadcast();
  Stream<ClientGameState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  Stream<LobbyState> get lobbyStream => _lobbyController.stream;

  List<String> _myHand = [];
  Map<String, dynamic>? _lastPublicState;
  bool _disposed = false;
  bool _hasReceivedMessage = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  GameService({
    required String gameId,
    required String myUid,
    required String token,
  })  : _gameId = gameId,
        _myUid = myUid,
        _token = token;

  void startListening() {
    _connect();
  }

  void _connect() {
    if (_disposed) return;

    // Close previous channel to avoid duplicate listeners
    _channel?.sink.close();
    _hasReceivedMessage = false;

    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsUrl}/ws/game/$_gameId?token=$_token'),
    );

    _channel!.stream.listen(
      (message) {
        if (!_hasReceivedMessage) {
          _hasReceivedMessage = true;
          _reconnectAttempts = 0;
          _connectionController.add(ConnectionStatus.connected);
        }
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final event = data['event'] as String;

        switch (event) {
          case 'gameState':
            _lastPublicState = data['data'] as Map<String, dynamic>;
            _stateController.add(
              ClientGameState.fromMap(_lastPublicState!, _myUid, _myHand),
            );
          case 'hand':
            final handData = data['data'] as Map<String, dynamic>;
            _myHand = List<String>.from(handData['hand'] as List<dynamic>);
            if (_lastPublicState != null) {
              _stateController.add(
                ClientGameState.fromMap(_lastPublicState!, _myUid, _myHand),
              );
            }
          case 'reconnected':
            // Server confirms this was a reconnect (not a fresh connect)
            _connectionController.add(ConnectionStatus.connected);
          case 'lobby_state':
            final lobbyData = data['data'] as Map<String, dynamic>;
            _lobbyController.add(LobbyState.fromMap(lobbyData));
          case 'error':
            final errorData = data['data'] as Map<String, dynamic>;
            _errorController.add(errorData['message'] as String);
          default:
            break;
        }
      },
      onError: (error) {
        _connectionController.add(ConnectionStatus.disconnected);
        _errorController.add('Connection error: $error');
        _attemptReconnect();
      },
      onDone: () {
        if (!_disposed) {
          _connectionController.add(ConnectionStatus.disconnected);
          _attemptReconnect();
        }
      },
    );
  }

  void _attemptReconnect() {
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _connectionController.add(ConnectionStatus.reconnectFailed);
      return;
    }
    _reconnectAttempts++;
    _connectionController.add(ConnectionStatus.reconnecting);
    final delay = Duration(seconds: _reconnectAttempts * 2);
    Future.delayed(delay, () => _connect());
  }

  void _sendAction(String action, Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode({'action': action, 'data': data}));
  }

  void sendBid(int bidAmount) =>
      _sendAction('placeBid', {'bidAmount': bidAmount});

  void sendPass() =>
      _sendAction('placeBid', {'bidAmount': 0});

  void sendTrumpSelection(String suit) =>
      _sendAction('selectTrump', {'suit': suit});

  void sendPlayCard(String cardCode) =>
      _sendAction('playCard', {'card': cardCode});

  // GameInputSink implementation
  @override
  void playCard(GameCard card) => sendPlayCard(card.encode());

  @override
  void placeBid(BidAmount amount) => sendBid(amount.value);

  @override
  void pass() => sendPass();

  @override
  void selectTrump(Suit suit) => sendTrumpSelection(suit.name);

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _stateController.close();
    _errorController.close();
    _connectionController.close();
    _lobbyController.close();
  }
}
