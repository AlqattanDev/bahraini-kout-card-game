import '../models/bid.dart';

class BidValidationResult {
  final bool isValid;
  final String? error;
  const BidValidationResult.valid() : isValid = true, error = null;
  const BidValidationResult.invalid(this.error) : isValid = false;
}

enum MalzoomOutcome { none, reshuffle, forcedBid }

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
  static BidValidationResult validateBid({
    required BidAmount bidAmount,
    required BidAmount? currentHighest,
    required List<int> passedPlayers,
    required int playerIndex,
  }) {
    if (passedPlayers.contains(playerIndex)) return const BidValidationResult.invalid('already-passed');
    if (currentHighest != null && bidAmount.value <= currentHighest.value) return const BidValidationResult.invalid('bid-not-higher');
    return const BidValidationResult.valid();
  }

  static BidValidationResult validatePass({required List<int> passedPlayers, required int playerIndex}) {
    if (passedPlayers.contains(playerIndex)) return const BidValidationResult.invalid('already-passed');
    return const BidValidationResult.valid();
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

  static MalzoomOutcome checkMalzoom({required List<int> passedPlayers, required int reshuffleCount}) {
    if (passedPlayers.length < 4) return MalzoomOutcome.none;
    if (reshuffleCount < 1) return MalzoomOutcome.reshuffle;
    return MalzoomOutcome.forcedBid;
  }
}
