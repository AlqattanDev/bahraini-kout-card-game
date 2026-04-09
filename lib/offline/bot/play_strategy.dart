import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/logic/play_validator.dart';
import 'package:koutbh/shared/logic/trick_resolver.dart';
import 'package:koutbh/shared/logic/card_utils.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/card_tracker.dart';
import 'package:koutbh/offline/bot/game_context.dart';

class PlayStrategy {
  static PlayCardAction selectCard({
    required List<GameCard> hand,
    required List<({String playerUid, GameCard card})> trickPlays,
    required Suit? trumpSuit,
    required Suit? ledSuit,
    required int mySeat,
    String? partnerUid,
    bool isKout = false,
    bool isFirstTrick = false,
    GameContext? context,
  }) {
    final legalCards = _legalPlays(
      hand,
      ledSuit,
      trickPlays.isEmpty,
      trumpSuit: trumpSuit,
      isKout: isKout,
      isFirstTrick: isFirstTrick,
    );

    if (legalCards.length == 1) {
      return PlayCardAction(legalCards.first);
    }

    if (trickPlays.isEmpty) {
      return PlayCardAction(
        _selectLead(legalCards, trumpSuit, context: context, hand: hand),
      );
    }

    return PlayCardAction(
      _selectFollow(
        legalCards: legalCards,
        hand: hand,
        trickPlays: trickPlays,
        trumpSuit: trumpSuit,
        ledSuit: ledSuit,
        partnerUid: partnerUid,
        context: context,
      ),
    );
  }

  static List<GameCard> _legalPlays(
    List<GameCard> hand,
    Suit? ledSuit,
    bool isLead, {
    Suit? trumpSuit,
    bool isKout = false,
    bool isFirstTrick = false,
  }) {
    final legal = PlayValidator.playableForCurrentTrick(
      hand: hand,
      trickHasNoPlaysYet: isLead,
      ledSuit: ledSuit,
      trumpSuit: trumpSuit,
      bidIsKout: isKout,
      noTricksCompletedYet: isFirstTrick,
    ).toList();

    if (isLead) {
      final nonJoker = legal.where((c) => !c.isJoker).toList();
      if (nonJoker.isNotEmpty) return nonJoker;
    }

    return legal;
  }

  static bool _isLowLead(GameCard card) {
    if (card.isJoker || card.rank == null) return false;
    return card.rank!.value <= Rank.ten.value;
  }

  static bool _defenderDumpMode(GameContext ctx) {
    if (ctx.isBiddingTeam) return false;
    if (ctx.bidderSeat == null) return false;
    final bidderTeam = teamForSeat(ctx.bidderSeat!);
    final won = ctx.trickCounts[bidderTeam] ?? 0;
    return won >= (ctx.currentBid?.value ?? 5);
  }

  static bool _defenderBidAlreadyLost(GameContext ctx) {
    if (ctx.isBiddingTeam) return false;
    if (ctx.bidderSeat == null) return false;
    final bidderTeam = teamForSeat(ctx.bidderSeat!);
    final won = ctx.trickCounts[bidderTeam] ?? 0;
    final need = (ctx.currentBid?.value ?? 5) - won;
    final remaining = 8 - ctx.tricksPlayed;
    return need > remaining;
  }

