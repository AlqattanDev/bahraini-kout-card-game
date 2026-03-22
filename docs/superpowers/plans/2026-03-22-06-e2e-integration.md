# E2E Integration & Final Verification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire all layers together, run end-to-end tests, handle disconnect scenarios, and verify the complete game flow from matchmaking through game over.

**Architecture:** Integration layer connecting Flutter client (Plans 3-5) to Firebase backend (Plan 2) with shared game logic (Plan 1). E2E tests use Firebase Emulator Suite with 4 simulated clients.

**Tech Stack:** Flutter integration tests, Firebase Emulator Suite, Dart test runner

**Spec:** `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md`

**Depends on:** All previous plans (1-5)

---

## File Structure

```
test/
  e2e/
    full_game_e2e_test.dart         # 4-client full game flow
    matchmaking_e2e_test.dart       # Queue → match → game created
    disconnect_e2e_test.dart        # Disconnect scenarios
    malzoom_e2e_test.dart           # Malzoom full flow
    kout_e2e_test.dart              # Kout instant win/loss
    poison_joker_e2e_test.dart      # Poison joker trigger
  integration/
    client_server_sync_test.dart    # Verify Firestore → ClientGameState mapping

scripts/
  run_e2e.sh                        # Start emulators + run E2E tests
```

---

### Task 1: Emulator Test Harness

**Files:**
- Create: `scripts/run_e2e.sh`
- Create: `test/e2e/test_helpers.dart`

- [ ] **Step 1: Create emulator launch script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Start Firebase emulators and run E2E tests
firebase emulators:exec --only auth,firestore,functions \
  'flutter test test/e2e/ --concurrency=1'
```

- [ ] **Step 2: Create test helpers**

```dart
// test/e2e/test_helpers.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Configure Firebase SDKs to use local emulators.
Future<void> setupEmulators() async {
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}

/// Create an authenticated test user.
Future<String> createTestUser(FirebaseAuth auth, String email) async {
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: 'test123456',
  );
  return credential.user!.uid;
}

