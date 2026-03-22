# Flutter Client Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter app shell — Firebase Auth, matchmaking service, game service (Firestore subscriptions), navigation, and client-side game state model. No Flame rendering yet — just the service layer and screen scaffolds.

**Architecture:** Flutter app with service classes wrapping Firebase SDK calls. Screens are placeholder widgets that will host Flame components in Plan 4. State management via streams from Firestore snapshots mapped to typed Dart models.

**Tech Stack:** Flutter 3.x, Firebase Auth, Cloud Firestore, Firebase Messaging (FCM), `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `cloud_functions`

**Spec:** `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md`

**Depends on:** Plan 1 (shared game logic models used for client-side state), Plan 2 (Cloud Functions the client calls)

---

## File Structure

```
lib/
  main.dart
  app/
    app.dart                      # MaterialApp, routing
    screens/
      home_screen.dart            # Main menu
      matchmaking_screen.dart     # Queue UI, waiting animation
      game_screen.dart            # Placeholder for Flame GameWidget
    services/
      auth_service.dart           # Firebase Auth wrapper
      matchmaking_service.dart    # Queue join/leave, FCM listener
      game_service.dart           # Firestore game doc + hand subscription
    models/
      player.dart                 # Player profile model
      client_game_state.dart      # Client-side game state from Firestore snapshots
    widgets/
      loading_indicator.dart      # Shared loading widget

test/
  app/
    services/
      auth_service_test.dart
      matchmaking_service_test.dart
      game_service_test.dart
    models/
      client_game_state_test.dart
```

---

### Task 1: Firebase Integration Setup

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app/app.dart`

- [ ] **Step 1: Add Firebase dependencies to pubspec.yaml**

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  cloud_functions: ^5.0.0
  firebase_messaging: ^15.0.0
```

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: No errors

- [ ] **Step 3: Implement main.dart with Firebase init**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const KoutApp());
}
```

- [ ] **Step 4: Implement app.dart with route scaffold**

```dart
// lib/app/app.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/game_screen.dart';

class KoutApp extends StatelessWidget {
  const KoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bahraini Kout',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF3B2314),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/matchmaking': (_) => const MatchmakingScreen(),
        '/game': (_) => const GameScreen(),
      },
    );
  }
}
```

- [ ] **Step 5: Create placeholder screens**

```dart
// lib/app/screens/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bahraini Kout', style: TextStyle(fontSize: 32, color: Color(0xFFF5ECD7))),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/matchmaking'),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Similar stubs for `matchmaking_screen.dart` and `game_screen.dart`.

- [ ] **Step 6: Verify build compiles**

Run: `flutter build apk --debug --target-platform android-arm64`
Expected: Build succeeds (may need `google-services.json` — use a placeholder for now)

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/app/ pubspec.yaml
git commit -m "feat: scaffold Flutter app with Firebase init, routing, and placeholder screens"
```

---

### Task 2: Auth Service

**Files:**
- Create: `lib/app/services/auth_service.dart`
- Create: `test/app/services/auth_service_test.dart`

- [ ] **Step 1: Write auth service tests**

Tests: signInAnonymously returns user, signInWithGoogle returns user, signOut clears current user, currentUser stream emits on auth state change.

- [ ] **Step 2: Implement auth service**

```dart
// lib/app/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  Future<void> signOut() => _auth.signOut();
}
```

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add lib/app/services/auth_service.dart test/app/services/
git commit -m "feat: add auth service wrapping Firebase Auth"
```

---

### Task 3: Client Game State Model

**Files:**
- Create: `lib/app/models/client_game_state.dart`
- Create: `lib/app/models/player.dart`
- Create: `test/app/models/client_game_state_test.dart`

- [ ] **Step 1: Write client game state tests**

Tests: fromFirestore parses all fields correctly, handles null currentTrick, handles missing biddingState, team helper methods work, isMyTurn check works.

- [ ] **Step 2: Implement client game state**

```dart
// lib/app/models/client_game_state.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/card.dart';
import '../../shared/models/game_state.dart';
import '../../shared/models/bid.dart';

class ClientGameState {
  final GamePhase phase;
  final List<String> playerUids;
  final Map<Team, int> scores;
  final Map<Team, int> tricks;
  final String? currentPlayerUid;
  final String dealerUid;
  final Suit? trumpSuit;
  final BidAmount? currentBid;
  final String? bidderUid;
  final List<({String playerUid, GameCard card})> currentTrickPlays;
  final List<GameCard> myHand;
  final String myUid;