  static GameCard _selectLead(
    List<GameCard> legalCards,
    Suit? trumpSuit, {
    GameContext? context,
    List<GameCard>? hand,
  }) {
    final fullHand = hand ?? legalCards;

    if (context?.tracker != null) {
      final masters = legalCards
          .where(
            (c) =>
                !c.isJoker && context!.tracker!.isHighestRemaining(c, fullHand),
          )
          .toList();
      if (masters.isNotEmpty) {
        masters.sort((a, b) {
          final aT = a.suit == trumpSuit;
          final bT = b.suit == trumpSuit;
          if (aT != bT) return aT ? 1 : -1;
          return b.rank!.value.compareTo(a.rank!.value);
        });
        return masters.first;
      }
    }

    final aces = legalCards
        .where(
          (c) =>
              !c.isJoker &&
              c.rank == Rank.ace &&
              (trumpSuit == null || c.suit != trumpSuit),
        )
        .toList();

    if (aces.isNotEmpty) {
      final aceWithKing = aces.where(
        (a) => legalCards.any(
          (c) => !c.isJoker && c.suit == a.suit && c.rank == Rank.king,
        ),
      );
      if (aceWithKing.isNotEmpty) return aceWithKing.first;

      final singletonAce = aces.where(
        (a) =>
            legalCards.where((c) => !c.isJoker && c.suit == a.suit).length == 1,
      );
      if (singletonAce.isNotEmpty) return singletonAce.first;

      return aces.first;
    }

    if (context != null && context.isBiddingTeam && trumpSuit != null) {
      final myTrumps = legalCards
          .where((c) => !c.isJoker && c.suit == trumpSuit)
          .toList();
      if (myTrumps.length >= 3) {
        myTrumps.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
        return myTrumps.first;
      }
    }

    if (context?.tracker != null) {
      final partnerSeat = context!.partnerSeat;
      final partnerVoids = context.tracker!.knownVoids[partnerSeat] ?? {};
      for (final voidSuit in partnerVoids) {
        if (voidSuit == trumpSuit) continue;
        final suitCards = legalCards
            .where((c) => !c.isJoker && c.suit == voidSuit)
            .toList();
        if (suitCards.isNotEmpty) {
          suitCards.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
          return suitCards.first;
        }
      }
    }

    if (context != null && !context.isBiddingTeam) {
      final nonTrumpSingles = legalCards.where((c) {
        if (c.isJoker) return false;
        if (c.suit == trumpSuit) return false;
        return legalCards.where((o) => !o.isJoker && o.suit == c.suit).length ==
            1;
      }).toList();
      if (nonTrumpSingles.isNotEmpty) return nonTrumpSingles.first;
    }

    final nonTrump = trumpSuit != null
        ? legalCards.where((c) => !c.isJoker && c.suit != trumpSuit).toList()
        : legalCards.where((c) => !c.isJoker).toList();

    if (nonTrump.isNotEmpty) {
      final counts = countBySuit(nonTrump);
      final suitGroups = <Suit, List<GameCard>>{};
      for (final c in nonTrump) {
        suitGroups.putIfAbsent(c.suit!, () => []).add(c);
      }

      final sortedSuits = suitGroups.entries.toList()
        ..sort((a, b) {
          final lenCmp = counts[b.key]!.compareTo(counts[a.key]!);
          if (lenCmp != 0) return lenCmp;
          final aMax = a.value
              .map((c) => c.rank!.value)
              .reduce((a, b) => a > b ? a : b);
          final bMax = b.value
              .map((c) => c.rank!.value)
              .reduce((a, b) => a > b ? a : b);
          return bMax.compareTo(aMax);
        });

      final bestSuitCards = sortedSuits.first.value;
      bestSuitCards.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return bestSuitCards.first;
    }

    final sorted = legalCards.where((c) => !c.isJoker).toList()
      ..sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
    return sorted.isNotEmpty ? sorted.first : legalCards.first;
  }