/// Helper to call a Cloud Function and return result.
Future<dynamic> callFunction(String name, Map<String, dynamic> data) async {
  final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return result.data;
}
```

- [ ] **Step 3: Commit**

```bash
git add scripts/run_e2e.sh test/e2e/test_helpers.dart
chmod +x scripts/run_e2e.sh
git commit -m "feat: add E2E test harness with emulator setup and test helpers"
```

---

### Task 2: Matchmaking E2E Test

**Files:**
- Create: `test/e2e/matchmaking_e2e_test.dart`

- [ ] **Step 1: Write matchmaking E2E test**

```dart
// test/e2e/matchmaking_e2e_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupEmulators();
  });

  test('4 players queue → matchmaking creates game → all 4 are players', () async {
    // Create 4 test users
    final uids = <String>[];
    for (var i = 0; i < 4; i++) {
      final uid = await createTestUser(
        FirebaseAuth.instance,
        'player$i@test.com',
      );
      uids.add(uid);
    }

    // All 4 join queue
    for (final uid in uids) {
      await callFunction('joinQueue', {'eloRating': 1000});
    }

    // Wait for matchmaking trigger to fire
    await Future.delayed(const Duration(seconds: 3));

    // Verify a game was created with all 4 players
    final games = await FirebaseFirestore.instance
        .collection('games')
        .where('players', arrayContains: uids[0])
        .get();

    expect(games.docs.length, 1);
    final gameData = games.docs.first.data();
    expect(gameData['players'].length, 4);
    expect(gameData['phase'], 'WAITING');

    // Verify queue is empty
    final queue = await FirebaseFirestore.instance
        .collection('matchmaking_queue')
        .get();
    expect(queue.docs.length, 0);

    // Verify each player has a private hand doc
    for (final uid in uids) {
      final handDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(games.docs.first.id)
          .collection('private')
          .doc(uid)
          .get();
      expect(handDoc.exists, true);
      expect((handDoc.data()!['cards'] as List).length, 8);
    }
  });
}
```

- [ ] **Step 2: Run test with emulators**

Run: `./scripts/run_e2e.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/e2e/matchmaking_e2e_test.dart
git commit -m "test: add matchmaking E2E test — 4 players queue to game creation"
```

---

### Task 3: Full Game E2E Test

**Files:**
- Create: `test/e2e/full_game_e2e_test.dart`

- [ ] **Step 1: Write full game flow test**

Simulates: 4 players match → deal → player 1 bids 5, others pass → player 1 selects trump → 8 tricks played (each player plays a valid card from their hand) → round scored → verify scores updated.

This is the critical test — it exercises the entire backend through a complete game round.

- [ ] **Step 2: Run test**

Run: `./scripts/run_e2e.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/e2e/full_game_e2e_test.dart
git commit -m "test: add full game E2E test — matchmaking through scoring"
```

---

### Task 4: Edge Case E2E Tests

**Files:**
- Create: `test/e2e/malzoom_e2e_test.dart`
- Create: `test/e2e/kout_e2e_test.dart`
- Create: `test/e2e/poison_joker_e2e_test.dart`

- [ ] **Step 1: Write Malzoom E2E test**

All 4 pass → verify reshuffle (new hands dealt, reshuffleCount=1) → all 4 pass again → verify dealer forced to bid 5 → game continues normally.

- [ ] **Step 2: Write Kout E2E test**

Player bids 8 (Kout) → wins all 8 tricks → verify GAME_OVER with winner score ≥ 31.
Player bids 8 (Kout) → loses 1 trick → verify GAME_OVER with opponent score ≥ 31.

- [ ] **Step 3: Write Poison Joker E2E test**

Set up a game state where a player's last card is the Joker → call playCard → verify round ends with +10 to opponent, no card played.

- [ ] **Step 4: Run all E2E tests**

Run: `./scripts/run_e2e.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add test/e2e/
git commit -m "test: add E2E tests for malzoom, kout, and poison joker edge cases"
```

---

### Task 5: Disconnect Handling E2E Test

**Files:**
- Create: `test/e2e/disconnect_e2e_test.dart`

- [ ] **Step 1: Write disconnect during bidding test**

Player stops sending heartbeats → presence TTL expires → after 90s timeout → verify game forfeited with appropriate penalty.

Note: In emulator tests, we can directly delete the presence doc to simulate TTL expiry.

- [ ] **Step 2: Write disconnect during play test**

Same flow but during PLAYING phase — verify the current bid's failure penalty is applied.

- [ ] **Step 3: Write reconnection test**

Player disconnects → reconnects within 90s → verify game continues normally.

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

```bash
git add test/e2e/disconnect_e2e_test.dart
git commit -m "test: add disconnect handling E2E tests — forfeit and reconnection"
```

---

### Task 6: Client-Server Sync Verification

**Files:**
- Create: `test/integration/client_server_sync_test.dart`

- [ ] **Step 1: Write sync verification test**

Verifies that `ClientGameState.fromFirestore` correctly maps every field from a real Firestore game document. Creates a game via Cloud Functions, then reads the Firestore doc and constructs a `ClientGameState` from it, asserting all fields are correct.

- [ ] **Step 2: Run test**
- [ ] **Step 3: Commit**

```bash
git add test/integration/
git commit -m "test: add client-server sync verification test"
```

---

### Task 7: Final Full Suite Run & Cleanup

- [ ] **Step 1: Run complete Dart test suite**

Run: `flutter test`
Expected: All PASS

- [ ] **Step 2: Run complete Cloud Functions test suite**

Run: `cd functions && npm run test:emulator`
Expected: All PASS

- [ ] **Step 3: Run E2E tests**

Run: `./scripts/run_e2e.sh`
Expected: All PASS

- [ ] **Step 4: Verify app builds for both platforms**

```bash
flutter build apk --release
flutter build ios --release --no-codesign
```
Expected: Both build successfully

- [ ] **Step 5: Commit any final fixes**

```bash
git add .
git commit -m "chore: final cleanup and verification — all tests passing, both platforms build"
```

---

## Summary

7 tasks. Produces:
- E2E test harness with Firebase Emulator integration
- Matchmaking E2E test
- Full game flow E2E test (deal → bid → play → score)
- Edge case E2E tests (Malzoom, Kout, Poison Joker)
- Disconnect handling E2E tests
- Client-server sync verification
- Final build verification for iOS and Android
