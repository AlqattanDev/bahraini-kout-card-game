import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/offline/player_controller.dart';

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
  }) {
    // Determine which cards are legal to play
    final legalCards = _legalPlays(hand, ledSuit, trickPlays.isEmpty,
        trumpSuit: trumpSuit, isKout: isKout, isFirstTrick: isFirstTrick);

    if (legalCards.length == 1) {
      return PlayCardAction(legalCards.first);
    }

    if (trickPlays.isEmpty) {
      // LEADING
      return PlayCardAction(_selectLead(legalCards, trumpSuit));
    }

    // FOLLOWING
    return PlayCardAction(_selectFollow(
      legalCards: legalCards,
      hand: hand,
      trickPlays: trickPlays,
      trumpSuit: trumpSuit,
      ledSuit: ledSuit,
      partnerUid: partnerUid,
    ));
  }

  static List<GameCard> _legalPlays(
      List<GameCard> hand, Suit? ledSuit, bool isLead,
      {Suit? trumpSuit, bool isKout = false, bool isFirstTrick = false}) {
    if (isLead) {
      // Kout rule: first trick lead must be trump if holding trump
      if (isKout && isFirstTrick && trumpSuit != null) {
        final trumpCards =
            hand.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
        if (trumpCards.isNotEmpty) return trumpCards;
      }
      // Can't lead with joker
      final nonJoker = hand.where((c) => !c.isJoker).toList();
      return nonJoker.isEmpty ? hand.toList() : nonJoker;
    }

    if (ledSuit != null) {
      final suitCards =
          hand.where((c) => !c.isJoker && c.suit == ledSuit).toList();
      if (suitCards.isNotEmpty) return suitCards;
    }

    return hand.toList();
  }

  static GameCard _selectLead(List<GameCard> legalCards, Suit? trumpSuit) {
    // Ace-first: lead an Ace if we have one (non-trump)
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

    // Fallback: lead from longest non-trump suit with highest card
    final nonTrump = trumpSuit != null
        ? legalCards.where((c) => !c.isJoker && c.suit != trumpSuit).toList()
        : legalCards.where((c) => !c.isJoker).toList();

    if (nonTrump.isNotEmpty) {
      // Group by suit, pick longest
      final suitGroups = <Suit, List<GameCard>>{};
      for (final c in nonTrump) {
        suitGroups.putIfAbsent(c.suit!, () => []).add(c);
      }

      final sortedSuits = suitGroups.entries.toList()
        ..sort((a, b) {
          final lenCmp = b.value.length.compareTo(a.value.length);
          if (lenCmp != 0) return lenCmp;
          // Tie: highest card
          final aMax = a.value
              .map((c) => c.rank!.value)
              .reduce((a, b) => a > b ? a : b);
          final bMax = b.value
              .map((c) => c.rank!.value)
              .reduce((a, b) => a > b ? a : b);
          return bMax.compareTo(aMax);
        });

      // Lead highest from longest suit
      final bestSuitCards = sortedSuits.first.value;
      bestSuitCards.sort((a, b) => b.rank!.value.compareTo(a.rank!.value));
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
  }) {
    final winningPlay = _winningPlay(trickPlays, trumpSuit, ledSuit);
    final partnerWinning =
        partnerUid != null && winningPlay?.playerUid == partnerUid;
    final hasJoker = legalCards.any((c) => c.isJoker);
    final myPosition = trickPlays.length; // 0=lead, 1=2nd, 2=3rd, 3=4th/last

    // Following suit (Joker not in legalCards when we have the led suit)
    final followingSuit = ledSuit != null &&
        legalCards.every((c) => !c.isJoker && c.suit == ledSuit);

    if (followingSuit) {
      if (myPosition == 3) {
        // Last to play: perfect info. Win cheaply or dump.
        if (partnerWinning) return _lowest(legalCards);
        final winners =
            _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
        return _lowest(winners.isNotEmpty ? winners : legalCards);
      } else {
        // Not last: play to win (can't assume partner covers)
        final winners =
            _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
        if (winners.isNotEmpty) return _lowest(winners);
        return _lowest(legalCards);
      }
    }

    // Void in led suit — partner winning: dump low, but dump Joker if poison imminent
    if (partnerWinning) {
      if (hasJoker && hand.length <= 2) {
        return legalCards.firstWhere((c) => c.isJoker); // poison risk
      }
      return _lowest(legalCards); // don't trump partner
    }

    // Void in led suit, NOT partner winning — Joker decision
    if (hasJoker) {
      final nonJoker = legalCards.where((c) => !c.isJoker).toList();

      // POISON CHECK: if only 1 non-Joker card left, Joker WILL be last card next trick
      if (nonJoker.length <= 1) {
        return legalCards.firstWhere((c) => c.isJoker); // dump now
      }

      // Use Joker to steal: opponent trumped or played high card
      final opponentTrumped = trumpSuit != null &&
          trickPlays.any((p) => !p.card.isJoker && p.card.suit == trumpSuit);
      if (opponentTrumped) {
        return legalCards.firstWhere((c) => c.isJoker);
      }

      // Late game (<=3 cards) and void: use Joker rather than risk poison
      if (hand.length <= 3) {
        return legalCards.firstWhere((c) => c.isJoker);
      }

      // Otherwise hold Joker
    }

    // Try to trump in
    if (trumpSuit != null) {
      final trumpCards =
          legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
      if (trumpCards.isNotEmpty) {
        final winningTrumps =
            _cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);
        if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
        return _lowest(trumpCards);
      }
    }

    return _lowest(legalCards);
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

    var best = plays.first;
    for (int i = 1; i < plays.length; i++) {
      if (_beats(plays[i].card, best.card, trumpSuit, ledSuit)) {
        best = plays[i];
      }
    }
    return best;
  }

  static bool _beats(
      GameCard a, GameCard b, Suit? trumpSuit, Suit? ledSuit) {
    if (a.isJoker) return true;
    if (b.isJoker) return false;

    // Trump beats non-trump
    if (trumpSuit != null) {
      if (a.suit == trumpSuit && b.suit != trumpSuit) return true;
      if (a.suit != trumpSuit && b.suit == trumpSuit) return false;
      if (a.suit == trumpSuit && b.suit == trumpSuit) {
        return a.rank!.value > b.rank!.value;
      }
    }

    // Same suit comparison
    if (a.suit == b.suit) return a.rank!.value > b.rank!.value;

    // Led suit beats non-led, non-trump
    if (ledSuit != null) {
      if (a.suit == ledSuit && b.suit != ledSuit) return true;
      if (a.suit != ledSuit && b.suit == ledSuit) return false;
    }

    return false;
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
        .where((c) => _beats(c, best.card, trumpSuit, ledSuit))
        .toList();
  }
}
