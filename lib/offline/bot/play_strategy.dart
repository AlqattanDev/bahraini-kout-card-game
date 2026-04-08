import 'package:koutbh/shared/models/card.dart';
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
    // Determine which cards are legal to play
    final legalCards = _legalPlays(hand, ledSuit, trickPlays.isEmpty,
        trumpSuit: trumpSuit, isKout: isKout, isFirstTrick: isFirstTrick);

    if (legalCards.length == 1) {
      return PlayCardAction(legalCards.first);
    }

    if (trickPlays.isEmpty) {
      // LEADING
      return PlayCardAction(
          _selectLead(legalCards, trumpSuit, context: context, hand: hand));
    }

    // FOLLOWING
    return PlayCardAction(_selectFollow(
      legalCards: legalCards,
      hand: hand,
      trickPlays: trickPlays,
      trumpSuit: trumpSuit,
      ledSuit: ledSuit,
      partnerUid: partnerUid,
      context: context,
    ));
  }

  /// Returns legally playable cards, delegating to [PlayValidator] as the
  /// single source of truth, then applying bot-specific filtering.
  static List<GameCard> _legalPlays(
      List<GameCard> hand, Suit? ledSuit, bool isLead,
      {Suit? trumpSuit, bool isKout = false, bool isFirstTrick = false}) {
    final legal = PlayValidator.playableForCurrentTrick(
      hand: hand,
      trickHasNoPlaysYet: isLead,
      ledSuit: ledSuit,
      trumpSuit: trumpSuit,
      bidIsKout: isKout,
      noTricksCompletedYet: isFirstTrick,
    ).toList();

    // Bot-specific: avoid leading with Joker (legal but triggers instant loss)
    if (isLead) {
      final nonJoker = legal.where((c) => !c.isJoker).toList();
      if (nonJoker.isNotEmpty) return nonJoker;
    }

    return legal;
  }

  static GameCard _selectLead(List<GameCard> legalCards, Suit? trumpSuit,
      {GameContext? context, List<GameCard>? hand}) {
    final fullHand = hand ?? legalCards;

    // 5.6 — Master card leads (requires CardTracker): guaranteed winners
    if (context?.tracker != null) {
      final masters = legalCards
          .where((c) =>
              !c.isJoker &&
              c.suit != trumpSuit &&
              context!.tracker!.isHighestRemaining(c, fullHand))
          .toList();
      if (masters.isNotEmpty) return masters.first;
    }

    // T1.1 — Ace-first: lead an Ace if we have one (non-trump)
    final aces = legalCards
        .where((c) =>
            !c.isJoker &&
            c.rank == Rank.ace &&
            (trumpSuit == null || c.suit != trumpSuit))
        .toList();

    if (aces.isNotEmpty) {
      // Prefer Ace where we also hold King of same suit
      final aceWithKing = aces.where((a) => legalCards.any(
          (c) => !c.isJoker && c.suit == a.suit && c.rank == Rank.king));
      if (aceWithKing.isNotEmpty) return aceWithKing.first;

      // Prefer singleton Ace (only card in that suit → creates void)
      final singletonAce = aces.where((a) =>
          legalCards.where((c) => !c.isJoker && c.suit == a.suit).length == 1);
      if (singletonAce.isNotEmpty) return singletonAce.first;

      // Any Ace
      return aces.first;
    }

    // 5.2 — Trump strip leads for bidding team with 3+ trump
    if (context != null && context.isBiddingTeam && trumpSuit != null) {
      final myTrumps = legalCards
          .where((c) => !c.isJoker && c.suit == trumpSuit)
          .toList();
      if (myTrumps.length >= 3) {
        myTrumps.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
        return myTrumps.first; // lead highest trump to strip opponents
      }
    }

    // 5.3 — Partner-void leads (requires CardTracker)
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
          return suitCards.first; // lead low into partner's void
        }
      }
    }

    // 5.4 — Short-suit leads for defense: singleton non-trump to create void
    if (context != null && !context.isBiddingTeam) {
      final nonTrumpSingles = legalCards.where((c) {
        if (c.isJoker) return false;
        if (c.suit == trumpSuit) return false;
        return legalCards.where((o) => !o.isJoker && o.suit == c.suit).length ==
            1;
      }).toList();
      if (nonTrumpSingles.isNotEmpty) return nonTrumpSingles.first;
    }

    // 5.5 — Fallback: lead LOW from longest non-trump suit (probing)
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

      // Lead LOW from longest suit — probe cheaply, preserve honors
      final bestSuitCards = sortedSuits.first.value;
      bestSuitCards.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return bestSuitCards.first;
    }

    // Only trump left, lead highest
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

    final followingSuit = ledSuit != null &&
        legalCards.every((c) => !c.isJoker && c.suit == ledSuit);

    // 6.5 — Defensive play: bid already made → dump to end round
    if (context != null) {
      final needed = context.tricksNeededForBid;
      if (context.isBiddingTeam && needed <= 0) {
        return _strategicDump(legalCards, hand, trumpSuit);
      }
      // Defending and they need exactly 1 more: MUST win this one
      if (!context.isBiddingTeam && needed == 1) {
        if (hasJoker) return legalCards.firstWhere((c) => c.isJoker);
        if (trumpSuit != null) {
          final trumpCards = legalCards
              .where((c) => !c.isJoker && c.suit == trumpSuit)
              .toList();
          final winningTrumps =
              _cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);
          if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
        }
      }
    }

    // 6.6 — Forced-bid survival mode
    if (context?.isForcedBid == true) {
      if (followingSuit) {
        final aces = legalCards.where((c) => c.rank == Rank.ace).toList();
        if (aces.isNotEmpty) return aces.first;
        return _lowest(legalCards);
      }
      return _strategicDump(legalCards, hand, trumpSuit);
    }

    // Following suit
    if (followingSuit) {
      if (myPosition == 3) {
        if (partnerWinning) return _lowest(legalCards);
        final winners =
            _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
        return _lowest(winners.isNotEmpty ? winners : legalCards);
      } else {
        final winners =
            _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
        if (winners.isNotEmpty) return _lowest(winners);
        return _lowest(legalCards);
      }
    }

    // Void — partner winning: dump strategically, but dump Joker if poison
    if (partnerWinning) {
      if (hasJoker) {
        final nonJoker = legalCards.where((c) => !c.isJoker).toList();
        if (_jokerPoisonRisk(nonJoker, hand, context?.tracker)) {
          return legalCards.firstWhere((c) => c.isJoker);
        }
      }
      return _strategicDump(legalCards, hand, trumpSuit);
    }

    // 7.5 — Endgame Joker: if <=2 cards, one is Joker, might be forced to lead
    if (hand.length <= 2 &&
        hasJoker &&
        hand.where((c) => !c.isJoker).length <= 1) {
      return legalCards.firstWhere((c) => c.isJoker);
    }

    // Void, NOT partner winning — Joker decision (P7 urgency scoring)
    if (hasJoker) {
      final nonJoker = legalCards.where((c) => !c.isJoker).toList();

      if (_jokerPoisonRisk(nonJoker, hand, context?.tracker)) {
        return legalCards.firstWhere((c) => c.isJoker);
      }

      // 7.4 — Joker urgency scoring
      double urgency = 0.0;

      if (context != null) {
        final needed = context.isBiddingTeam
            ? context.tricksNeededForBid
            : (8 - (context.currentBid?.value ?? 5) + 1) -
                context.opponentTricks;
        if (needed == 1) urgency += 0.5;
      }

      final opponentTrumped = trumpSuit != null &&
          trickPlays.any((p) => !p.card.isJoker && p.card.suit == trumpSuit);
      if (opponentTrumped) urgency += 0.3;

      if (hand.length <= 3) urgency += 0.3;

      if (partnerWinning) urgency -= 0.8;

      final jokerThreshold = context?.difficulty.jokerUrgencyThreshold ?? 0.3;
      if (urgency >= jokerThreshold) {
        return legalCards.firstWhere((c) => c.isJoker);
      }
    }

    // 6.3 — Trump conservation (requires CardTracker)
    if (context?.tracker != null && trumpSuit != null) {
      final trumpsOut = context!.tracker!.trumpsRemaining(trumpSuit, hand);
      final myTrumps =
          legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
      if (trumpsOut <= 1 && myTrumps.length == 1) {
        final trickHasHonor = _trickHasAceOrKing(trickPlays);
        if (!trickHasHonor && (context.tricksNeededForBid) > 1) {
          return _strategicDump(legalCards, hand, trumpSuit);
        }
      }
    }

    // Try to trump in
    if (trumpSuit != null) {
      final trumpCards =
          legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
      if (trumpCards.isNotEmpty) {
        // 6.4 — Overtrump: skip low-value tricks as defender
        final trickHasValue = _trickHasAceOrKing(trickPlays);
        if (!trickHasValue && context != null && !context.isBiddingTeam) {
          return _strategicDump(legalCards, hand, trumpSuit);
        }

        final winningTrumps =
            _cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);
        if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
        return _lowest(trumpCards);
      }
    }

    return _strategicDump(legalCards, hand, trumpSuit);
  }

  /// 6.2 — Strategic dumping: prefer creating voids and preserving combos.
  static GameCard _strategicDump(
      List<GameCard> legalCards, List<GameCard> hand, Suit? trumpSuit) {
    final dumpable = legalCards.where((c) => !c.isJoker).toList();
    if (dumpable.isEmpty) return legalCards.first;

    // Prefer singletons in non-trump suits → clears void for future ruffing
    final singletons = dumpable.where((c) {
      final suitCount =
          hand.where((h) => !h.isJoker && h.suit == c.suit).length;
      return suitCount == 1 && c.suit != trumpSuit;
    }).toList();
    if (singletons.isNotEmpty) {
      singletons.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return singletons.first;
    }

    // Avoid breaking honor combos
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

    // Fallback: lowest non-trump
    final nonTrump =
        dumpable.where((c) => c.suit != trumpSuit).toList();
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

    // Joker always wins
    for (final play in plays) {
      if (play.card.isJoker) return play;
    }

    if (ledSuit == null && plays.isNotEmpty && !plays.first.card.isJoker) {
      ledSuit = plays.first.card.suit;
    }

    var bestPlay = plays.first;
    for (int i = 1; i < plays.length; i++) {
      if (TrickResolver.beats(plays[i].card, bestPlay.card, trumpSuit, ledSuit)) {
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
