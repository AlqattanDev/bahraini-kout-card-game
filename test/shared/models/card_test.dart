import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/constants.dart';

void main() {
  group('Suit', () {
    test('has exactly 4 suits', () {
      expect(Suit.values.length, equals(4));
    });

    test('contains spades, hearts, clubs, diamonds', () {
      expect(Suit.values, containsAll([
        Suit.spades,
        Suit.hearts,
        Suit.clubs,
        Suit.diamonds,
      ]));
    });
  });

  group('Rank', () {
    test('has exactly 8 ranks', () {
      expect(Rank.values.length, equals(8));
    });

    test('ranks are ordered high to low: A(14), K(13), Q(12), J(11), 10, 9, 8, 7', () {
      expect(Rank.ace.value, equals(14));
      expect(Rank.king.value, equals(13));
      expect(Rank.queen.value, equals(12));
      expect(Rank.jack.value, equals(11));
      expect(Rank.ten.value, equals(10));
      expect(Rank.nine.value, equals(9));
      expect(Rank.eight.value, equals(8));
      expect(Rank.seven.value, equals(7));
    });

    test('ace is higher than king', () {
      expect(Rank.ace.value, greaterThan(Rank.king.value));
    });

    test('seven is the lowest rank', () {
      final lowestValue = Rank.values.map((r) => r.value).reduce((a, b) => a < b ? a : b);
      expect(Rank.seven.value, equals(lowestValue));
    });
  });

  group('GameCard', () {
    test('creates a regular card with suit and rank', () {
      final card = GameCard(suit: Suit.spades, rank: Rank.ace);
      expect(card.suit, equals(Suit.spades));
      expect(card.rank, equals(Rank.ace));
      expect(card.isJoker, isFalse);
    });

    test('creates a joker', () {
      final joker = GameCard.joker();
      expect(joker.isJoker, isTrue);
      expect(joker.suit, isNull);
      expect(joker.rank, isNull);
    });

    group('encode', () {
      test('encodes SA (Ace of Spades)', () {
        final card = GameCard(suit: Suit.spades, rank: Rank.ace);
        expect(card.encode(), equals('SA'));
      });

      test('encodes HK (King of Hearts)', () {
        final card = GameCard(suit: Suit.hearts, rank: Rank.king);
        expect(card.encode(), equals('HK'));
      });

      test('encodes D10 (Ten of Diamonds)', () {
        final card = GameCard(suit: Suit.diamonds, rank: Rank.ten);
        expect(card.encode(), equals('D10'));
      });

      test('encodes C7 (Seven of Clubs)', () {
        final card = GameCard(suit: Suit.clubs, rank: Rank.seven);
        expect(card.encode(), equals('C7'));
      });

      test('encodes JO (Joker)', () {
        final joker = GameCard.joker();
        expect(joker.encode(), equals('JO'));
      });
    });

    group('decode', () {
      test('decodes SA to Ace of Spades', () {
        final card = GameCard.decode('SA');
        expect(card.suit, equals(Suit.spades));
        expect(card.rank, equals(Rank.ace));
        expect(card.isJoker, isFalse);
      });

      test('decodes HK to King of Hearts', () {
        final card = GameCard.decode('HK');
        expect(card.suit, equals(Suit.hearts));
        expect(card.rank, equals(Rank.king));
      });

      test('decodes D10 to Ten of Diamonds', () {
        final card = GameCard.decode('D10');
        expect(card.suit, equals(Suit.diamonds));
        expect(card.rank, equals(Rank.ten));
      });

      test('decodes C7 to Seven of Clubs', () {
        final card = GameCard.decode('C7');
        expect(card.suit, equals(Suit.clubs));
        expect(card.rank, equals(Rank.seven));
      });

      test('decodes JO to Joker', () {
        final card = GameCard.decode('JO');
        expect(card.isJoker, isTrue);
        expect(card.suit, isNull);
        expect(card.rank, isNull);
      });
    });

    group('decode roundtrip', () {
      test('encode then decode returns equivalent card for all regular cards', () {
        for (final suit in Suit.values) {
          for (final rank in Rank.values) {
            final original = GameCard(suit: suit, rank: rank);
            final roundtripped = GameCard.decode(original.encode());
            expect(roundtripped, equals(original),
                reason: 'Roundtrip failed for ${original.encode()}');
          }
        }
      });

      test('encode then decode returns equivalent joker', () {
        final joker = GameCard.joker();
        final roundtripped = GameCard.decode(joker.encode());
        expect(roundtripped, equals(joker));
      });
    });

    group('equality', () {
      test('two cards with same suit and rank are equal', () {
        final card1 = GameCard(suit: Suit.spades, rank: Rank.ace);
        final card2 = GameCard(suit: Suit.spades, rank: Rank.ace);
        expect(card1, equals(card2));
      });

      test('two cards with different suits are not equal', () {
        final card1 = GameCard(suit: Suit.spades, rank: Rank.ace);
        final card2 = GameCard(suit: Suit.hearts, rank: Rank.ace);
        expect(card1, isNot(equals(card2)));
      });

      test('two cards with different ranks are not equal', () {
        final card1 = GameCard(suit: Suit.spades, rank: Rank.ace);
        final card2 = GameCard(suit: Suit.spades, rank: Rank.king);
        expect(card1, isNot(equals(card2)));
      });

      test('two jokers are equal', () {
        final joker1 = GameCard.joker();
        final joker2 = GameCard.joker();
        expect(joker1, equals(joker2));
      });

      test('joker is not equal to a regular card', () {
        final joker = GameCard.joker();
        final card = GameCard(suit: Suit.spades, rank: Rank.ace);
        expect(joker, isNot(equals(card)));
      });

      test('equal cards have same hashCode', () {
        final card1 = GameCard(suit: Suit.spades, rank: Rank.ace);
        final card2 = GameCard(suit: Suit.spades, rank: Rank.ace);
        expect(card1.hashCode, equals(card2.hashCode));
      });

      test('two jokers have same hashCode', () {
        final joker1 = GameCard.joker();
        final joker2 = GameCard.joker();
        expect(joker1.hashCode, equals(joker2.hashCode));
      });
    });

    group('toString', () {
      test('toString returns human-readable form', () {
        final card = GameCard(suit: Suit.spades, rank: Rank.ace);
        expect(card.toString(), equals('ace of spades'));
      });

      test('joker toString returns Joker', () {
        final joker = GameCard.joker();
        expect(joker.toString(), equals('Joker'));
      });
    });
  });

  group('constants', () {
    test('suitInitial maps all 4 suits to their initials', () {
      expect(suitInitial[Suit.spades], equals('S'));
      expect(suitInitial[Suit.hearts], equals('H'));
      expect(suitInitial[Suit.clubs], equals('C'));
      expect(suitInitial[Suit.diamonds], equals('D'));
      expect(suitInitial.length, equals(4));
    });

    test('initialToSuit maps all initials back to suits', () {
      expect(initialToSuit['S'], equals(Suit.spades));
      expect(initialToSuit['H'], equals(Suit.hearts));
      expect(initialToSuit['C'], equals(Suit.clubs));
      expect(initialToSuit['D'], equals(Suit.diamonds));
      expect(initialToSuit.length, equals(4));
    });

    test('rankString maps all 8 ranks to their strings', () {
      expect(rankString[Rank.ace], equals('A'));
      expect(rankString[Rank.king], equals('K'));
      expect(rankString[Rank.queen], equals('Q'));
      expect(rankString[Rank.jack], equals('J'));
      expect(rankString[Rank.ten], equals('10'));
      expect(rankString[Rank.nine], equals('9'));
      expect(rankString[Rank.eight], equals('8'));
      expect(rankString[Rank.seven], equals('7'));
      expect(rankString.length, equals(8));
    });

    test('stringToRank maps all strings back to ranks', () {
      expect(stringToRank['A'], equals(Rank.ace));
      expect(stringToRank['K'], equals(Rank.king));
      expect(stringToRank['Q'], equals(Rank.queen));
      expect(stringToRank['J'], equals(Rank.jack));
      expect(stringToRank['10'], equals(Rank.ten));
      expect(stringToRank['9'], equals(Rank.nine));
      expect(stringToRank['8'], equals(Rank.eight));
      expect(stringToRank['7'], equals(Rank.seven));
      expect(stringToRank.length, equals(8));
    });

    test('suitInitial and initialToSuit are inverses', () {
      for (final suit in Suit.values) {
        final initial = suitInitial[suit]!;
        expect(initialToSuit[initial], equals(suit));
      }
    });

    test('rankString and stringToRank are inverses', () {
      for (final rank in Rank.values) {
        final str = rankString[rank]!;
        expect(stringToRank[str], equals(rank));
      }
    });
  });
}
