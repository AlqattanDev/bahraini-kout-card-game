import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/logic/bid_validator.dart';

void main() {
  group('BidValidator', () {
    group('validateBid', () {
      test('accepts first bid of 5', () {
        final result = BidValidator.validateBid(bidAmount: BidAmount.bab, currentHighest: null, passedPlayers: [], playerIndex: 1);
        expect(result.isValid, true);
      });
      test('accepts bid higher than current', () {
        final result = BidValidator.validateBid(bidAmount: BidAmount.seven, currentHighest: BidAmount.six, passedPlayers: [], playerIndex: 1);
        expect(result.isValid, true);
      });
      test('rejects bid equal to current', () {
        final result = BidValidator.validateBid(bidAmount: BidAmount.six, currentHighest: BidAmount.six, passedPlayers: [], playerIndex: 1);
        expect(result.isValid, false);
        expect(result.error, 'bid-not-higher');
      });
      test('rejects bid lower than current', () {
        final result = BidValidator.validateBid(bidAmount: BidAmount.bab, currentHighest: BidAmount.six, passedPlayers: [], playerIndex: 1);
        expect(result.isValid, false);
        expect(result.error, 'bid-not-higher');
      });
      test('rejects bid from player who already passed', () {
        final result = BidValidator.validateBid(bidAmount: BidAmount.seven, currentHighest: BidAmount.six, passedPlayers: [1], playerIndex: 1);
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });
    });

    group('validatePass', () {
      test('allows pass for non-passed player when not last', () {
        final result = BidValidator.validatePass(passedPlayers: [0], playerIndex: 1, playerCount: 4);
        expect(result.isValid, true);
      });
      test('rejects pass from player who already passed', () {
        final result = BidValidator.validatePass(passedPlayers: [1], playerIndex: 1, playerCount: 4);
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });
      test('rejects pass when player is last remaining and no bid exists', () {
        final result = BidValidator.validatePass(passedPlayers: [0, 2, 3], playerIndex: 1, playerCount: 4, currentHighest: null);
        expect(result.isValid, false);
        expect(result.error, 'must-bid');
      });
      test('allows pass when player is last remaining but a bid exists', () {
        final result = BidValidator.validatePass(passedPlayers: [0, 2, 3], playerIndex: 1, playerCount: 4, currentHighest: BidAmount.six);
        expect(result.isValid, true);
      });
    });

    group('isLastBidder', () {
      test('returns true when 3 others have passed', () {
        expect(BidValidator.isLastBidder(passedPlayers: [0, 2, 3], playerIndex: 1, playerCount: 4), true);
      });
      test('returns false when fewer than 3 have passed', () {
        expect(BidValidator.isLastBidder(passedPlayers: [0, 2], playerIndex: 1, playerCount: 4), false);
      });
      test('returns false when player is in passedPlayers', () {
        expect(BidValidator.isLastBidder(passedPlayers: [0, 1, 2], playerIndex: 1, playerCount: 4), false);
      });
    });

    group('checkBiddingComplete', () {
      test('complete when 3 players passed and a bid exists', () {
        final result = BidValidator.checkBiddingComplete(passedPlayers: [0, 2, 3], currentHighest: BidAmount.six, highestBidderIndex: 1);
        expect(result, BiddingOutcome.won(winnerIndex: 1, bid: BidAmount.six));
      });
      test('not complete with fewer than 3 passes', () {
        final result = BidValidator.checkBiddingComplete(passedPlayers: [0, 2], currentHighest: BidAmount.six, highestBidderIndex: 1);
        expect(result, BiddingOutcome.ongoing());
      });
      test('not complete when all 4 passed but no bid', () {
        final result = BidValidator.checkBiddingComplete(passedPlayers: [0, 1, 2, 3], currentHighest: null, highestBidderIndex: null);
        expect(result, BiddingOutcome.ongoing());
      });
    });
  });
}
