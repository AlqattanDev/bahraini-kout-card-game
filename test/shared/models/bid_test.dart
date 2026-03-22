import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/bid.dart';

void main() {
  group('BidAmount', () {
    test('valid bids are 5, 6, 7, 8', () {
      expect(BidAmount.values.map((b) => b.value), [5, 6, 7, 8]);
    });
    test('bid 5 is named Bab', () { expect(BidAmount.bab.value, 5); });
    test('bid 8 is named Kout', () { expect(BidAmount.kout.value, 8); });
    test('success points match spec', () {
      expect(BidAmount.bab.successPoints, 5);
      expect(BidAmount.six.successPoints, 6);
      expect(BidAmount.seven.successPoints, 7);
      expect(BidAmount.kout.successPoints, 31);
    });
    test('failure points (opponent gets) match spec', () {
      expect(BidAmount.bab.failurePoints, 10);
      expect(BidAmount.six.failurePoints, 12);
      expect(BidAmount.seven.failurePoints, 14);
      expect(BidAmount.kout.failurePoints, 31);
    });
  });
}
