import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/client_game_state.dart';
import '../../offline/game_input_sink.dart';
import '../../shared/models/card.dart';
import '../../shared/models/bid.dart';

class GameService implements GameInputSink {
  final String _gameId;
  final String _myUid;
  final String _token;

  WebSocketChannel? _channel;
  final _stateController = StreamController<ClientGameState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  Stream<ClientGameState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;

  List<String> _myHand = [];
  Map<String, dynamic>? _lastPublicState;
  bool _disposed = false;
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

    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsUrl}/ws/game/$_gameId?token=$_token'),
    );

    _channel!.stream.listen(
      (message) {
        _reconnectAttempts = 0; // Reset on successful message
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
            // Re-emit state with updated hand
            if (_lastPublicState != null) {
              _stateController.add(
                ClientGameState.fromMap(_lastPublicState!, _myUid, _myHand),
              );
            }
          case 'error':
            final errorData = data['data'] as Map<String, dynamic>;
            _errorController.add(errorData['message'] as String);
        }
      },
      onError: (error) {
        _errorController.add('Connection error: $error');
        _attemptReconnect();
      },
      onDone: () {
        if (!_disposed) _attemptReconnect();
      },
    );
  }

  void _attemptReconnect() {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
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
  }
}
