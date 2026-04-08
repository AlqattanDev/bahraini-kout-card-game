import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'player_controller.dart';
import 'bot/game_context.dart';
import 'bot/bot_persona.dart';
import 'bot/bot_settings.dart';
import 'bot/bid_strategy.dart';
import 'bot/trump_strategy.dart';
import 'bot/play_strategy.dart';

class BotPlayerController implements PlayerController {
  final int seatIndex;

  BotPlayerController({required this.seatIndex});

  @override
  Future<GameAction> decideAction(
    ClientGameState state,
    ActionContext context,
  ) async {
    return switch (context) {
      BidContext(:final currentHighBid, :final isForced) =>
        BidStrategy.decideBid(
          state.myHand,
          currentHighBid,
          isForced: isForced,
          scores: state.scores,
          myTeam: teamForSeat(seatIndex),
          mySeat: seatIndex,
          bidHistory: _convertBidHistory(state),
          difficultyAdjust: BotSettings.bidAdjust,
        ),
      TrumpContext(:final isForcedBid) => TrumpAction(
        TrumpStrategy.selectTrump(
          state.myHand,
          bidLevel: state.currentBid,
          isForcedBid: isForcedBid,
          lengthWeight: BotSettings.trumpLengthWeight,
          strengthWeight: BotSettings.trumpStrengthWeight,
        ),
      ),
      PlayContext(:final ledSuit, :final isForced, :final tracker) =>
        PlayStrategy.selectCard(
          hand: state.myHand,
          trickPlays: state.currentTrickPlays,
          trumpSuit: state.trumpSuit,
          ledSuit: ledSuit,
          mySeat: seatIndex,
          partnerUid: state.playerUids[(seatIndex + 2) % 4],
          isKout: state.currentBid?.isKout ?? false,
          isFirstTrick: state.trickWinners.isEmpty,
          context: GameContext.fromClientState(
            state,
            seatIndex,
            isForcedBid: isForced,
            tracker: tracker,
            persona: BotPersona.fromSeed(
              seatIndex,
              state.roundIndex,
              state.trickWinners.length,
            ),
          ),
        ),
    };
  }

  static List<({int seat, String action})> _convertBidHistory(
    ClientGameState state,
  ) {
    return state.bidHistory.map((e) {
      final seatIndex = state.playerUids.indexOf(e.playerUid);
      if (seatIndex == -1) {
        throw StateError('Unknown player UID in bid history: ${e.playerUid}');
      }
      return (seat: seatIndex, action: e.action);
    }).toList();
  }
}
