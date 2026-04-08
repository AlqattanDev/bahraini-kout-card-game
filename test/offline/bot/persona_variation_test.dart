import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/bot_persona.dart';
import 'package:koutbh/offline/bot/game_context.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';

GameContext _ctx(BotPersona persona) {
  return GameContext(
    mySeat: 0,
    myTeam: Team.a,
    scores: const {Team.a: 0, Team.b: 0},
    currentBid: BidAmount.six,
    bidderSeat: 0,
    isBiddingTeam: true,
    isForcedBid: false,
    trickCounts: const {Team.a: 2, Team.b: 1},
    trickWinners: const [],
    trumpSuit: Suit.hearts,
    persona: persona,
    roundControlUrgency: 0.2,
  );
}

void main() {
  test('persona from stable seed is deterministic', () {
    final a = BotPersona.fromSeed(1, 4, 2);
    final b = BotPersona.fromSeed(1, 4, 2);
    expect(a, equals(b));
  });

  test('different seeds can select different style', () {
    final a = BotPersona.fromSeed(1, 1, 1);
    final b = BotPersona.fromSeed(2, 1, 1);
    expect(a.style, isNotNull);
    expect(b.style, isNotNull);
  });

  test('equal-ish options vary by persona but remain legal', () {
    final hand = [
      GameCard.decode('S10'),
      GameCard.decode('S9'),
      GameCard.decode('S8'),
    ];
    final trickPlays = [(playerUid: 'partner', card: GameCard.decode('SK'))];

    final methodical = PlayStrategy.selectCard(
      hand: hand,
      trickPlays: trickPlays,
      trumpSuit: Suit.hearts,
      ledSuit: Suit.spades,
      mySeat: 0,
      partnerUid: 'partner',
      context: _ctx(const BotPersona(BotStyle.methodical)),
    );
    final pressure = PlayStrategy.selectCard(
      hand: hand,
      trickPlays: trickPlays,
      trumpSuit: Suit.hearts,
      ledSuit: Suit.spades,
      mySeat: 0,
      partnerUid: 'partner',
      context: _ctx(const BotPersona(BotStyle.pressure)),
    );

    expect(hand.contains(methodical.card), isTrue);
    expect(hand.contains(pressure.card), isTrue);
    expect(methodical.card.encode(), isNotEmpty);
    expect(pressure.card.encode(), isNotEmpty);
    expect(methodical.card, GameCard.decode('S8'));
    expect(pressure.card, GameCard.decode('S10'));
  });
}