  static GameCard _selectFollow({
    required List<GameCard> legalCards,
    required List<GameCard> hand,
    required List<({String playerUid, GameCard card})> trickPlays,
    required Suit? trumpSuit,
    required Suit? ledSuit,
    String? partnerUid,
    GameContext? context,
  }) {
    final winningPlay = _winningPlay(trickPlays, trumpSuit, ledSuit);
    final partnerWinning =
        partnerUid != null && winningPlay?.playerUid == partnerUid;
    final hasJoker = legalCards.any((c) => c.isJoker);
    final myPosition = trickPlays.length;

    final followingSuit =
        ledSuit != null &&
        legalCards.every((c) => !c.isJoker && c.suit == ledSuit);

    if (context != null) {
      if (context.isBiddingTeam && context.tricksNeededForBid <= 0) {
        return _strategicDump(legalCards, hand, trumpSuit);
      }
      if (_defenderDumpMode(context) || _defenderBidAlreadyLost(context)) {
        return _strategicDump(legalCards, hand, trumpSuit);
      }
      if (!context.isBiddingTeam && context.tricksNeededForBid == 1) {
        if (hasJoker) return legalCards.firstWhere((c) => c.isJoker);
        if (trumpSuit != null) {
          final trumpCards = legalCards
              .where((c) => !c.isJoker && c.suit == trumpSuit)
              .toList();
          final winningTrumps = _cardsBeating(
            trumpCards,
            trickPlays,
            trumpSuit,
            ledSuit,
          );
          if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
        }
      }
    }

    if (partnerUid != null &&
        trickPlays.isNotEmpty &&
        trickPlays.first.playerUid == partnerUid &&
        _isLowLead(trickPlays.first.card) &&
        (myPosition == 1 || myPosition == 2)) {
      final w = _winningPlay(trickPlays, trumpSuit, ledSuit);
      if (w != null && w.playerUid == partnerUid) {
        return _lowest(legalCards);
      }
    }

    if (context?.isForcedBid == true) {
      if (followingSuit) {
        final aces = legalCards.where((c) => c.rank == Rank.ace).toList();
        if (aces.isNotEmpty) return aces.first;
        return _lowest(legalCards);
      }
      return _strategicDump(legalCards, hand, trumpSuit);
    }

    if (hand.length <= 2 &&
        hasJoker &&
        hand.where((c) => !c.isJoker).length <= 1) {
      return legalCards.firstWhere((c) => c.isJoker);
    }

    if (followingSuit) {
      final urgency = context?.roundControlUrgency ?? 0;
      final canBeat = _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
      final shouldProtectPartner =
          partnerWinning && myPosition <= 2 && urgency < 0.8;
      if (shouldProtectPartner) {
        return _lowest(legalCards);
      }
      final mustSecureNow =
          partnerWinning && urgency >= 0.8 && canBeat.isNotEmpty;
      if (mustSecureNow) {
        return _lowest(canBeat);
      }

      // Last to play: if partner already has the trick, do not overtake.
      if (partnerWinning && myPosition == 3) {
        return _lowest(legalCards);
      }
      if (myPosition == 3) {
        final winners = _cardsBeating(
          legalCards,
          trickPlays,
          trumpSuit,
          ledSuit,
        );
        return _lowest(winners.isNotEmpty ? winners : legalCards);
      } else {
        final winners = _cardsBeating(
          legalCards,
          trickPlays,
          trumpSuit,
          ledSuit,
        );
        if (winners.isNotEmpty) {
          return _lowest(winners);
        }
        return _lowest(legalCards);
      }
    }

    if (partnerWinning) {
      if (hasJoker) {
        final nonJoker = legalCards.where((c) => !c.isJoker).toList();
        if (_jokerPoisonRisk(nonJoker, hand, context?.tracker)) {
          return legalCards.firstWhere((c) => c.isJoker);
        }
      }
      return _strategicDump(legalCards, hand, trumpSuit);
    }

    if (hasJoker) {
      final nonJoker = legalCards.where((c) => !c.isJoker).toList();

      if (_cannotWinWithoutJoker(nonJoker, trickPlays, trumpSuit, ledSuit) &&
          !partnerWinning) {
        return legalCards.firstWhere((c) => c.isJoker);
      }

      if (_jokerPoisonRisk(nonJoker, hand, context?.tracker)) {
        return legalCards.firstWhere((c) => c.isJoker);
      }

      double urgency = 0.0;

      if (context != null) {
        final needed = context.isBiddingTeam
            ? context.tricksNeededForBid
            : (8 - (context.currentBid?.value ?? 5) + 1) -
                  context.opponentTricks;
        if (needed == 1) urgency += 0.5;
      }

      final opponentTrumped =
          trumpSuit != null &&
          trickPlays.any((p) => !p.card.isJoker && p.card.suit == trumpSuit);
      if (opponentTrumped) urgency += 0.3;

      if (hand.length <= 3) urgency += 0.3;

      if (partnerWinning) urgency -= 0.8;

      // Threshold inlined; PlayStrategy will be rewritten in Task 8.
      if (urgency >= 0.08) {
        return legalCards.firstWhere((c) => c.isJoker);
      }
    }

    if (context?.tracker != null && trumpSuit != null) {
      final trumpsOut = context!.tracker!.trumpsRemaining(trumpSuit, hand);
      final myTrumps = legalCards
          .where((c) => !c.isJoker && c.suit == trumpSuit)
          .toList();
      if (trumpsOut <= 1 && myTrumps.length == 1) {
        final trickHasHonor = _trickHasAceOrKing(trickPlays);
        if (!trickHasHonor && (context.tricksNeededForBid) > 1) {
          return _strategicDump(legalCards, hand, trumpSuit);
        }
      }
    }

    if (trumpSuit != null) {
      final trumpCards = legalCards
          .where((c) => !c.isJoker && c.suit == trumpSuit)
          .toList();
      if (trumpCards.isNotEmpty) {
        final winningTrumps = _cardsBeating(
          trumpCards,
          trickPlays,
          trumpSuit,
          ledSuit,
        );
        if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
        return _strategicDump(legalCards, hand, trumpSuit);
      }
    }

    return _strategicDump(legalCards, hand, trumpSuit);
  }

