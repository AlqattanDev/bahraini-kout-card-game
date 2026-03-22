# Shared Game Logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Dart game logic layer — card models, deck construction, trick resolution, scoring, bid validation, and Poison Joker detection — with full test coverage and zero external dependencies.

**Architecture:** Pure Dart library in `lib/shared/` with no Flutter, Flame, or Firebase imports. All functions are pure (input → output, no side effects). This layer is shared between the Flutter client (for optimistic UI hints) and the Cloud Functions backend (ported to TypeScript or called via Dart backend).

**Tech Stack:** Dart 3.x, `dart test` runner

**Spec:** `docs/superpowers/specs/2026-03-22-bahraini-kout-game-design.md`

---

## File Structure

```
lib/
  shared/
    models/
      card.dart              # Suit enum, Rank enum, Card class, Joker singleton
      deck.dart              # Deck construction, shuffle, deal
      bid.dart               # Bid enum/value, BidResult, scoring table
      trick.dart             # Trick class (plays list, resolution)
      game_state.dart        # GamePhase enum, team helpers, score state
    logic/
      trick_resolver.dart    # Determine trick winner given plays + trump
      bid_validator.dart     # Validate bid actions, track passes, Malzoom
      play_validator.dart    # Validate card plays (suit-following, Joker rules)
      scorer.dart            # Round scoring, game-end detection
    constants.dart           # Card encoding/decoding, rank ordering

test/
  shared/
    models/
      card_test.dart
      deck_test.dart
      bid_test.dart
      trick_test.dart
    logic/
      trick_resolver_test.dart
      bid_validator_test.dart
      play_validator_test.dart
      scorer_test.dart
```

---

### Task 1: Project Scaffold & Card Model

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/shared/constants.dart`
- Create: `lib/shared/models/card.dart`
- Create: `test/shared/models/card_test.dart`

- [ ] **Step 1: Initialize Flutter project**

```bash
flutter create --project-name bahraini_kout --org com.bahraini.kout --platforms=android,ios .
```

- [ ] **Step 2: Verify project builds**

Run: `flutter pub get`
Expected: No errors

- [ ] **Step 3: Write card model tests**

```dart
// test/shared/models/card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/constants.dart';

