import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/models/card.dart';

void main() {
  PlayCardAction select({
    required List<GameCard> hand,
    required List<({String playerUid, GameCard card})> trickPlays,
    Suit? trumpSuit,
    Suit? ledSuit,
    int mySeat = 0,
    String? partnerUid,
    bool isKout = false,
    bool isFirstTrick = false,
  }) {
    return PlayStrategy.selectCard(
      hand: hand,
      trickPlays: trickPlays,
      trumpSuit: trumpSuit,
      ledSuit: ledSuit,
      mySeat: mySeat,
      partnerUid: partnerUid,
      isKout: isKout,
      isFirstTrick: isFirstTrick,
    );
  }

  group('selectFollow', () {
    test('1. following suit + partner winning → plays lowest', () {
      final result = select(
        hand: [
          GameCard.decode('SK'),
          GameCard.decode('S10'),
          GameCard.decode('S7'),
          GameCard.decode('H8'),
          GameCard.decode('C9'),
        ],
        trickPlays: [(playerUid: 'partner', card: GameCard.decode('SA'))],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      expect(result.card, GameCard.decode('S7'));
    });

    test('2. following suit + partner NOT winning + has winner → plays lowest winner', () {
      final result = select(
        hand: [
          GameCard.decode('SK'),
          GameCard.decode('S10'),
          GameCard.decode('S7'),
          GameCard.decode('H8'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('SQ'))],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // SK is the only card beating SQ
      expect(result.card, GameCard.decode('SK'));
    });

    test('3. following suit + no winner → plays lowest', () {
      final result = select(
        hand: [
          GameCard.decode('S10'),
          GameCard.decode('S8'),
          GameCard.decode('S7'),
          GameCard.decode('H9'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('SA'))],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      expect(result.card, GameCard.decode('S7'));
    });

    test('4. void + partner winning → dumps lowest', () {
      final result = select(
        hand: [
          GameCard.decode('H10'),
          GameCard.decode('H8'),
          GameCard.decode('CJ'),
        ],
        trickPlays: [(playerUid: 'partner', card: GameCard.decode('SA'))],
        trumpSuit: Suit.clubs,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // _lowest picks H8 (rank 8 < 10 < 11)
      expect(result.card, GameCard.decode('H8'));
    });

    test('5. void + has Joker + trick >= 7 → plays Joker', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
        ],
        trickPlays: [(playerUid: 'partner', card: GameCard.decode('SA'))],
        trumpSuit: Suit.clubs,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // 2 cards → trick 7, partner winning + Joker + trick >= 7 → dump Joker
      expect(result.card.isJoker, isTrue);
    });

    test('6. void + has Joker + trick < 5 → holds Joker', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
          GameCard.decode('HK'),
          GameCard.decode('CJ'),
          GameCard.decode('C9'),
          GameCard.decode('D10'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('SA'))],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // 6 cards → trick 3, not partner winning. Holds Joker, trumps with D10
      expect(result.card.isJoker, isFalse);
      expect(result.card, GameCard.decode('D10'));
    });

    test('7. void + has trump + no Joker → trumps with lowest winning trump', () {
      final result = select(
        hand: [
          GameCard.decode('DK'),
          GameCard.decode('D10'),
          GameCard.decode('H8'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('SA'))],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // Both DK and D10 beat SA (trump > non-trump), lowest = D10
      expect(result.card, GameCard.decode('D10'));
    });
  });

  group('T1.2 position-aware following', () {
    test('position 1 (2nd to play) following suit → tries to win even if partner led', () {
      final result = select(
        hand: [
          GameCard.decode('SK'),
          GameCard.decode('S10'),
          GameCard.decode('S7'),
          GameCard.decode('H8'),
          GameCard.decode('C9'),
        ],
        trickPlays: [(playerUid: 'partner', card: GameCard.decode('SQ'))],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // Position 1, not last → tries to win. SK beats SQ.
      expect(result.card, GameCard.decode('SK'));
    });

    test('position 3 (last to play) + partner winning → dumps low', () {
      final result = select(
        hand: [
          GameCard.decode('SK'),
          GameCard.decode('S10'),
          GameCard.decode('S7'),
          GameCard.decode('H8'),
        ],
        trickPlays: [
          (playerUid: 'opp1', card: GameCard.decode('S8')),
          (playerUid: 'partner', card: GameCard.decode('SA')),
          (playerUid: 'opp2', card: GameCard.decode('S9')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // Position 3 (last), partner winning with SA → dump lowest
      expect(result.card, GameCard.decode('S7'));
    });
  });

  group('T1.3 Joker logic', () {
    test('partner winning + 2 cards → dumps Joker (poison escape)', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
        ],
        trickPlays: [(playerUid: 'partner', card: GameCard.decode('SA'))],
        trumpSuit: Suit.clubs,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      expect(result.card.isJoker, isTrue);
    });

    test('partner winning + 5 cards → dumps lowest (holds Joker)', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
          GameCard.decode('HK'),
          GameCard.decode('CJ'),
          GameCard.decode('C9'),
        ],
        trickPlays: [(playerUid: 'partner', card: GameCard.decode('SA'))],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // hand.length 5 > 2, partner winning → dump lowest, hold Joker
      expect(result.card.isJoker, isFalse);
      expect(result.card, GameCard.decode('H8'));
    });

    test('opponent trumped → plays Joker to steal', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
          GameCard.decode('HK'),
          GameCard.decode('CJ'),
          GameCard.decode('C9'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('D10'))],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // Opponent played D10 (trump), not partner winning → Joker steals
      expect(result.card.isJoker, isTrue);
    });

    test('1 non-Joker card left → dumps Joker (poison prevention)', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('SA'))],
        trumpSuit: Suit.clubs,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // Not partner winning, nonJoker.length = 1 ≤ 1 → dump Joker
      expect(result.card.isJoker, isTrue);
    });

    test('5 cards, no special condition → holds Joker', () {
      final result = select(
        hand: [
          GameCard.joker(),
          GameCard.decode('H8'),
          GameCard.decode('HK'),
          GameCard.decode('CJ'),
          GameCard.decode('C9'),
        ],
        trickPlays: [(playerUid: 'opp', card: GameCard.decode('SA'))],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        partnerUid: 'partner',
      );
      // Not partner winning, 4 non-Joker > 1, no opponent trump, hand.length 5 > 3
      // Holds Joker, trumps with H8
      expect(result.card.isJoker, isFalse);
      expect(result.card, GameCard.decode('H8'));
    });
  });

  group('T1.1 Ace-first leading', () {
    test('Ace-King same suit → leads Ace', () {
      final result = select(
        hand: [
          GameCard.decode('SA'),
          GameCard.decode('SK'),
          GameCard.decode('H10'),
          GameCard.decode('H9'),
          GameCard.decode('H8'),
          GameCard.decode('CQ'),
          GameCard.decode('C9'),
          GameCard.decode('D8'),
        ],
        trickPlays: [],
        trumpSuit: Suit.diamonds,
      );
      // Has SA with SK → Ace-King preference → leads SA
      // Without Ace-first would lead H10 (longest suit = hearts with 3)
      expect(result.card, GameCard.decode('SA'));
    });

    test('singleton Ace preferred over Ace with backup', () {
      final result = select(
        hand: [
          GameCard.decode('SA'),
          GameCard.decode('HA'),
          GameCard.decode('H10'),
          GameCard.decode('H9'),
          GameCard.decode('C9'),
          GameCard.decode('C8'),
          GameCard.decode('D8'),
          GameCard.decode('D9'),
        ],
        trickPlays: [],
        trumpSuit: Suit.clubs,
      );
      // SA is singleton (only spade), HA has backup (H10, H9)
      // Neither has King → singleton preferred → leads SA
      expect(result.card, GameCard.decode('SA'));
    });
  });

  group('selectLead', () {
    test('8. Kout first trick → leads highest trump', () {
      final result = select(
        hand: [
          GameCard.decode('DA'),
          GameCard.decode('DK'),
          GameCard.decode('D10'),
          GameCard.decode('HA'),
          GameCard.decode('SA'),
          GameCard.decode('C9'),
          GameCard.decode('C8'),
          GameCard.decode('H7'),
        ],
        trickPlays: [],
        trumpSuit: Suit.diamonds,
        isKout: true,
        isFirstTrick: true,
      );
      expect(result.card, GameCard.decode('DA'));
    });

    test('9. has Ace in longest suit → leads Ace', () {
      final result = select(
        hand: [
          GameCard.decode('SA'),
          GameCard.decode('SK'),
          GameCard.decode('S10'),
          GameCard.decode('HA'),
          GameCard.decode('C9'),
          GameCard.decode('C8'),
          GameCard.decode('DK'),
          GameCard.decode('D9'),
        ],
        trickPlays: [],
        trumpSuit: Suit.hearts,
      );
      // Spades is longest non-trump (3), leads highest = SA
      expect(result.card, GameCard.decode('SA'));
    });

    test('10. no Ace → leads highest from longest non-trump suit', () {
      final result = select(
        hand: [
          GameCard.decode('SK'),
          GameCard.decode('SQ'),
          GameCard.decode('S10'),
          GameCard.decode('HK'),
          GameCard.decode('C9'),
          GameCard.decode('C8'),
          GameCard.decode('DK'),
          GameCard.decode('D9'),
        ],
        trickPlays: [],
        trumpSuit: Suit.diamonds,
      );
      // Spades is longest non-trump (3), leads highest = SK
      expect(result.card, GameCard.decode('SK'));
    });
  });
}
