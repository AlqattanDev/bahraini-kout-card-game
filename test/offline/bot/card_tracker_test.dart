import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/card_tracker.dart';
import 'package:koutbh/shared/models/card.dart';

void main() {
  late CardTracker tracker;

  setUp(() {
    tracker = CardTracker();
  });

  test('recordPlay adds to playedCards', () {
    final card = GameCard.decode('SA');
    tracker.recordPlay(0, card);
    expect(tracker.playedCards, contains(card));
    expect(tracker.playedCards.length, 1);
  });

  test('remainingCards excludes played and hand', () {
    final played = GameCard.decode('SA');
    final inHand = GameCard.decode('SK');
    tracker.recordPlay(1, played);

    final remaining = tracker.remainingCards([inHand]);
    expect(remaining, isNot(contains(played)));
    expect(remaining, isNot(contains(inHand)));
    // Full deck is 32, minus 1 played, minus 1 in hand = 30
    expect(remaining.length, 30);
  });

  test('inferVoid records correctly', () {
    tracker.inferVoid(1, Suit.hearts);
    expect(tracker.knownVoids[1], contains(Suit.hearts));

    tracker.inferVoid(1, Suit.clubs);
    expect(tracker.knownVoids[1]!.length, 2);
  });

  test('trumpsRemaining counts correctly', () {
    final myHand = [GameCard.decode('HA'), GameCard.decode('HK')];
    // Hearts in deck: A,K,Q,J,10,9,8,7 = 8 cards
    // In hand: 2 (HA, HK). Played: 0. Remaining = 6
    expect(tracker.trumpsRemaining(Suit.hearts, myHand), 6);

    tracker.recordPlay(1, GameCard.decode('HQ'));
    expect(tracker.trumpsRemaining(Suit.hearts, myHand), 5);
  });

  test('isHighestRemaining: King becomes master after Ace played', () {
    final king = GameCard.decode('SK');
    final myHand = [king];

    // Ace of spades not played → King is NOT highest
    expect(tracker.isHighestRemaining(king, myHand), isFalse);

    // Play the Ace
    tracker.recordPlay(2, GameCard.decode('SA'));
    // Now King IS the highest remaining in spades
    expect(tracker.isHighestRemaining(king, myHand), isTrue);
  });

  test('isSuitExhausted: true when all suit cards played or in hand', () {
    // Diamonds has 7 cards: A,K,Q,J,10,9,8 (no 7)
    final myDiamonds = [
      GameCard.decode('DA'),
      GameCard.decode('DK'),
      GameCard.decode('DQ'),
    ];
    expect(tracker.isSuitExhausted(Suit.diamonds, myDiamonds), isFalse);

    // Play remaining diamonds
    tracker.recordPlay(1, GameCard.decode('DJ'));
    tracker.recordPlay(2, GameCard.decode('D10'));
    tracker.recordPlay(3, GameCard.decode('D9'));
    tracker.recordPlay(0, GameCard.decode('D8'));

    expect(tracker.isSuitExhausted(Suit.diamonds, myDiamonds), isTrue);
  });

  test('reset clears everything', () {
    tracker.recordPlay(0, GameCard.decode('SA'));
    tracker.inferVoid(1, Suit.hearts);
    tracker.reset();

    expect(tracker.playedCards, isEmpty);
    expect(tracker.knownVoids, isEmpty);
  });

  test('Joker is always highest remaining', () {
    final joker = GameCard.joker();
    expect(tracker.isHighestRemaining(joker, [joker]), isTrue);
  });

  test('fullDeck has 32 cards', () {
    expect(GameCard.fullDeck().length, 32);
  });
}
