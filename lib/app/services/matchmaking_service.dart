import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchmakingService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final String _myUid;

  MatchmakingService({
    required String myUid,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _myUid = myUid,
        _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> joinQueue(int eloRating) async {
    await _functions.httpsCallable('joinQueue').call({'eloRating': eloRating});
  }

  Future<void> leaveQueue() async {
    await _functions.httpsCallable('leaveQueue').call();
  }

  Stream<String> listenForMatch() {
    return _firestore
        .collection('games')
        .where('players', arrayContains: _myUid)
        .where('phase', isEqualTo: 'WAITING')
        .orderBy('metadata.createdAt', descending: true)
        .limit(1)
        .snapshots()
        .where((snapshot) => snapshot.docs.isNotEmpty)
        .map((snapshot) => snapshot.docs.first.id);
  }
}