  ClientGameState({
    required this.phase,
    required this.playerUids,
    required this.scores,
    required this.tricks,
    required this.currentPlayerUid,
    required this.dealerUid,
    required this.trumpSuit,
    required this.currentBid,
    required this.bidderUid,
    required this.currentTrickPlays,
    required this.myHand,
    required this.myUid,
  });

  bool get isMyTurn => currentPlayerUid == myUid;

  int get mySeatIndex => playerUids.indexOf(myUid);

  Team get myTeam => teamForSeat(mySeatIndex);

  factory ClientGameState.fromFirestore({
    required DocumentSnapshot<Map<String, dynamic>> gameDoc,
    required List<GameCard> hand,
    required String myUid,
  }) {
    final data = gameDoc.data()!;
    final players = List<String>.from(data['players']);

    final trickPlays = <({String playerUid, GameCard card})>[];
    if (data['currentTrick'] != null) {
      final plays = List<Map<String, dynamic>>.from(data['currentTrick']['plays'] ?? []);
      for (final play in plays) {
        trickPlays.add((
          playerUid: play['player'] as String,
          card: GameCard.decode(play['card'] as String),
        ));
      }
    }

    final bidAmount = data['bid'] != null
        ? BidAmount.fromValue(data['bid']['amount'] as int)
        : null;

    final trumpStr = data['trumpSuit'] as String?;
    final trumpSuit = trumpStr != null ? _parseSuit(trumpStr) : null;

    return ClientGameState(
      phase: _parsePhase(data['phase'] as String),
      playerUids: players,
      scores: {
        Team.a: (data['scores']?['teamA'] as int?) ?? 0,
        Team.b: (data['scores']?['teamB'] as int?) ?? 0,
      },
      tricks: {
        Team.a: (data['tricks']?['teamA'] as int?) ?? 0,
        Team.b: (data['tricks']?['teamB'] as int?) ?? 0,
      },
      currentPlayerUid: data['currentPlayer'] as String?,
      dealerUid: data['dealer'] as String,
      trumpSuit: trumpSuit,
      currentBid: bidAmount,
      bidderUid: data['bid']?['player'] as String?,
      currentTrickPlays: trickPlays,
      myHand: hand,
      myUid: myUid,
    );
  }

  static GamePhase _parsePhase(String phase) => switch (phase) {
    'WAITING' => GamePhase.waiting,
    'DEALING' => GamePhase.dealing,
    'BIDDING' => GamePhase.bidding,
    'TRUMP_SELECTION' => GamePhase.trumpSelection,
    'PLAYING' => GamePhase.playing,
    'ROUND_SCORING' => GamePhase.roundScoring,
    'GAME_OVER' => GamePhase.gameOver,
    _ => throw ArgumentError('Unknown phase: $phase'),
  };

  static Suit _parseSuit(String suit) => switch (suit) {
    'spades' => Suit.spades,
    'hearts' => Suit.hearts,
    'clubs' => Suit.clubs,
    'diamonds' => Suit.diamonds,
    _ => throw ArgumentError('Unknown suit: $suit'),
  };
}
```

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add lib/app/models/ test/app/models/
git commit -m "feat: add client game state model with Firestore deserialization"
```

---

### Task 4: Game Service (Firestore Subscriptions + Cloud Function Calls)

**Files:**
- Create: `lib/app/services/game_service.dart`
- Create: `test/app/services/game_service_test.dart`

- [ ] **Step 1: Write game service tests**

Tests: subscribes to game doc, subscribes to private hand doc, merges both streams into ClientGameState, sendBid calls placeBid function, sendTrumpSelection calls selectTrump function, sendPlayCard calls playCard function.

- [ ] **Step 2: Implement game service**

