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
  }) {
    // Determine which cards are legal to play
    final legalCards = _legalPlays(hand, ledSuit, trickPlays.isEmpty);

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
      List<GameCard> hand, Suit? ledSuit, bool isLead) {
    if (isLead) {
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
    // Lead from longest non-trump suit with highest card
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
    // Check if partner is currently winning
    final winningPlay = _winningPlay(trickPlays, trumpSuit, ledSuit);
    final partnerWinning =
        partnerUid != null && winningPlay?.playerUid == partnerUid;

    // Check for Joker play opportunity: if holding Joker with <=2 other cards
    final joker = legalCards.where((c) => c.isJoker).toList();
    final nonJokerInHand = hand.where((c) => !c.isJoker).length;
    if (joker.isNotEmpty && nonJokerInHand <= 2 && !partnerWinning) {
      return joker.first;
    }

    // Following suit
    final followingSuit = ledSuit != null &&
        legalCards.every((c) => !c.isJoker && c.suit == ledSuit);

    if (followingSuit) {
      if (partnerWinning) {
        // Dump lowest
        return _lowest(legalCards);
      }

      // Can we win?
      final winningCards =
          _cardsBeating(legalCards, trickPlays, trumpSuit, ledSuit);
      if (winningCards.isNotEmpty) {
        // Play lowest winning card
        return _lowest(winningCards);
      }
      // Can't win, dump lowest
      return _lowest(legalCards);
    }

    // Void in led suit
    if (partnerWinning) {
      // Dump lowest from weakest suit
      return _dumpLowest(legalCards);
    }

    // Try to trump in
    if (trumpSuit != null) {
      final trumpCards =
          legalCards.where((c) => !c.isJoker && c.suit == trumpSuit).toList();
      if (trumpCards.isNotEmpty) {
        // Play lowest trump that wins
        final winningTrumps =
            _cardsBeating(trumpCards, trickPlays, trumpSuit, ledSuit);
        if (winningTrumps.isNotEmpty) return _lowest(winningTrumps);
        return _lowest(trumpCards);
      }
    }

    // Can't trump, dump lowest
    return _dumpLowest(legalCards);
  }

  static GameCard _lowest(List<GameCard> cards) {
    final nonJoker = cards.where((c) => !c.isJoker).toList();
    if (nonJoker.isEmpty) return cards.first;
    nonJoker.sort((a, b) => a.rank!.value.compareTo(b.rank!.value));
    return nonJoker.first;
  }

  static GameCard _dumpLowest(List<GameCard> cards) {
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
