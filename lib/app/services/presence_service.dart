import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  final FirebaseFirestore _firestore;
  final String _gameId;
  final String _myUid;
  Timer? _heartbeatTimer;

  PresenceService({
    required String gameId,
    required String myUid,
    FirebaseFirestore? firestore,
  })  : _gameId = gameId,
        _myUid = myUid,
        _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference get _presenceRef => _firestore
      .collection('games')
      .doc(_gameId)
      .collection('presence')
      .doc(_myUid);

  void start() {
    _writeHeartbeat();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _writeHeartbeat());
  }

  Future<void> _writeHeartbeat() async {
    await _presenceRef
        .set({'uid': _myUid, 'lastSeen': FieldValue.serverTimestamp()});
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> disconnect() async {
    stop();
    await _presenceRef.delete();
  }

  void dispose() {
    stop();
  }
}