```dart
// lib/app/services/game_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../shared/models/card.dart';
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
  List<GameCard> _myHand = [];

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
        _myHand = (data['cards'] as List<dynamic>)
            .map((c) => GameCard.decode(c as String))
            .toList();
      }
      _emitState();
    });
  }

  void _emitState() {
    if (_lastGameDoc == null || !_lastGameDoc!.exists) return;
    _stateController.add(ClientGameState.fromFirestore(
      gameDoc: _lastGameDoc!,
      hand: _myHand,
      myUid: _myUid,
    ));
  }

  Future<void> sendBid(int bidAmount) async {
    await _functions.httpsCallable('placeBid').call({
      'gameId': _gameId,
      'bidAmount': bidAmount,
    });
  }

  Future<void> sendPass() async {
    await _functions.httpsCallable('placeBid').call({
      'gameId': _gameId,
      'bidAmount': 0,
    });
  }

  Future<void> sendTrumpSelection(String suit) async {
    await _functions.httpsCallable('selectTrump').call({
      'gameId': _gameId,
      'suit': suit,
    });
  }

  Future<void> sendPlayCard(String cardCode) async {
    await _functions.httpsCallable('playCard').call({
      'gameId': _gameId,
      'card': cardCode,
    });
  }

  void dispose() {
    _gameDocSub?.cancel();
    _handSub?.cancel();
    _stateController.close();
  }
}
```

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add lib/app/services/game_service.dart test/app/services/
git commit -m "feat: add game service with Firestore subscriptions and Cloud Function calls"
```

---

### Task 5: Matchmaking Service

**Files:**
- Create: `lib/app/services/matchmaking_service.dart`
- Create: `test/app/services/matchmaking_service_test.dart`

- [ ] **Step 1: Write matchmaking service tests**

Tests: joinQueue calls Cloud Function, leaveQueue calls Cloud Function, listenForMatch subscribes to user's games query and emits gameId.

- [ ] **Step 2: Implement matchmaking service**

```dart
// lib/app/services/matchmaking_service.dart
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
    await _functions.httpsCallable('joinQueue').call({
      'eloRating': eloRating,
    });
  }

  Future<void> leaveQueue() async {
    await _functions.httpsCallable('leaveQueue').call();
  }

  /// Listens for a game where this player is a participant and phase is WAITING.
  /// Returns the gameId when a match is found.
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
```

- [ ] **Step 3: Run tests**
- [ ] **Step 4: Commit**

```bash
git add lib/app/services/matchmaking_service.dart test/app/services/
git commit -m "feat: add matchmaking service with queue management and match detection"
```

---

### Task 6: Wire Screens to Services

**Files:**
- Modify: `lib/app/screens/home_screen.dart`
- Modify: `lib/app/screens/matchmaking_screen.dart`
- Modify: `lib/app/screens/game_screen.dart`

- [ ] **Step 1: Update home screen with auth**

Add anonymous sign-in on launch, show Play button when authenticated.

- [ ] **Step 2: Update matchmaking screen**

Join queue on enter, show "Searching for opponents..." with loading animation, navigate to `/game` when match found.

- [ ] **Step 3: Update game screen**

Create `GameService` with the matched `gameId`, subscribe to state stream, show phase-dependent placeholder text (will be replaced by Flame in Plan 4).

- [ ] **Step 4: Run app on emulator to verify flow**

Run: `flutter run`
Expected: App launches → anonymous auth → tap Play → matchmaking screen → (would need 4 clients to match, so just verify no crashes)

- [ ] **Step 5: Commit**

```bash
git add lib/app/screens/
git commit -m "feat: wire screens to auth, matchmaking, and game services"
```

---

### Task 7: Presence Heartbeat Service

**Files:**
- Create: `lib/app/services/presence_service.dart`
- Create: `test/app/services/presence_service_test.dart`

- [ ] **Step 1: Write presence service tests**

Tests: starts writing heartbeat every 30 seconds, stops on dispose, writes to correct Firestore path `games/{gameId}/presence/{uid}`, reconnects and resumes heartbeat after app returns to foreground.

- [ ] **Step 2: Implement presence service**

```dart
// lib/app/services/presence_service.dart
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

  DocumentReference get _presenceRef =>
      _firestore.collection('games').doc(_gameId).collection('presence').doc(_myUid);

  /// Start sending heartbeats every 30 seconds.
  void start() {
    _writeHeartbeat(); // immediate first write
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _writeHeartbeat(),
    );
  }

  Future<void> _writeHeartbeat() async {
    await _presenceRef.set({
      'uid': _myUid,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Stop heartbeats (e.g., on game end or app background).
  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Remove presence doc (clean disconnect).
  Future<void> disconnect() async {
    stop();
    await _presenceRef.delete();
  }

  void dispose() {
    stop();
  }
}
```

- [ ] **Step 3: Wire into GameScreen**

Start `PresenceService` when game screen mounts, stop on dispose. Also listen to `AppLifecycleState` to pause/resume heartbeats on app background/foreground.

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

```bash
git add lib/app/services/presence_service.dart test/app/services/ lib/app/screens/game_screen.dart
git commit -m "feat: add presence heartbeat service with 30-second interval and lifecycle management"
```

---

## Summary

7 tasks. Produces:
- Flutter app shell with Firebase integration
- Auth service (anonymous + future Google Sign-In)
- Matchmaking service (queue join/leave, match detection via Firestore query)
- Game service (dual Firestore subscription, Cloud Function calls for all game actions)
- Client game state model (Firestore → typed Dart)
- Screen scaffolds wired to services (ready for Flame overlay in Plan 4)
