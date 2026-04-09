import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/logic/play_validator.dart';
import 'package:koutbh/shared/logic/trick_resolver.dart';
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
        _selectLead(legalCards, hand, trumpSuit, context),
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

  // ---------------------------------------------------------------------------
  // Legal plays
  // ---------------------------------------------------------------------------

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

    // Never lead Joker (validator already excludes it, but double-check).
    if (isLead) {
      final nonJoker = legal.where((c) => !c.isJoker).toList();
      if (nonJoker.isNotEmpty) return nonJoker;
    }

    return legal;
  }

  // ---------------------------------------------------------------------------
  // LEADING
  // ---------------------------------------------------------------------------

  static GameCard _selectLead(
    List<GameCard> legalCards,
    List<GameCard> hand,
    Suit? trumpSuit,
    GameContext? context,
  ) {
    // 1. Master cards — via CardTracker.isHighestRemaining().
    //    Non-trump masters before trump masters.
    if (context?.tracker != null) {
      final masters = legalCards
          .where(
            (c) =>
                !c.isJoker &&
                context!.tracker!.isHighestRemaining(c, hand),
          )
          .toList();
      if (masters.isNotEmpty) {
        // Sort: non-trump first, then by rank descending.
        masters.sort((a, b) {
          final aIsTrump = a.suit == trumpSuit;
          final bIsTrump = b.suit == trumpSuit;
          if (aIsTrump != bIsTrump) return aIsTrump ? 1 : -1;
          return b.rank!.value.compareTo(a.rank!.value);
        });
        return masters.first;
      }
    }

    // 2. Non-trump Aces — prefer Ace with King in same suit, then any Ace.
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
        (a) => hand.any(
          (c) => !c.isJoker && c.suit == a.suit && c.rank == Rank.king,
        ),
      );
      if (aceWithKing.isNotEmpty) return aceWithKing.first;
      return aces.first;
    }

    // 3. Singleton voids — lead a singleton non-trump card when you have trump.
    if (trumpSuit != null) {
      final hasTrump =
          hand.any((c) => !c.isJoker && c.suit == trumpSuit);
      if (hasTrump) {
        final singletons = legalCards.where((c) {
          if (c.isJoker || c.suit == trumpSuit) return false;
          return hand
                  .where((h) => !h.isJoker && h.suit == c.suit)
                  .length ==
              1;
        }).toList();
        if (singletons.isNotEmpty) {
          singletons.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
          return singletons.first;
        }
      }
    }

    // 4. Trump strip — bidding team with 3+ trumps: lead highest trump.
    if (context != null && context.isBiddingTeam && trumpSuit != null) {
      final myTrumps = legalCards
          .where((c) => !c.isJoker && c.suit == trumpSuit)
          .toList();
      if (myTrumps.length >= 3) {
        myTrumps.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
        return myTrumps.first;
      }
    }

    // 5. Partner void exploit — lead into a suit partner is void in.
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

    // 6. Longest non-trump suit — lead lowest card.
    final nonTrump = trumpSuit != null
        ? legalCards.where((c) => !c.isJoker && c.suit != trumpSuit).toList()
        : legalCards.where((c) => !c.isJoker).toList();

    if (nonTrump.isNotEmpty) {
      final suitGroups = <Suit, List<GameCard>>{};
      for (final c in nonTrump) {
        suitGroups.putIfAbsent(c.suit!, () => []).add(c);
      }
      final sortedSuits = suitGroups.entries.toList()
        ..sort((a, b) {
          final lenCmp = b.value.length.compareTo(a.value.length);
          if (lenCmp != 0) return lenCmp;
          // Tie-break by highest rank in suit (prefer stronger suits).
          final aMax = a.value
              .map((c) => c.rank!.value)
              .reduce((x, y) => x > y ? x : y);
          final bMax = b.value
              .map((c) => c.rank!.value)
              .reduce((x, y) => x > y ? x : y);
          return bMax.compareTo(aMax);
        });
      final bestSuitCards = sortedSuits.first.value;
      bestSuitCards.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return bestSuitCards.first;
    }

    // 7. Fallback — highest non-Joker card.
    final sorted = legalCards.where((c) => !c.isJoker).toList()
      ..sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
    return sorted.isNotEmpty ? sorted.first : legalCards.first;
  }

  // ---------------------------------------------------------------------------
  // FOLLOWING
  // ---------------------------------------------------------------------------

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
    final myPosition = trickPlays.length; // 0-indexed: 1,2,3

    // Am I following the led suit?
    final followingSuit = ledSuit != null &&
        legalCards.any((c) => !c.isJoker && c.suit == ledSuit);

    // ----- Trick countdown: play Joker now to avoid having to lead it later -----
    // If 2 or fewer tricks remain and we have Joker, play it while following.
    if (context != null) {
      final tricksRemaining = 8 - context.tricksPlayed;
      if (tricksRemaining <= 2 && hasJoker) {
        final joker = hand.firstWhere((c) => c.isJoker);
        if (legalCards.contains(joker)) {
          return joker;
        }
      }
    }

    // ----- Poison prevention (always check first) -----
    // If hand has <= 2 cards and one is Joker, play Joker NOW.
    if (hand.length <= 2 && hasJoker) {
      return legalCards.firstWhere((c) => c.isJoker);
    }

    // ----- Following suit -----
    if (followingSuit) {
      return _followSuit(
        legalCards: legalCards,
        trickPlays: trickPlays,
        trumpSuit: trumpSuit,
        ledSuit: ledSuit,
        partnerWinning: partnerWinning,
        myPosition: myPosition,
      );
    }

    // ----- Void in led suit -----
    return _voidFollow(
      legalCards: legalCards,
      hand: hand,
      trickPlays: trickPlays,
      trumpSuit: trumpSuit,
      ledSuit: ledSuit,
      partnerWinning: partnerWinning,
      myPosition: myPosition,
      hasJoker: hasJoker,
      tracker: context?.tracker,
    );
  }

  /// When we must follow the led suit.
  static GameCard _followSuit({
    required List<GameCard> legalCards,
    required List<({String playerUid, GameCard card})> trickPlays,
    required Suit? trumpSuit,
    required Suit? ledSuit,
    required bool partnerWinning,
    required int myPosition,
  }) {
    final suitCards =
        legalCards.where((c) => !c.isJoker && c.suit == ledSuit).toList();
    final canBeat = _cardsBeating(suitCards, trickPlays, trumpSuit, ledSuit);

    // Partner winning + last to play → play lowest.
    if (partnerWinning && myPosition == 3) {
      return _lowest(suitCards);
    }

    // Partner winning + opponent still to play → play lowest.
    if (partnerWinning) {
      return _lowest(suitCards);
    }

    // Opponent winning + can beat → play lowest winner.
    if (canBeat.isNotEmpty) {
      return _lowest(canBeat);
    }

    // Cannot beat → play lowest.
    return _lowest(suitCards);
  }

  /// When we are void in the led suit.
  static GameCard _voidFollow({
    required List<GameCard> legalCards,
    required List<GameCard> hand,
    required List<({String playerUid, GameCard card})> trickPlays,
    required Suit? trumpSuit,
    required Suit? ledSuit,
    required bool partnerWinning,
    required int myPosition,
    required bool hasJoker,
    CardTracker? tracker,
  }) {
    final trumpCards = trumpSuit != null
        ? legalCards
              .where((c) => !c.isJoker && c.suit == trumpSuit)
              .toList()
        : <GameCard>[];
    final winningTrumps =
        _cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);

    // Partner winning safely (last to play, no opponent after) → dump.
    if (partnerWinning && myPosition == 3) {
      return _strategicDump(legalCards, hand, trumpSuit);
    }

    // Partner winning but opponent still to play → try to guarantee with trump.
    if (partnerWinning) {
      if (tracker != null && trumpCards.isNotEmpty && trumpSuit != null) {
        final trumpsOut = tracker.trumpsRemaining(trumpSuit, hand);
        if (trumpsOut == 0) {
          // No trumps remaining in opponent hands — any trump guarantees the trick.
          return _lowest(trumpCards);
        }
        // Check if my highest trump beats all remaining trumps in opponent hands.
        final myHighestTrump = trumpCards.reduce(
          (a, b) => a.rank!.value > b.rank!.value ? a : b,
        );
        final remaining = tracker.remainingCards(hand);
        final remainingTrumps = remaining.where(
          (c) => !c.isJoker && c.suit == trumpSuit,
        );
        final canGuarantee = remainingTrumps.every(
          (c) => myHighestTrump.rank!.value > c.rank!.value,
        );
        if (canGuarantee) {
          return myHighestTrump;
        }
      }
      return _strategicDump(legalCards, hand, trumpSuit);
    }

    // Opponent winning + have winning trump → play lowest winning trump.
    if (winningTrumps.isNotEmpty) {
      return _lowest(winningTrumps);
    }

    // Opponent winning + have trump but none beat current winner → play lowest trump.
    if (trumpCards.isNotEmpty) {
      return _lowest(trumpCards);
    }

    // Can't win with trump → try Joker.
    if (hasJoker) {
      final nonJokerCanWin =
          _cardsBeating(
            legalCards.where((c) => !c.isJoker).toList(),
            trickPlays,
            trumpSuit,
            ledSuit,
          ).isNotEmpty;
      if (!nonJokerCanWin) {
        return legalCards.firstWhere((c) => c.isJoker);
      }
    }

    // No trump, no Joker, can't win → dump.
    return _strategicDump(legalCards, hand, trumpSuit);
  }

  // ---------------------------------------------------------------------------
  // Strategic dump — simplified 3-tier
  // ---------------------------------------------------------------------------

  static GameCard _strategicDump(
    List<GameCard> legalCards,
    List<GameCard> hand,
    Suit? trumpSuit,
  ) {
    final dumpable = legalCards.where((c) => !c.isJoker).toList();
    if (dumpable.isEmpty) return legalCards.first;

    // Tier 1: Singletons in non-trump suits (lowest rank) — creates voids.
    final singletons = dumpable.where((c) {
      final suitCount =
          hand.where((h) => !h.isJoker && h.suit == c.suit).length;
      return suitCount == 1 && c.suit != trumpSuit;
    }).toList();
    if (singletons.isNotEmpty) {
      singletons.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return singletons.first;
    }

    // Tier 2: Lowest card from weakest non-trump suit — don't break AK/KQ combos.
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

    // Tier 3: Lowest non-trump, or lowest trump if only trump remains.
    final nonTrump = dumpable.where((c) => c.suit != trumpSuit).toList();
    if (nonTrump.isNotEmpty) {
      nonTrump.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
      return nonTrump.first;
    }
    dumpable.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return dumpable.first;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Lowest non-Joker card by rank. Falls back to Joker if all are Jokers.
  static GameCard _lowest(List<GameCard> cards) {
    final nonJoker = cards.where((c) => !c.isJoker).toList();
    if (nonJoker.isEmpty) return cards.first;
    nonJoker.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return nonJoker.first;
  }

  /// Determine the current winning play in a partial trick.
  static ({String playerUid, GameCard card})? _winningPlay(
    List<({String playerUid, GameCard card})> plays,
    Suit? trumpSuit,
    Suit? ledSuit,
  ) {
    if (plays.isEmpty) return null;

    // Joker always wins.
    for (final play in plays) {
      if (play.card.isJoker) return play;
    }

    // Infer ledSuit from first play if not provided.
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

  /// Filter candidates to only those that beat the current trick winner.
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
