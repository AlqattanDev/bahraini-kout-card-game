import 'dart:async';
import 'dart:math';

import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/constants/timing.dart';
import 'package:koutbh/offline/game_input_sink.dart';

class HumanPlayerController implements PlayerController, GameInputSink {
  static Duration get timeout => GameTiming.humanTurnTimeout;

  Completer<GameAction>? _pending;
  Timer? _timer;

  @override
  Future<GameAction> decideAction(
      ClientGameState state, ActionContext context) {
    _timer?.cancel();
    _pending = Completer<GameAction>();

    _timer = Timer(timeout, () {
      final fallback = _fallbackAction(state, context);
      _complete(fallback);
    });

    return _pending!.future;
  }

  void _complete(GameAction action) {
    _timer?.cancel();
    _timer = null;
    final p = _pending;
    if (p != null && !p.isCompleted) {
      _pending = null;
      p.complete(action);
    }
  }

  GameAction _fallbackAction(ClientGameState state, ActionContext context) {
    final rng = Random();

    if (context is BidContext) {
      // Pass if allowed, otherwise forced minimum bid
      final canPass = !context.isForced;
      return canPass ? PassAction() : BidAction(BidAmount.bab);
    }

    if (context is TrumpContext) {
      // Pick a random suit from the hand
      final suits = state.myHand
          .where((c) => !c.isJoker && c.suit != null)
          .map((c) => c.suit!)
          .toSet()
          .toList();
      if (suits.isEmpty) return TrumpAction(Suit.spades);
      return TrumpAction(suits[rng.nextInt(suits.length)]);
    }

    if (context is PlayContext) {
      // Pick a random valid card
      final hand = state.myHand;
      List<GameCard> validCards;

      if (context.ledSuit != null) {
        // Must follow suit if possible (joker always valid)
        final followSuit =
            hand.where((c) => c.suit == context.ledSuit).toList();
        if (followSuit.isNotEmpty) {
          final jokers = hand.where((c) => c.isJoker).toList();
          validCards = [...followSuit, ...jokers];
        } else {
          validCards = List.from(hand);
        }
      } else {
        // Leading — play any non-joker card (joker lead = poison)
        final nonJoker = hand.where((c) => !c.isJoker).toList();
        validCards = nonJoker.isNotEmpty ? nonJoker : List.from(hand);
      }

      return PlayCardAction(validCards[rng.nextInt(validCards.length)]);
    }

    // Should never reach here
    return PassAction();
  }

  @override
  void playCard(GameCard card) => _complete(PlayCardAction(card));

  @override
  void placeBid(BidAmount amount) => _complete(BidAction(amount));

  @override
  void pass() => _complete(PassAction());

  @override
  void selectTrump(Suit suit) => _complete(TrumpAction(suit));
}
