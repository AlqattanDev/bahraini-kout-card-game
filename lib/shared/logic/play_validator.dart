import '../models/card.dart';

class PlayValidationResult {
  final bool isValid;
  final String? error;
  const PlayValidationResult.valid() : isValid = true, error = null;
  const PlayValidationResult.invalid(this.error) : isValid = false;
}

class PlayValidator {
  static PlayValidationResult validatePlay({
    required GameCard card,
    required List<GameCard> hand,
    required Suit? ledSuit,
    required bool isLeadPlay,
    Suit? trumpSuit,
    bool isKout = false,
    bool isFirstTrick = false,
  }) {
    if (!hand.contains(card)) return const PlayValidationResult.invalid('card-not-in-hand');
    // Kout rule: first trick leader must play trump if they have it.
    if (isKout && isLeadPlay && isFirstTrick && trumpSuit != null) {
      final hasTrump = hand.any((c) => !c.isJoker && c.suit == trumpSuit);
      if (hasTrump && !card.isJoker && card.suit != trumpSuit) {
        return const PlayValidationResult.invalid('must-lead-trump');
      }
    }
    // Joker CAN be led — but triggers immediate round loss (handled by game controller).
    if (!isLeadPlay && ledSuit != null) {
      final hasLedSuit = hand.any((c) => !c.isJoker && c.suit == ledSuit);
      if (hasLedSuit && !card.isJoker && card.suit != ledSuit) {
        return const PlayValidationResult.invalid('must-follow-suit');
      }
    }
    return const PlayValidationResult.valid();
  }

  /// Returns the set of cards in [hand] that are legal to play given the
  /// current trick state. Single source of truth for playability — UI and bot
  /// should both call through here.
  static Set<GameCard> playableCards({
    required List<GameCard> hand,
    required Suit? ledSuit,
    required bool isLeadPlay,
    Suit? trumpSuit,
    bool isKout = false,
    bool isFirstTrick = false,
  }) {
    return hand
        .where((card) => validatePlay(
              card: card,
              hand: hand,
              ledSuit: ledSuit,
              isLeadPlay: isLeadPlay,
              trumpSuit: trumpSuit,
              isKout: isKout,
              isFirstTrick: isFirstTrick,
            ).isValid)
        .toSet();
  }

  /// Playable cards for the current trick using the same inputs UI and bots use.
  ///
  /// [trickHasNoPlaysYet] — true when this seat is leading (no cards on the trick yet).
  /// [ledSuit] — suit led; when following a joker lead this may be null even though
  /// [trickHasNoPlaysYet] is false, so do not infer lead vs follow from [ledSuit] alone.
  /// [noTricksCompletedYet] — true while the round has not finished any trick
  /// (`trickWinners.isEmpty`); drives the Kout “lead trump first trick” rule only when leading.
  static Set<GameCard> playableForCurrentTrick({
    required List<GameCard> hand,
    required bool trickHasNoPlaysYet,
    required Suit? ledSuit,
    Suit? trumpSuit,
    required bool bidIsKout,
    required bool noTricksCompletedYet,
  }) {
    return playableCards(
      hand: hand,
      ledSuit: trickHasNoPlaysYet ? null : ledSuit,
      isLeadPlay: trickHasNoPlaysYet,
      trumpSuit: trumpSuit,
      isKout: bidIsKout,
      isFirstTrick: noTricksCompletedYet,
    );
  }

  static bool detectPoisonJoker(List<GameCard> hand) {
    return hand.length == 1 && hand.first.isJoker;
  }

  /// Returns true when a Joker is played as the lead card of a trick.
  /// This is a legal play but triggers an immediate round loss for the
  /// leading player's team (+10 to opponent, same as poison joker).
  static bool detectJokerLead(GameCard card, bool isLeadPlay) {
    return isLeadPlay && card.isJoker;
  }
}
