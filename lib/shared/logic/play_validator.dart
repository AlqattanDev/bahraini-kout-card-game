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
  }) {
    if (!hand.contains(card)) return const PlayValidationResult.invalid('card-not-in-hand');
    if (isLeadPlay && card.isJoker) return const PlayValidationResult.invalid('cannot-lead-joker');
    if (!isLeadPlay && ledSuit != null) {
      final hasLedSuit = hand.any((c) => !c.isJoker && c.suit == ledSuit);
      if (hasLedSuit && (card.isJoker || card.suit != ledSuit)) {
        return const PlayValidationResult.invalid('must-follow-suit');
      }
    }
    return const PlayValidationResult.valid();
  }

  static bool detectPoisonJoker(List<GameCard> hand) {
    return hand.length == 1 && hand.first.isJoker;
  }
}