  static GameCard _strategicDump(
    List<GameCard> legalCards,
    List<GameCard> hand,
    Suit? trumpSuit,
  ) {
    final dumpable = legalCards.where((c) => !c.isJoker).toList();
    if (dumpable.isEmpty) return legalCards.first;

    final singletons = dumpable.where((c) {
      final suitCount = hand
          .where((h) => !h.isJoker && h.suit == c.suit)
          .length;
      return suitCount == 1 && c.suit != trumpSuit;
    }).toList();
    if (singletons.isNotEmpty) {
      singletons.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return singletons.first;
    }

    final safeToBreak = dumpable.where((c) {
      if (c.suit == trumpSuit) return false;
      if (c.rank == Rank.king &&
          hand.any((h) => h.suit == c.suit && h.rank == Rank.ace)) {
        return false;
      }
      if (c.rank == Rank.queen &&
          hand.any((h) => h.suit == c.suit && h.rank == Rank.king)) {
        return false;
      }
      return true;
    }).toList();

    if (safeToBreak.isNotEmpty) {
      safeToBreak.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return safeToBreak.first;
    }

    final nonTrump = dumpable.where((c) => c.suit != trumpSuit).toList();
    if (nonTrump.isNotEmpty) {
      nonTrump.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return nonTrump.first;
    }
    dumpable.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return dumpable.first;
  }

  static GameCard _lowest(List<GameCard> cards) {
    final nonJoker = cards.where((c) => !c.isJoker).toList();
    if (nonJoker.isEmpty) return cards.first;
    nonJoker.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return nonJoker.first;
  }

  static ({String playerUid, GameCard card})? _winningPlay(
    List<({String playerUid, GameCard card})> plays,
    Suit? trumpSuit,
    Suit? ledSuit,
  ) {
    if (plays.isEmpty) return null;

    for (final play in plays) {
      if (play.card.isJoker) return play;
    }

    if (ledSuit == null && plays.isNotEmpty && !plays.first.card.isJoker) {
      ledSuit = plays.first.card.suit;
    }

    var bestPlay = plays.first;
    for (int i = 1; i < plays.length; i++) {
      if (TrickResolver.beats(
        plays[i].card,
        bestPlay.card,
        trumpSuit,
        ledSuit,
      )) {
        bestPlay = plays[i];
      }
    }
    return bestPlay;
  }

  static bool _jokerPoisonRisk(
    List<GameCard> nonJokerLegal,
    List<GameCard> hand,
    CardTracker? tracker,
  ) {
    if (nonJokerLegal.isEmpty) return true;
    if (nonJokerLegal.length <= 1) return true;
    if (tracker != null && nonJokerLegal.length <= 2) {
      return nonJokerLegal.any((c) => !tracker.isSuitExhausted(c.suit!, hand));
    }
    return false;
  }

  static bool _trickHasAceOrKing(
    List<({String playerUid, GameCard card})> trickPlays,
  ) {
    return trickPlays.any(
      (p) =>
          !p.card.isJoker &&
          (p.card.rank == Rank.ace || p.card.rank == Rank.king),
    );
  }

  static bool _cannotWinWithoutJoker(
    List<GameCard> nonJokerLegal,
    List<({String playerUid, GameCard card})> trickPlays,
    Suit? trumpSuit,
    Suit? ledSuit,
  ) {
    if (nonJokerLegal.isEmpty) return true;
    final winners = _cardsBeating(
      nonJokerLegal,
      trickPlays,
      trumpSuit,
      ledSuit,
    );
    return winners.isEmpty;
  }

  static List<GameCard> _cardsBeating(
    List<GameCard> candidates,
    List<({String playerUid, GameCard card})> trickPlays,
    Suit? trumpSuit,
    Suit? ledSuit,
  ) {
    final best = _winningPlay(trickPlays, trumpSuit, ledSuit);
    if (best == null) return candidates;

    return candidates
        .where((c) => TrickResolver.beats(c, best.card, trumpSuit, ledSuit))
        .toList();
  }
}
