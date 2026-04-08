import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/offline/bot/bid_strategy.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/deck.dart';

void main() {
  group('Bid telemetry', () {
    test('prints bid distribution over random hands', () {
      const sampleSize = 2000;
      var passCount = 0;
      final bidCounts = <BidAmount, int>{
        BidAmount.bab: 0,
        BidAmount.six: 0,
        BidAmount.seven: 0,
        BidAmount.kout: 0,
      };

      for (int i = 0; i < sampleSize; i++) {
        final hand = Deck.fourPlayer().deal(4).first;
        final action = BidStrategy.decideBid(hand, null);
        if (action is PassAction) {
          passCount++;
        } else if (action is BidAction) {
          bidCounts[action.amount] = (bidCounts[action.amount] ?? 0) + 1;
        }
      }

      final totalBids = sampleSize - passCount;
      final bidRate = totalBids / sampleSize;
      final highBidRate =
          ((bidCounts[BidAmount.seven] ?? 0) + (bidCounts[BidAmount.kout] ?? 0)) /
          sampleSize;

      // Telemetry output for tuning.
      print('--- Bid telemetry ($sampleSize random hands) ---');
      print('pass: $passCount (${(passCount * 100 / sampleSize).toStringAsFixed(1)}%)');
      for (final bid in BidAmount.values) {
        final count = bidCounts[bid] ?? 0;
        print(
          '${bid.value}: $count (${(count * 100 / sampleSize).toStringAsFixed(1)}%)',
        );
      }
      print('total bids: $totalBids (${(bidRate * 100).toStringAsFixed(1)}%)');
      print(
        '7+8 rate: ${((highBidRate * 100)).toStringAsFixed(1)}%',
      );

      // Sanity checks to prevent regressions toward ultra-safe bots.
      expect(bidRate, greaterThan(0.45));
      expect(highBidRate, greaterThan(0.12));

      // Human-like aggression band: enough 7s, rare reckless Kout in neutral samples.
      expect(
        (bidCounts[BidAmount.seven] ?? 0) / sampleSize,
        greaterThan(0.08),
      );
      expect(
        (bidCounts[BidAmount.kout] ?? 0) / sampleSize,
        lessThan(0.03),
      );
    });
  });
}
