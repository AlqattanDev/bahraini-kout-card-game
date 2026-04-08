import '../models/bid.dart';

enum BidValidationError {
  alreadyPassed,
  bidNotHigher,
  mustBid;

  @override
  String toString() => switch (this) {
        BidValidationError.alreadyPassed => 'already-passed',
        BidValidationError.bidNotHigher => 'bid-not-higher',
        BidValidationError.mustBid => 'must-bid',
      };
}

class BidValidationResult {
  final bool isValid;
  final BidValidationError? error;
  const BidValidationResult.valid() : isValid = true, error = null;
  const BidValidationResult.invalid(this.error) : isValid = false;
}

class BiddingOutcome {
  final bool isComplete;
  final int? winnerIndex;
  final BidAmount? winningBid;

  const BiddingOutcome._({required this.isComplete, this.winnerIndex, this.winningBid});

  factory BiddingOutcome.won({required int winnerIndex, required BidAmount bid}) =>
      BiddingOutcome._(isComplete: true, winnerIndex: winnerIndex, winningBid: bid);

  factory BiddingOutcome.ongoing() => const BiddingOutcome._(isComplete: false);

  @override
  bool operator ==(Object other) {
    if (other is! BiddingOutcome) return false;
    return isComplete == other.isComplete && winnerIndex == other.winnerIndex && winningBid == other.winningBid;
  }

  @override
  int get hashCode => Object.hash(isComplete, winnerIndex, winningBid);
}

class BidValidator {
  static bool _alreadyPassed(List<int> passedPlayers, int playerIndex) =>
      passedPlayers.contains(playerIndex);

  static BidValidationResult validateBid({
    required BidAmount bidAmount,
    required BidAmount? currentHighest,
    required List<int> passedPlayers,
    required int playerIndex,
  }) {
    if (_alreadyPassed(passedPlayers, playerIndex)) {
      return const BidValidationResult.invalid(BidValidationError.alreadyPassed);
    }
    if (currentHighest != null && bidAmount.value <= currentHighest.value) {
      return const BidValidationResult.invalid(BidValidationError.bidNotHigher);
    }
    return const BidValidationResult.valid();
  }

  static BidValidationResult validatePass({
    required List<int> passedPlayers,
    required int playerIndex,
    int playerCount = 4,
    BidAmount? currentHighest,
  }) {
    if (_alreadyPassed(passedPlayers, playerIndex)) {
      return const BidValidationResult.invalid(BidValidationError.alreadyPassed);
    }
    if (isLastBidder(passedPlayers: passedPlayers, playerIndex: playerIndex, playerCount: playerCount) && currentHighest == null) {
      return const BidValidationResult.invalid(BidValidationError.mustBid);
    }
    return const BidValidationResult.valid();
  }

  static bool isLastBidder({
    required List<int> passedPlayers,
    required int playerIndex,
    int playerCount = 4,
  }) {
    if (_alreadyPassed(passedPlayers, playerIndex)) return false;
    final activePlayers = playerCount - passedPlayers.length;
    return activePlayers == 1;
  }

  static BiddingOutcome checkBiddingComplete({
    required List<int> passedPlayers,
    required BidAmount? currentHighest,
    required int? highestBidderIndex,
  }) {
    if (passedPlayers.length >= 3 && currentHighest != null && highestBidderIndex != null) {
      return BiddingOutcome.won(winnerIndex: highestBidderIndex, bid: currentHighest);
    }
    return BiddingOutcome.ongoing();
  }
}
