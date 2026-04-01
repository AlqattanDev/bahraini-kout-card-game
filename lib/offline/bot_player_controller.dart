import 'package:koutbh/app/models/client_game_state.dart';
import 'player_controller.dart';
import 'bot/bid_strategy.dart';
import 'bot/trump_strategy.dart';
import 'bot/play_strategy.dart';

class BotPlayerController implements PlayerController {
  final int seatIndex;

  BotPlayerController({required this.seatIndex});

  @override
  Future<GameAction> decideAction(
      ClientGameState state, ActionContext context) async {
    return switch (context) {
      BidContext(:final currentHighBid, :final isForced) =>
        BidStrategy.decideBid(state.myHand, currentHighBid, isForced: isForced),
      TrumpContext() => TrumpAction(TrumpStrategy.selectTrump(state.myHand)),
      PlayContext(:final ledSuit) => PlayStrategy.selectCard(
          hand: state.myHand,
          trickPlays: state.currentTrickPlays,
          trumpSuit: state.trumpSuit,
          ledSuit: ledSuit,
          mySeat: seatIndex,
          partnerUid: state.playerUids[(seatIndex + 2) % 4],
          isKout: state.currentBid?.isKout ?? false,
          isFirstTrick: state.trickWinners.isEmpty,
        ),
    };
  }
}
