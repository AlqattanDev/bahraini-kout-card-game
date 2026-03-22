import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/logic/bid_validator.dart';

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
      test('allows pass for non-passed player', () {
        final result = BidValidator.validatePass(passedPlayers: [0, 2], playerIndex: 1);
        expect(result.isValid, true);
      });
      test('rejects pass from player who already passed', () {
        final result = BidValidator.validatePass(passedPlayers: [1], playerIndex: 1);
        expect(result.isValid, false);
        expect(result.error, 'already-passed');
      });
    });

    group('checkBiddingComplete', () {
      test('bidding complete when 3 players passed', () {
        final result = BidValidator.checkBiddingComplete(passedPlayers: [0, 2, 3], currentHighest: BidAmount.six, highestBidderIndex: 1);
        expect(result, BiddingOutcome.won(winnerIndex: 1, bid: BidAmount.six));
      });
      test('bidding not complete with fewer than 3 passes', () {
        final result = BidValidator.checkBiddingComplete(passedPlayers: [0, 2], currentHighest: BidAmount.six, highestBidderIndex: 1);
        expect(result, BiddingOutcome.ongoing());
      });
    });

    group('checkMalzoom', () {
      test('first all-pass triggers reshuffle', () {
        expect(BidValidator.checkMalzoom(passedPlayers: [0, 1, 2, 3], reshuffleCount: 0), MalzoomOutcome.reshuffle);
      });
      test('second all-pass triggers forced bid', () {
        expect(BidValidator.checkMalzoom(passedPlayers: [0, 1, 2, 3], reshuffleCount: 1), MalzoomOutcome.forcedBid);
      });
      test('not all passed returns none', () {
        expect(BidValidator.checkMalzoom(passedPlayers: [0, 1, 2], reshuffleCount: 0), MalzoomOutcome.none);
      });
    });
  });
}
