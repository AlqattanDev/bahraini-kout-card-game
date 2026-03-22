import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/client_game_state.dart';

class GameService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _gameId;
  final String _myUid;

  StreamSubscription? _gameDocSub;
  StreamSubscription? _handSub;

  final _stateController = StreamController<ClientGameState>.broadcast();
  Stream<ClientGameState> get stateStream => _stateController.stream;

  DocumentSnapshot<Map<String, dynamic>>? _lastGameDoc;
  List<String> _myHandEncoded = [];

  GameService({
    required String gameId,
    required String myUid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _gameId = gameId,
        _myUid = myUid,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  void startListening() {
    _gameDocSub = _firestore
        .collection('games')
        .doc(_gameId)
        .snapshots()
        .listen((snapshot) {
      _lastGameDoc = snapshot;
      _emitState();
    });

    _handSub = _firestore
        .collection('games')
        .doc(_gameId)
        .collection('private')
        .doc(_myUid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        _myHandEncoded = List<String>.from(data['cards'] as List<dynamic>);
      }
      _emitState();
    });
  }

  void _emitState() {
    if (_lastGameDoc == null || !_lastGameDoc!.exists) return;
    _stateController.add(
      ClientGameState.fromMap(
        _lastGameDoc!.data()!,
        _myUid,
        _myHandEncoded,
      ),
    );
  }

  Future<void> sendBid(int bidAmount) async {
    await _functions
        .httpsCallable('placeBid')
        .call({'gameId': _gameId, 'bidAmount': bidAmount});
  }

  Future<void> sendPass() async {
    await _functions
        .httpsCallable('placeBid')
        .call({'gameId': _gameId, 'bidAmount': 0});
  }

  Future<void> sendTrumpSelection(String suit) async {
    await _functions
        .httpsCallable('selectTrump')
        .call({'gameId': _gameId, 'suit': suit});
  }

  Future<void> sendPlayCard(String cardCode) async {
    await _functions
        .httpsCallable('playCard')
        .call({'gameId': _gameId, 'card': cardCode});
  }

  void dispose() {
    _gameDocSub?.cancel();
    _handSub?.cancel();
    _stateController.close();
  }
}