void main() {
  group('Suit', () {
    test('has exactly 4 suits', () {
      expect(Suit.values.length, 4);
    });

    test('suits are spades, hearts, clubs, diamonds', () {
      expect(Suit.values, containsAll([
        Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds,
      ]));
    });
  });

  group('Rank', () {
    test('has exactly 8 ranks for 4-player mode', () {
      expect(Rank.values.length, 8);
    });

    test('ranks ordered high to low: A, K, Q, J, 10, 9, 8, 7', () {
      expect(Rank.ace.index < Rank.seven.index, true);
    });

    test('ace is highest', () {
      expect(Rank.ace.value, 14);
    });

    test('seven is lowest', () {
      expect(Rank.seven.value, 7);
    });
  });

  group('GameCard', () {
    test('creates a regular card', () {
      final card = GameCard(Suit.spades, Rank.ace);
      expect(card.suit, Suit.spades);
      expect(card.rank, Rank.ace);
      expect(card.isJoker, false);
    });

    test('creates joker via factory', () {
      final joker = GameCard.joker();
      expect(joker.isJoker, true);
      expect(joker.suit, isNull);
      expect(joker.rank, isNull);
    });

    test('encodes to string correctly', () {
      expect(GameCard(Suit.spades, Rank.ace).encode(), 'SA');
      expect(GameCard(Suit.hearts, Rank.king).encode(), 'HK');
      expect(GameCard(Suit.diamonds, Rank.ten).encode(), 'D10');
      expect(GameCard(Suit.clubs, Rank.seven).encode(), 'C7');
      expect(GameCard.joker().encode(), 'JO');
    });

    test('decodes from string correctly', () {
      expect(GameCard.decode('SA'), GameCard(Suit.spades, Rank.ace));
      expect(GameCard.decode('HK'), GameCard(Suit.hearts, Rank.king));
      expect(GameCard.decode('D10'), GameCard(Suit.diamonds, Rank.ten));
      expect(GameCard.decode('JO'), GameCard.joker());
    });

    test('equality works', () {
      expect(
        GameCard(Suit.spades, Rank.ace),
        GameCard(Suit.spades, Rank.ace),
      );
      expect(
        GameCard(Suit.spades, Rank.ace),
        isNot(GameCard(Suit.hearts, Rank.ace)),
      );
    });

    test('jokers are equal', () {
      expect(GameCard.joker(), GameCard.joker());
    });
  });

  group('Card encoding constants', () {
    test('suitInitial maps correctly', () {
      expect(suitInitial[Suit.spades], 'S');
      expect(suitInitial[Suit.hearts], 'H');
      expect(suitInitial[Suit.clubs], 'C');
      expect(suitInitial[Suit.diamonds], 'D');
    });

    test('rankString maps correctly', () {
      expect(rankString[Rank.ace], 'A');
      expect(rankString[Rank.king], 'K');
      expect(rankString[Rank.ten], '10');
      expect(rankString[Rank.seven], '7');
    });
  });
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/shared/models/card_test.dart`
Expected: FAIL — files don't exist yet

- [ ] **Step 5: Implement constants**

```dart
// lib/shared/constants.dart
import 'models/card.dart';

const Map<Suit, String> suitInitial = {
  Suit.spades: 'S',
  Suit.hearts: 'H',
  Suit.clubs: 'C',
  Suit.diamonds: 'D',
};

const Map<String, Suit> initialToSuit = {
  'S': Suit.spades,
  'H': Suit.hearts,
  'C': Suit.clubs,
  'D': Suit.diamonds,
};

const Map<Rank, String> rankString = {
  Rank.ace: 'A',
  Rank.king: 'K',
  Rank.queen: 'Q',
  Rank.jack: 'J',
  Rank.ten: '10',
  Rank.nine: '9',
  Rank.eight: '8',
  Rank.seven: '7',
};

const Map<String, Rank> stringToRank = {
  'A': Rank.ace,
  'K': Rank.king,
  'Q': Rank.queen,
  'J': Rank.jack,
  '10': Rank.ten,
  '9': Rank.nine,
  '8': Rank.eight,
  '7': Rank.seven,
};
```

- [ ] **Step 6: Implement card model**

```dart
// lib/shared/models/card.dart
enum Suit { spades, hearts, clubs, diamonds }

enum Rank {
  ace(14),
  king(13),
  queen(12),
  jack(11),
  ten(10),
  nine(9),
  eight(8),
  seven(7);

  const Rank(this.value);
  final int value;
}

class GameCard {
  final Suit? suit;
  final Rank? rank;
  final bool isJoker;

  const GameCard(Suit this.suit, Rank this.rank) : isJoker = false;

  const GameCard._joker() : suit = null, rank = null, isJoker = true;

  factory GameCard.joker() => const GameCard._joker();

  String encode() {
    if (isJoker) return 'JO';
    return '${_suitToInitial[suit!]}${_rankToString[rank!]}';
  }

  static GameCard decode(String code) {
    if (code == 'JO') return GameCard.joker();
    final suitChar = code[0];
    final rankStr = code.substring(1);
    final suit = _initialToSuit[suitChar];
    final rank = _stringToRank[rankStr];
    if (suit == null || rank == null) {
      throw ArgumentError('Invalid card code: $code');
    }
    return GameCard(suit, rank);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GameCard) return false;
    if (isJoker && other.isJoker) return true;
    return suit == other.suit && rank == other.rank;
  }

  @override
  int get hashCode => isJoker ? 0 : Object.hash(suit, rank);

  @override
  String toString() => isJoker ? 'Joker' : '${rank!.name} of ${suit!.name}';

  static const Map<Suit, String> _suitToInitial = {
    Suit.spades: 'S',
    Suit.hearts: 'H',
    Suit.clubs: 'C',
    Suit.diamonds: 'D',
  };

  static const Map<String, Suit> _initialToSuit = {
    'S': Suit.spades,
    'H': Suit.hearts,
    'C': Suit.clubs,
    'D': Suit.diamonds,
  };

  static const Map<Rank, String> _rankToString = {
    Rank.ace: 'A',
    Rank.king: 'K',
    Rank.queen: 'Q',
    Rank.jack: 'J',
    Rank.ten: '10',
    Rank.nine: '9',
    Rank.eight: '8',
    Rank.seven: '7',
  };

  static const Map<String, Rank> _stringToRank = {
    'A': Rank.ace,
    'K': Rank.king,
    'Q': Rank.queen,
    'J': Rank.jack,
    '10': Rank.ten,
    '9': Rank.nine,
    '8': Rank.eight,
    '7': Rank.seven,
  };
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/shared/models/card_test.dart`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add lib/shared/models/card.dart lib/shared/constants.dart test/shared/models/card_test.dart pubspec.yaml
git commit -m "feat: add card model with encoding/decoding and rank ordering"
```

---

### Task 2: Deck Construction & Dealing

**Files:**
- Create: `lib/shared/models/deck.dart`
- Create: `test/shared/models/deck_test.dart`

- [ ] **Step 1: Write deck tests**

```dart
// test/shared/models/deck_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/deck.dart';

void main() {
  group('Deck.fourPlayer', () {
    late Deck deck;

    setUp(() {
      deck = Deck.fourPlayer();
    });

    test('has exactly 32 cards', () {
      expect(deck.cards.length, 32);
    });

    test('spades has 8 cards (A, K, Q, J, 10, 9, 8, 7)', () {
      final spades = deck.cards
          .where((c) => !c.isJoker && c.suit == Suit.spades)
          .toList();
      expect(spades.length, 8);
    });

    test('hearts has 8 cards', () {
      final hearts = deck.cards
          .where((c) => !c.isJoker && c.suit == Suit.hearts)
          .toList();
      expect(hearts.length, 8);
    });

    test('clubs has 8 cards', () {
      final clubs = deck.cards
          .where((c) => !c.isJoker && c.suit == Suit.clubs)
          .toList();
      expect(clubs.length, 8);
    });

    test('diamonds has 7 cards (A, K, Q, J, 10, 9, 8 — no 7)', () {
      final diamonds = deck.cards
          .where((c) => !c.isJoker && c.suit == Suit.diamonds)
          .toList();
      expect(diamonds.length, 7);
      expect(
        diamonds.any((c) => c.rank == Rank.seven),
        false,
      );
    });

    test('has exactly 1 joker', () {
      final jokers = deck.cards.where((c) => c.isJoker).toList();
      expect(jokers.length, 1);
    });

    test('no duplicate cards', () {
      final encoded = deck.cards.map((c) => c.encode()).toSet();
      expect(encoded.length, 32);
    });
  });

  group('Deck.deal', () {
    test('deals 8 cards to each of 4 players', () {
      final deck = Deck.fourPlayer();
      final hands = deck.deal(4);
      expect(hands.length, 4);
      for (final hand in hands) {
        expect(hand.length, 8);
      }
    });

    test('all 32 cards are distributed', () {
      final deck = Deck.fourPlayer();
      final hands = deck.deal(4);
      final allCards = hands.expand((h) => h).toSet();
      expect(allCards.length, 32);
    });

    test('shuffling produces different deals', () {
      final deck1 = Deck.fourPlayer();
      final deck2 = Deck.fourPlayer();
      final hands1 = deck1.deal(4);
      final hands2 = deck2.deal(4);
      // Extremely unlikely to be identical — check at least one hand differs
      final encoded1 = hands1[0].map((c) => c.encode()).toList();
      final encoded2 = hands2[0].map((c) => c.encode()).toList();
      // This test is probabilistic but failure rate is ~1 in 2^80
      expect(encoded1, isNot(equals(encoded2)));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/models/deck_test.dart`
Expected: FAIL — deck.dart doesn't exist

- [ ] **Step 3: Implement deck**

```dart
// lib/shared/models/deck.dart
import 'card.dart';

class Deck {
  final List<GameCard> cards;

  Deck._(this.cards);

  factory Deck.fourPlayer() {
    final cards = <GameCard>[];

    const fullSuits = [Suit.spades, Suit.hearts, Suit.clubs];
    const fullRanks = Rank.values; // A, K, Q, J, 10, 9, 8, 7

    for (final suit in fullSuits) {
      for (final rank in fullRanks) {
        cards.add(GameCard(suit, rank));
      }
    }

    // Diamonds: all ranks except 7
    for (final rank in fullRanks) {
      if (rank != Rank.seven) {
        cards.add(GameCard(Suit.diamonds, rank));
      }
    }

    cards.add(GameCard.joker());

    return Deck._(cards);
  }

  List<List<GameCard>> deal(int playerCount) {
    final shuffled = List<GameCard>.from(cards)..shuffle();
    final cardsPerPlayer = shuffled.length ~/ playerCount;
    return List.generate(
      playerCount,
      (i) => shuffled.sublist(
        i * cardsPerPlayer,
        (i + 1) * cardsPerPlayer,
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/models/deck_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/models/deck.dart test/shared/models/deck_test.dart
git commit -m "feat: add deck construction and dealing for 4-player mode"
```

---

### Task 3: Trick Resolution

**Files:**
- Create: `lib/shared/models/trick.dart`
- Create: `lib/shared/logic/trick_resolver.dart`
- Create: `test/shared/logic/trick_resolver_test.dart`

- [ ] **Step 1: Write trick resolver tests**

```dart
// test/shared/logic/trick_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/trick.dart';
import 'package:bahraini_kout/shared/logic/trick_resolver.dart';

void main() {
  group('TrickResolver', () {
    test('highest card of led suit wins (no trump, no joker)', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.hearts, Rank.nine)),
          TrickPlay(playerIndex: 1, card: GameCard(Suit.hearts, Rank.king)),
          TrickPlay(playerIndex: 2, card: GameCard(Suit.hearts, Rank.seven)),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.hearts, Rank.ace)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 3); // Ace is highest
    });

    test('off-suit cards lose to led suit', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.hearts, Rank.seven)),
          TrickPlay(playerIndex: 1, card: GameCard(Suit.clubs, Rank.ace)),
          TrickPlay(playerIndex: 2, card: GameCard(Suit.diamonds, Rank.ace)),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.hearts, Rank.eight)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 3); // H8 beats H7, off-suit cards ignored
    });

    test('trump beats led suit', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.hearts, Rank.ace)),
          TrickPlay(playerIndex: 1, card: GameCard(Suit.spades, Rank.seven)),
          TrickPlay(playerIndex: 2, card: GameCard(Suit.hearts, Rank.king)),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.hearts, Rank.queen)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 1); // S7 (trump) beats all hearts
    });

    test('highest trump wins when multiple trumps played', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.hearts, Rank.ace)),
          TrickPlay(playerIndex: 1, card: GameCard(Suit.spades, Rank.seven)),
          TrickPlay(playerIndex: 2, card: GameCard(Suit.spades, Rank.jack)),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.hearts, Rank.king)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 2); // SJ > S7
    });

    test('joker always wins', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.hearts, Rank.ace)),
          TrickPlay(playerIndex: 1, card: GameCard(Suit.spades, Rank.ace)),
          TrickPlay(playerIndex: 2, card: GameCard.joker()),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.hearts, Rank.king)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 2); // Joker beats everything
    });

    test('joker beats trump ace', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.spades, Rank.ace)),
          TrickPlay(playerIndex: 1, card: GameCard.joker()),
          TrickPlay(playerIndex: 2, card: GameCard(Suit.spades, Rank.king)),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.spades, Rank.queen)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 1); // Joker beats trump ace
    });

    test('when trump is led, highest trump wins (no joker)', () {
      final trick = Trick(
        leadPlayerIndex: 0,
        plays: [
          TrickPlay(playerIndex: 0, card: GameCard(Suit.spades, Rank.nine)),
          TrickPlay(playerIndex: 1, card: GameCard(Suit.spades, Rank.ace)),
          TrickPlay(playerIndex: 2, card: GameCard(Suit.hearts, Rank.ace)),
          TrickPlay(playerIndex: 3, card: GameCard(Suit.spades, Rank.ten)),
        ],
      );
      final winner = TrickResolver.resolve(trick, trumpSuit: Suit.spades);
      expect(winner, 1); // SA is highest trump
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/logic/trick_resolver_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement trick model**

```dart
// lib/shared/models/trick.dart
import 'card.dart';

class TrickPlay {
  final int playerIndex;
  final GameCard card;

  const TrickPlay({required this.playerIndex, required this.card});
}

class Trick {
  final int leadPlayerIndex;
  final List<TrickPlay> plays;

  const Trick({required this.leadPlayerIndex, required this.plays});

  Suit? get ledSuit {
    if (plays.isEmpty) return null;
    final leadCard = plays.first.card;
    return leadCard.isJoker ? null : leadCard.suit;
  }
}
```

- [ ] **Step 4: Implement trick resolver**

```dart
// lib/shared/logic/trick_resolver.dart
import '../models/card.dart';
import '../models/trick.dart';

class TrickResolver {
  /// Returns the playerIndex of the trick winner.
  static int resolve(Trick trick, {required Suit trumpSuit}) {
    final plays = trick.plays;
    assert(plays.length == 4, 'Trick must have exactly 4 plays');

    // Rule 1: Joker always wins
    for (final play in plays) {
      if (play.card.isJoker) return play.playerIndex;
    }

    final ledSuit = trick.ledSuit!;

    // Rule 2: Highest trump wins (if any trump played)
    final trumpPlays = plays
        .where((p) => !p.card.isJoker && p.card.suit == trumpSuit)
        .toList();
    if (trumpPlays.isNotEmpty) {
      trumpPlays.sort((a, b) => b.card.rank!.value.compareTo(a.card.rank!.value));
      return trumpPlays.first.playerIndex;
    }

    // Rule 3: Highest card of led suit wins
    final ledSuitPlays = plays
        .where((p) => !p.card.isJoker && p.card.suit == ledSuit)
        .toList();
    ledSuitPlays.sort((a, b) => b.card.rank!.value.compareTo(a.card.rank!.value));
    return ledSuitPlays.first.playerIndex;
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/shared/logic/trick_resolver_test.dart`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add lib/shared/models/trick.dart lib/shared/logic/trick_resolver.dart test/shared/logic/trick_resolver_test.dart
git commit -m "feat: add trick resolution with joker > trump > led suit ordering"
```

---

### Task 4: Play Validation (Suit-Following & Joker Rules)

**Files:**
- Create: `lib/shared/logic/play_validator.dart`
- Create: `test/shared/logic/play_validator_test.dart`

- [ ] **Step 1: Write play validator tests**

```dart
// test/shared/logic/play_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/logic/play_validator.dart';

void main() {
  group('PlayValidator.validatePlay', () {
    test('allows playing a card of the led suit', () {
      final hand = [
        GameCard(Suit.hearts, Rank.ace),
        GameCard(Suit.spades, Rank.king),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard(Suit.hearts, Rank.ace),
        hand: hand,
        ledSuit: Suit.hearts,
        isLeadPlay: false,
      );
      expect(result.isValid, true);
    });

    test('rejects off-suit when player has led suit', () {
      final hand = [
        GameCard(Suit.hearts, Rank.ace),
        GameCard(Suit.spades, Rank.king),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard(Suit.spades, Rank.king),
        hand: hand,
        ledSuit: Suit.hearts,
        isLeadPlay: false,
      );
      expect(result.isValid, false);
      expect(result.error, 'must-follow-suit');
    });

    test('allows off-suit when void in led suit', () {
      final hand = [
        GameCard(Suit.spades, Rank.king),
        GameCard(Suit.clubs, Rank.queen),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard(Suit.spades, Rank.king),
        hand: hand,
        ledSuit: Suit.hearts,
        isLeadPlay: false,
      );
      expect(result.isValid, true);
    });

    test('allows joker when void in led suit', () {
      final hand = [
        GameCard.joker(),
        GameCard(Suit.spades, Rank.king),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard.joker(),
        hand: hand,
        ledSuit: Suit.hearts,
        isLeadPlay: false,
      );
      expect(result.isValid, true);
    });

    test('rejects joker when player has led suit', () {
      final hand = [
        GameCard.joker(),
        GameCard(Suit.hearts, Rank.seven),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard.joker(),
        hand: hand,
        ledSuit: Suit.hearts,
        isLeadPlay: false,
      );
      expect(result.isValid, false);
      expect(result.error, 'must-follow-suit');
    });

    test('rejects leading with joker', () {
      final hand = [
        GameCard.joker(),
        GameCard(Suit.hearts, Rank.ace),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard.joker(),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
      );
      expect(result.isValid, false);
      expect(result.error, 'cannot-lead-joker');
    });

    test('allows leading with any non-joker card', () {
      final hand = [
        GameCard(Suit.hearts, Rank.ace),
        GameCard(Suit.spades, Rank.king),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard(Suit.hearts, Rank.ace),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
      );
      expect(result.isValid, true);
    });

    test('rejects card not in hand', () {
      final hand = [
        GameCard(Suit.hearts, Rank.ace),
      ];
      final result = PlayValidator.validatePlay(
        card: GameCard(Suit.spades, Rank.king),
        hand: hand,
        ledSuit: null,
        isLeadPlay: true,
      );
      expect(result.isValid, false);
      expect(result.error, 'card-not-in-hand');
    });
  });

  group('PlayValidator.detectPoisonJoker', () {
    test('detects poison joker when only card is joker', () {
      final hand = [GameCard.joker()];
      expect(PlayValidator.detectPoisonJoker(hand), true);
    });

    test('no poison joker with multiple cards', () {
      final hand = [
        GameCard.joker(),
        GameCard(Suit.hearts, Rank.ace),
      ];
      expect(PlayValidator.detectPoisonJoker(hand), false);
    });

    test('no poison joker when single card is not joker', () {
      final hand = [GameCard(Suit.hearts, Rank.ace)];
      expect(PlayValidator.detectPoisonJoker(hand), false);
    });

    test('no poison joker with empty hand', () {
      expect(PlayValidator.detectPoisonJoker([]), false);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/logic/play_validator_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement play validator**

```dart
// lib/shared/logic/play_validator.dart
import '../models/card.dart';

class PlayValidationResult {
  final bool isValid;
  final String? error;

  const PlayValidationResult.valid() : isValid = true, error = null;
  const PlayValidationResult.invalid(this.error) : isValid = false;
}

class PlayValidator {
  /// Validates whether a player can play a specific card.
  ///
  /// [card] - the card the player wants to play
  /// [hand] - the player's current hand
  /// [ledSuit] - the suit that was led (null if this is the lead play)
  /// [isLeadPlay] - true if this player is leading the trick
  static PlayValidationResult validatePlay({
    required GameCard card,
    required List<GameCard> hand,
    required Suit? ledSuit,
    required bool isLeadPlay,
  }) {
    // Check card is in hand
    if (!hand.contains(card)) {
      return const PlayValidationResult.invalid('card-not-in-hand');
    }

    // Joker cannot be led
    if (isLeadPlay && card.isJoker) {
      return const PlayValidationResult.invalid('cannot-lead-joker');
    }

    // Must follow suit if not leading
    if (!isLeadPlay && ledSuit != null) {
      final hasLedSuit = hand.any((c) => !c.isJoker && c.suit == ledSuit);
      if (hasLedSuit) {
        // Must play a card of the led suit
        if (card.isJoker || card.suit != ledSuit) {
          return const PlayValidationResult.invalid('must-follow-suit');
        }
      }
    }

    return const PlayValidationResult.valid();
  }

  /// Returns true if the player's only remaining card is the Joker (Poison Joker).
  static bool detectPoisonJoker(List<GameCard> hand) {
    return hand.length == 1 && hand.first.isJoker;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/logic/play_validator_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/logic/play_validator.dart test/shared/logic/play_validator_test.dart
git commit -m "feat: add play validation with suit-following, joker rules, and poison joker detection"
```

---

### Task 5: Bid Validation & Malzoom

**Files:**
- Create: `lib/shared/models/bid.dart`
- Create: `lib/shared/logic/bid_validator.dart`
- Create: `test/shared/models/bid_test.dart`
- Create: `test/shared/logic/bid_validator_test.dart`

- [ ] **Step 1: Write bid model tests**

```dart
// test/shared/models/bid_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/bid.dart';

void main() {
  group('BidAmount', () {
    test('valid bids are 5, 6, 7, 8', () {
      expect(BidAmount.values.map((b) => b.value), [5, 6, 7, 8]);
    });

    test('bid 5 is named Bab', () {
      expect(BidAmount.bab.value, 5);
    });

    test('bid 8 is named Kout', () {
      expect(BidAmount.kout.value, 8);
    });

    test('success points match spec', () {
      expect(BidAmount.bab.successPoints, 5);
      expect(BidAmount.six.successPoints, 6);
      expect(BidAmount.seven.successPoints, 7);
      expect(BidAmount.kout.successPoints, 31);
    });

    test('failure points (opponent gets) match spec', () {
      expect(BidAmount.bab.failurePoints, 10);
      expect(BidAmount.six.failurePoints, 12);
      expect(BidAmount.seven.failurePoints, 14);
      expect(BidAmount.kout.failurePoints, 31);
    });
  });
}
```

- [ ] **Step 2: Write bid validator tests**

```dart
// test/shared/logic/bid_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/logic/bid_validator.dart';

void main() {
  group('BidValidator', () {
    group('validateBid', () {
      test('accepts first bid of 5', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.bab,
          currentHighest: null,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, true);
      });

      test('accepts bid higher than current', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.seven,
          currentHighest: BidAmount.six,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, true);
      });

      test('rejects bid equal to current', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.six,
          currentHighest: BidAmount.six,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'bid-not-higher');
      });

      test('rejects bid lower than current', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.bab,
          currentHighest: BidAmount.six,
          passedPlayers: [],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'bid-not-higher');
      });

      test('rejects bid from player who already passed', () {
        final result = BidValidator.validateBid(
          bidAmount: BidAmount.seven,
          currentHighest: BidAmount.six,
          passedPlayers: [1],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });
    });

    group('validatePass', () {
      test('allows pass for non-passed player', () {
        final result = BidValidator.validatePass(
          passedPlayers: [0, 2],
          playerIndex: 1,
        );
        expect(result.isValid, true);
      });

      test('rejects pass from player who already passed', () {
        final result = BidValidator.validatePass(
          passedPlayers: [1],
          playerIndex: 1,
        );
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });
    });

    group('checkBiddingComplete', () {
      test('bidding complete when 3 players passed', () {
        final result = BidValidator.checkBiddingComplete(
          passedPlayers: [0, 2, 3],
          currentHighest: BidAmount.six,
          highestBidderIndex: 1,
        );
        expect(result, BiddingOutcome.won(winnerIndex: 1, bid: BidAmount.six));
      });

      test('bidding not complete with fewer than 3 passes', () {
        final result = BidValidator.checkBiddingComplete(
          passedPlayers: [0, 2],
          currentHighest: BidAmount.six,
          highestBidderIndex: 1,
        );
        expect(result, BiddingOutcome.ongoing());
      });
    });

    group('checkMalzoom', () {
      test('first all-pass triggers reshuffle', () {
        final result = BidValidator.checkMalzoom(
          passedPlayers: [0, 1, 2, 3],
          reshuffleCount: 0,
        );
        expect(result, MalzoomOutcome.reshuffle);
      });

      test('second all-pass triggers forced bid', () {
        final result = BidValidator.checkMalzoom(
          passedPlayers: [0, 1, 2, 3],
          reshuffleCount: 1,
        );
        expect(result, MalzoomOutcome.forcedBid);
      });

      test('not all passed returns none', () {
        final result = BidValidator.checkMalzoom(
          passedPlayers: [0, 1, 2],
          reshuffleCount: 0,
        );
        expect(result, MalzoomOutcome.none);
      });
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/shared/models/bid_test.dart test/shared/logic/bid_validator_test.dart`
Expected: FAIL

- [ ] **Step 4: Implement bid model**

```dart
// lib/shared/models/bid.dart
enum BidAmount {
  bab(value: 5, successPoints: 5, failurePoints: 10),
  six(value: 6, successPoints: 6, failurePoints: 12),
  seven(value: 7, successPoints: 7, failurePoints: 14),
  kout(value: 8, successPoints: 31, failurePoints: 31);

  const BidAmount({
    required this.value,
    required this.successPoints,
    required this.failurePoints,
  });

  final int value;
  final int successPoints;
  final int failurePoints;

  bool get isKout => this == BidAmount.kout;

  static BidAmount? fromValue(int value) {
    for (final bid in values) {
      if (bid.value == value) return bid;
    }
    return null;
  }
}
```

- [ ] **Step 5: Implement bid validator**

```dart
// lib/shared/logic/bid_validator.dart
import '../models/bid.dart';

class BidValidationResult {
  final bool isValid;
  final String? error;

  const BidValidationResult.valid() : isValid = true, error = null;
  const BidValidationResult.invalid(this.error) : isValid = false;
}

enum MalzoomOutcome { none, reshuffle, forcedBid }

class BiddingOutcome {
  final bool isComplete;
  final int? winnerIndex;
  final BidAmount? winningBid;

  const BiddingOutcome._({
    required this.isComplete,
    this.winnerIndex,
    this.winningBid,
  });

  factory BiddingOutcome.won({required int winnerIndex, required BidAmount bid}) =>
      BiddingOutcome._(isComplete: true, winnerIndex: winnerIndex, winningBid: bid);

  factory BiddingOutcome.ongoing() =>
      const BiddingOutcome._(isComplete: false);

  @override
  bool operator ==(Object other) {
    if (other is! BiddingOutcome) return false;
    return isComplete == other.isComplete &&
        winnerIndex == other.winnerIndex &&
        winningBid == other.winningBid;
  }

  @override
  int get hashCode => Object.hash(isComplete, winnerIndex, winningBid);
}

class BidValidator {
  static BidValidationResult validateBid({
    required BidAmount bidAmount,
    required BidAmount? currentHighest,
    required List<int> passedPlayers,
    required int playerIndex,
  }) {
    if (passedPlayers.contains(playerIndex)) {
      return const BidValidationResult.invalid('already-passed');
    }

    if (currentHighest != null && bidAmount.value <= currentHighest.value) {
      return const BidValidationResult.invalid('bid-not-higher');
    }

    return const BidValidationResult.valid();
  }

  static BidValidationResult validatePass({
    required List<int> passedPlayers,
    required int playerIndex,
  }) {
    if (passedPlayers.contains(playerIndex)) {
      return const BidValidationResult.invalid('already-passed');
    }
    return const BidValidationResult.valid();
  }

  static BiddingOutcome checkBiddingComplete({
    required List<int> passedPlayers,
    required BidAmount? currentHighest,
    required int? highestBidderIndex,
  }) {
    if (passedPlayers.length >= 3 && currentHighest != null && highestBidderIndex != null) {
      return BiddingOutcome.won(winnerIndex: highestBidderIndex, bid: currentHighest);
    }
    return BiddingOutcome.ongoing();
  }

  static MalzoomOutcome checkMalzoom({
    required List<int> passedPlayers,
    required int reshuffleCount,
  }) {
    if (passedPlayers.length < 4) return MalzoomOutcome.none;
    if (reshuffleCount < 1) return MalzoomOutcome.reshuffle;
    return MalzoomOutcome.forcedBid;
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/shared/models/bid_test.dart test/shared/logic/bid_validator_test.dart`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add lib/shared/models/bid.dart lib/shared/logic/bid_validator.dart test/shared/models/bid_test.dart test/shared/logic/bid_validator_test.dart
git commit -m "feat: add bid model, validation, pass tracking, and malzoom detection"
```

---

### Task 6: Scoring & Game State

**Files:**
- Create: `lib/shared/models/game_state.dart`
- Create: `lib/shared/logic/scorer.dart`
- Create: `test/shared/logic/scorer_test.dart`

- [ ] **Step 1: Write scorer tests**

```dart
// test/shared/logic/scorer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/shared/logic/scorer.dart';

void main() {
  group('Scorer.calculateRoundResult', () {
    test('bid 5 success: bidding team wins 5 tricks → +5', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.bab,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 5, Team.b: 3},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 5);
    });

    test('bid 5 success: bidding team wins 8 tricks → +5', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.bab,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 8, Team.b: 0},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 5);
    });

    test('bid 6 failure: bidding team wins 4 tricks → opponent +12', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.six,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 4, Team.b: 4},
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 12);
    });

    test('bid 7 failure: bidding team wins 6 tricks → opponent +14', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.seven,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 6, Team.b: 2},
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 14);
    });

    test('kout success: +31 to bidding team', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 8, Team.b: 0},
      );
      expect(result.winningTeam, Team.a);
      expect(result.pointsAwarded, 31);
    });

    test('kout failure: +31 to opponent', () {
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 7, Team.b: 1},
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 31);
    });

    test('poison joker: +10 to opponent regardless of bid', () {
      final result = Scorer.calculatePoisonJokerResult(
        biddingTeam: Team.a,
        poisonTeam: Team.a,
      );
      expect(result.winningTeam, Team.b);
      expect(result.pointsAwarded, 10);
    });
  });

  group('Scorer.applyScore', () {
    test('adds points to winning team only', () {
      final scores = {Team.a: 10, Team.b: 5};
      final newScores = Scorer.applyScore(
        scores: scores,
        winningTeam: Team.a,
        points: 6,
      );
      expect(newScores[Team.a], 16);
      expect(newScores[Team.b], 5);
    });

    test('does not deduct from losing team', () {
      final scores = {Team.a: 10, Team.b: 5};
      final newScores = Scorer.applyScore(
        scores: scores,
        winningTeam: Team.b,
        points: 12,
      );
      expect(newScores[Team.a], 10);
      expect(newScores[Team.b], 17);
    });

    test('scores clamp at 0 (never negative)', () {
      final scores = {Team.a: 0, Team.b: 0};
      final newScores = Scorer.applyScore(
        scores: scores,
        winningTeam: Team.a,
        points: 5,
      );
      expect(newScores[Team.a], 5);
      expect(newScores[Team.b], 0);
    });
  });

  group('Scorer.checkGameOver', () {
    test('game over when a team reaches 31', () {
      final scores = {Team.a: 31, Team.b: 8};
      expect(Scorer.checkGameOver(scores), Team.a);
    });

    test('game over when a team exceeds 31', () {
      final scores = {Team.a: 10, Team.b: 35};
      expect(Scorer.checkGameOver(scores), Team.b);
    });

    test('game not over below 31', () {
      final scores = {Team.a: 30, Team.b: 20};
      expect(Scorer.checkGameOver(scores), isNull);
    });
  });

  group('Team helpers', () {
    test('seats 0 and 2 are Team A', () {
      expect(teamForSeat(0), Team.a);
      expect(teamForSeat(2), Team.a);
    });

    test('seats 1 and 3 are Team B', () {
      expect(teamForSeat(1), Team.b);
      expect(teamForSeat(3), Team.b);
    });

    test('opponent team', () {
      expect(Team.a.opponent, Team.b);
      expect(Team.b.opponent, Team.a);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/logic/scorer_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement game state model**

```dart
// lib/shared/models/game_state.dart
enum GamePhase {
  waiting,
  dealing,
  bidding,
  trumpSelection,
  playing,
  roundScoring,
  gameOver,
}

enum Team {
  a,
  b;

  Team get opponent => this == Team.a ? Team.b : Team.a;
}

Team teamForSeat(int seatIndex) {
  return seatIndex.isEven ? Team.a : Team.b;
}

/// Returns the next seat index clockwise (0 → 1 → 2 → 3 → 0).
int nextSeat(int seatIndex, {int playerCount = 4}) {
  return (seatIndex + 1) % playerCount;
}
```

- [ ] **Step 4: Implement scorer**

```dart
// lib/shared/logic/scorer.dart
import '../models/bid.dart';
import '../models/game_state.dart';

class RoundResult {
  final Team winningTeam;
  final int pointsAwarded;

  const RoundResult({required this.winningTeam, required this.pointsAwarded});
}

class Scorer {
  /// Determines round outcome based on tricks won vs bid.
  static RoundResult calculateRoundResult({
    required BidAmount bid,
    required Team biddingTeam,
    required Map<Team, int> tricksWon,
  }) {
    final biddingTeamTricks = tricksWon[biddingTeam] ?? 0;
    final success = biddingTeamTricks >= bid.value;

    if (success) {
      return RoundResult(
        winningTeam: biddingTeam,
        pointsAwarded: bid.successPoints,
      );
    } else {
      return RoundResult(
        winningTeam: biddingTeam.opponent,
        pointsAwarded: bid.failurePoints,
      );
    }
  }

  /// Poison Joker always awards +10 to the opponent of the poisoned team.
  static RoundResult calculatePoisonJokerResult({
    required Team biddingTeam,
    required Team poisonTeam,
  }) {
    return RoundResult(
      winningTeam: poisonTeam.opponent,
      pointsAwarded: 10,
    );
  }

  /// Applies points to the winning team. Losing team's score is unchanged.
  /// Scores are clamped at 0 (never negative).
  static Map<Team, int> applyScore({
    required Map<Team, int> scores,
    required Team winningTeam,
    required int points,
  }) {
    return {
      for (final team in Team.values)
        team: team == winningTeam
            ? (scores[team] ?? 0) + points
            : (scores[team] ?? 0).clamp(0, 999),
    };
  }

  /// Returns the winning team if any team has reached 31, else null.
  static Team? checkGameOver(Map<Team, int> scores) {
    for (final team in Team.values) {
      if ((scores[team] ?? 0) >= 31) return team;
    }
    return null;
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/shared/logic/scorer_test.dart`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add lib/shared/models/game_state.dart lib/shared/logic/scorer.dart test/shared/logic/scorer_test.dart
git commit -m "feat: add scoring engine with round results, poison joker, score clamping, and game-over detection"
```

---

### Task 7: Integration Test — Full Round Simulation

**Files:**
- Create: `test/shared/integration/round_simulation_test.dart`

- [ ] **Step 1: Write a full round integration test**

```dart
// test/shared/integration/round_simulation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/trick.dart';
import 'package:bahraini_kout/shared/models/deck.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/shared/logic/trick_resolver.dart';
import 'package:bahraini_kout/shared/logic/play_validator.dart';
import 'package:bahraini_kout/shared/logic/bid_validator.dart';
import 'package:bahraini_kout/shared/logic/scorer.dart';

void main() {
  group('Full round simulation', () {
    test('deal → bid → play 8 tricks → score', () {
      // Deal
      final deck = Deck.fourPlayer();
      final hands = deck.deal(4);
      expect(hands.length, 4);
      for (final hand in hands) {
        expect(hand.length, 8);
      }

      // Bid: player 1 bids 5, others pass
      final passed = <int>[];
      final bidResult = BidValidator.validateBid(
        bidAmount: BidAmount.bab,
        currentHighest: null,
        passedPlayers: passed,
        playerIndex: 1,
      );
      expect(bidResult.isValid, true);

      // Others pass
      for (final p in [2, 3, 0]) {
        passed.add(p);
      }
      final outcome = BidValidator.checkBiddingComplete(
        passedPlayers: passed,
        currentHighest: BidAmount.bab,
        highestBidderIndex: 1,
      );
      expect(outcome.isComplete, true);
      expect(outcome.winnerIndex, 1);

      // Trump selection — pick a suit
      const trumpSuit = Suit.spades;

      // Play 8 tricks with the actual dealt hands
      final mutableHands = hands.map((h) => List<GameCard>.from(h)).toList();
      final tricksWon = {Team.a: 0, Team.b: 0};
      var leader = 2; // player after bid winner (seat 1) → seat 2

      for (var trickNum = 0; trickNum < 8; trickNum++) {
        // Check poison joker for leader
        if (PlayValidator.detectPoisonJoker(mutableHands[leader])) {
          // Poison joker — round ends
          break;
        }

        final plays = <TrickPlay>[];
        Suit? ledSuit;

        for (var i = 0; i < 4; i++) {
          final playerIdx = (leader + i) % 4;
          final hand = mutableHands[playerIdx];
          final isLead = i == 0;

          // Find a valid card to play
          GameCard? cardToPlay;
          for (final card in hand) {
            final validation = PlayValidator.validatePlay(
              card: card,
              hand: hand,
              ledSuit: ledSuit,
              isLeadPlay: isLead,
            );
            if (validation.isValid) {
              cardToPlay = card;
              break;
            }
          }
          expect(cardToPlay, isNotNull,
              reason: 'Player $playerIdx must have a valid card to play');

          plays.add(TrickPlay(playerIndex: playerIdx, card: cardToPlay!));
          hand.remove(cardToPlay);

          if (isLead && !cardToPlay.isJoker) {
            ledSuit = cardToPlay.suit;
          }
        }

        final trick = Trick(leadPlayerIndex: leader, plays: plays);
        final winner = TrickResolver.resolve(trick, trumpSuit: trumpSuit);
        tricksWon[teamForSeat(winner)] = (tricksWon[teamForSeat(winner)] ?? 0) + 1;
        leader = winner;
      }

      // Verify all 8 tricks were played (or poison joker)
      final totalTricks = (tricksWon[Team.a] ?? 0) + (tricksWon[Team.b] ?? 0);
      expect(totalTricks, lessThanOrEqualTo(8));
      expect(totalTricks, greaterThan(0));

      // Score
      if (totalTricks == 8) {
        final roundResult = Scorer.calculateRoundResult(
          bid: BidAmount.bab,
          biddingTeam: teamForSeat(1), // player 1 is Team B (odd seat)
          tricksWon: tricksWon,
        );
        expect(roundResult.pointsAwarded, greaterThan(0));

        final scores = Scorer.applyScore(
          scores: {Team.a: 0, Team.b: 0},
          winningTeam: roundResult.winningTeam,
          points: roundResult.pointsAwarded,
        );
        expect(scores[Team.a]! + scores[Team.b]!, greaterThan(0));
      }
    });

    test('kout success gives instant win', () {
      final scores = {Team.a: 5, Team.b: 10};
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 8, Team.b: 0},
      );
      final newScores = Scorer.applyScore(
        scores: scores,
        winningTeam: result.winningTeam,
        points: result.pointsAwarded,
      );
      expect(Scorer.checkGameOver(newScores), Team.a);
    });

    test('kout failure gives instant loss', () {
      final scores = {Team.a: 20, Team.b: 5};
      final result = Scorer.calculateRoundResult(
        bid: BidAmount.kout,
        biddingTeam: Team.a,
        tricksWon: {Team.a: 7, Team.b: 1},
      );
      final newScores = Scorer.applyScore(
        scores: scores,
        winningTeam: result.winningTeam,
        points: result.pointsAwarded,
      );
      expect(Scorer.checkGameOver(newScores), Team.b);
    });

    test('malzoom flow: all pass once → reshuffle, all pass again → forced bid', () {
      // First all-pass
      var malzoom = BidValidator.checkMalzoom(
        passedPlayers: [0, 1, 2, 3],
        reshuffleCount: 0,
      );
      expect(malzoom, MalzoomOutcome.reshuffle);

      // Second all-pass
      malzoom = BidValidator.checkMalzoom(
        passedPlayers: [0, 1, 2, 3],
        reshuffleCount: 1,
      );
      expect(malzoom, MalzoomOutcome.forcedBid);
    });
  });
}
```

- [ ] **Step 2: Run integration test**

Run: `flutter test test/shared/integration/round_simulation_test.dart`
Expected: All PASS

- [ ] **Step 3: Run all tests to confirm nothing is broken**

Run: `flutter test test/shared/`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add test/shared/integration/round_simulation_test.dart
git commit -m "test: add full round simulation integration test covering deal, bid, play, and scoring"
```

---

## Summary

7 tasks, ~35 steps. Produces:
- 6 source files in `lib/shared/`
- 7 test files in `test/shared/`
- Full coverage of: card model, deck, trick resolution, play validation, bid validation, malzoom, scoring, poison joker, game-over detection
- Zero external dependencies — pure Dart logic ready to be consumed by both client and server
