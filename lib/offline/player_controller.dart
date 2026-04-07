import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/app/models/client_game_state.dart';

sealed class GameAction {}

class BidAction extends GameAction {
  final BidAmount amount;
  BidAction(this.amount);
}

class PassAction extends GameAction {}

class TrumpAction extends GameAction {
  final Suit suit;
  TrumpAction(this.suit);
}

class PlayCardAction extends GameAction {
  final GameCard card;
  PlayCardAction(this.card);
}

sealed class ActionContext {}

class BidContext extends ActionContext {
  final BidAmount? currentHighBid;
  final bool isForced;
  final List<int> passedPlayers;
  BidContext({
    this.currentHighBid,
    this.isForced = false,
    this.passedPlayers = const [],
  });
}

class TrumpContext extends ActionContext {}

class PlayContext extends ActionContext {
  final Suit? ledSuit;
  final bool isForced;
  PlayContext({this.ledSuit, this.isForced = false});
}

abstract class PlayerController {
  Future<GameAction> decideAction(
      ClientGameState state, ActionContext context);
}
