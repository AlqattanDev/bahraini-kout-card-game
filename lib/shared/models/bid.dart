import '../constants.dart';

enum BidAmount {
  bab(value: 5, successPoints: 5, failurePoints: 10),
  six(value: 6, successPoints: 6, failurePoints: 12),
  seven(value: 7, successPoints: 7, failurePoints: 14),
  kout(value: 8, successPoints: targetScore, failurePoints: 16);

  const BidAmount({required this.value, required this.successPoints, required this.failurePoints});
  final int value;
  final int successPoints;
  final int failurePoints;
  bool get isKout => this == BidAmount.kout;

  static BidAmount? fromValue(int value) {
    for (final bid in values) { if (bid.value == value) return bid; }
    return null;
  }

  /// Returns the smallest [BidAmount] strictly above [current], or null if
  /// [current] is already kout (the maximum). If [current] is null, returns
  /// [bab] (the minimum bid).
  static BidAmount? nextAbove(BidAmount? current) {
    if (current == null) return BidAmount.bab;
    for (final bid in values) {
      if (bid.value > current.value) return bid;
    }
    return null;
  }
}
