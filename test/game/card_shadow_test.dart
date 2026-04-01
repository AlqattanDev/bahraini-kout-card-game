import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/card_component.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/enums.dart';

void main() {
  test('CardComponent has showShadow property defaulting to true', () {
    final card = CardComponent(
      card: GameCard(suit: Suit.spades, rank: Rank.ace),
      isFaceUp: true,
    );
    expect(card.showShadow, true);
  });

  test('CardComponent showShadow can be set to false', () {
    final card = CardComponent(
      card: GameCard(suit: Suit.spades, rank: Rank.ace),
      isFaceUp: true,
      showShadow: false,
    );
    expect(card.showShadow, false);
  });
}
