import 'dart:math';

import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/logic/trick_resolver.dart';
import 'card_tracker.dart';

class GameContext {
  final int mySeat;
  final Team myTeam;
  final Map<Team, int> scores;
  final BidAmount? currentBid;
  final int? bidderSeat;
  final bool isBiddingTeam;
  final bool isForcedBid;
  final Map<Team, int> trickCounts;
  final List<Team> trickWinners;
  final Suit? trumpSuit;
  final CardTracker? tracker;

  /// 0.0 = low pressure, 1.0 = every remaining trick matters for bid contract.
  final double roundControlUrgency;

  /// Current trick: partner's card is winning so far (partial trick).
  final bool partnerLikelyWinningTrick;

  /// Partner currently winning but trump could still steal the trick.
  final bool partnerNeedsProtection;

  final bool opponentLikelyVoidInLedSuit;
  final bool partnerLikelyVoidInLedSuit;

  const GameContext({
    required this.mySeat,
    required this.myTeam,
    required this.scores,
    required this.currentBid,
    required this.bidderSeat,
    required this.isBiddingTeam,
    required this.isForcedBid,
    required this.trickCounts,
    required this.trickWinners,
    this.trumpSuit,
    this.tracker,
    this.roundControlUrgency = 0.0,
    this.partnerLikelyWinningTrick = false,
    this.partnerNeedsProtection = false,
    this.opponentLikelyVoidInLedSuit = false,
    this.partnerLikelyVoidInLedSuit = false,
  });

  Team get opponentTeam => myTeam.opponent;
  int get partnerSeat => (mySeat + 2) % 4;
  int get myTricks => trickCounts[myTeam] ?? 0;
  int get opponentTricks => trickCounts[opponentTeam] ?? 0;
  int get tricksPlayed => trickWinners.length;

  /// How many more tricks the bidding team needs to make the bid.
  int get tricksNeededForBid {
    final biddingTeam = bidderSeat != null ? teamForSeat(bidderSeat!) : myTeam;
    final won = trickCounts[biddingTeam] ?? 0;
    return (currentBid?.value ?? 5) - won;
  }

  factory GameContext.fromClientState(
    ClientGameState state,
    int seatIndex, {
    CardTracker? tracker,
    bool isForcedBid = false,
  }) {
    final myTeam = teamForSeat(seatIndex);
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : null;
    final partnerUid = state.playerUids[(seatIndex + 2) % 4];
    final urgency = _computeRoundControlUrgency(state);
    final trickSignals = _computeTrickSignals(
      state: state,
      seatIndex: seatIndex,
      partnerUid: partnerUid,
      trumpSuit: state.trumpSuit,
      tracker: tracker,
    );

    return GameContext(
      mySeat: seatIndex,
      myTeam: myTeam,
      scores: state.scores,
      currentBid: state.currentBid,
      bidderSeat: bidderSeat,
      isBiddingTeam: bidderSeat != null && teamForSeat(bidderSeat) == myTeam,
      isForcedBid: isForcedBid,
      trickCounts: state.tricks,
      trickWinners: state.trickWinners,
      trumpSuit: state.trumpSuit,
      tracker: tracker,
      roundControlUrgency: urgency,
      partnerLikelyWinningTrick: trickSignals.partnerLikelyWinning,
      partnerNeedsProtection: trickSignals.partnerNeedsProtection,
      opponentLikelyVoidInLedSuit: trickSignals.opponentVoidLed,
      partnerLikelyVoidInLedSuit: trickSignals.partnerVoidLed,
    );
  }

  static double _computeRoundControlUrgency(ClientGameState state) {
    final bid = state.currentBid?.value ?? 5;
    final bidderSeat = state.bidderUid != null
        ? state.playerUids.indexOf(state.bidderUid!)
        : -1;
    if (bidderSeat < 0) return 0.0;
    final biddingTeam = teamForSeat(bidderSeat);
    final won = state.tricks[biddingTeam] ?? 0;
    final need = max(0, bid - won);
    final remaining = 8 - state.trickWinners.length;
    if (remaining <= 0) return 0.0;
    if (need <= 0) return 0.0;
    if (need > remaining) return 1.0;
    return (need / remaining).clamp(0.0, 1.0);
  }

  static ({
    bool partnerLikelyWinning,
    bool partnerNeedsProtection,
    bool opponentVoidLed,
    bool partnerVoidLed,
  })
  _computeTrickSignals({
    required ClientGameState state,
    required int seatIndex,
    required String partnerUid,
    required Suit? trumpSuit,
    required CardTracker? tracker,
  }) {
    final plays = state.currentTrickPlays;
    if (plays.isEmpty) {
      return (
        partnerLikelyWinning: false,
        partnerNeedsProtection: false,
        opponentVoidLed: false,
        partnerVoidLed: false,
      );
    }

    final leadCard = plays.first.card;
    final ledSuit = leadCard.isJoker ? null : leadCard.suit;

    var best = plays.first;
    for (var i = 1; i < plays.length; i++) {
      if (TrickResolver.beats(plays[i].card, best.card, trumpSuit, ledSuit)) {
        best = plays[i];
      }
    }

    final partnerWinning = best.playerUid == partnerUid;
    final trumpPlayed =
        trumpSuit != null &&
        plays.any((p) => !p.card.isJoker && p.card.suit == trumpSuit);
    final partnerNeedsProtection =
        partnerWinning &&
        trumpSuit != null &&
        ledSuit != null &&
        ledSuit != trumpSuit &&
        !trumpPlayed;

    bool opponentVoidLed = false;
    bool partnerVoidLed = false;
    if (tracker != null && ledSuit != null) {
      final voids = tracker.knownVoids;
      opponentVoidLed =
          (voids[(seatIndex + 1) % 4]?.contains(ledSuit) ?? false) ||
          (voids[(seatIndex + 3) % 4]?.contains(ledSuit) ?? false);
      partnerVoidLed = voids[(seatIndex + 2) % 4]?.contains(ledSuit) ?? false;
    }

    return (
      partnerLikelyWinning: partnerWinning,
      partnerNeedsProtection: partnerNeedsProtection,
      opponentVoidLed: opponentVoidLed,
      partnerVoidLed: partnerVoidLed,
    );
  }
}
