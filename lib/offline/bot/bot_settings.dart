/// Fixed tuning for offline AI opponents — one strong profile only (no tiers).
class BotSettings {
  BotSettings._();

  /// Positive = bids more readily (sharp, contesting auctions).
  static const double bidAdjust = 1.1;

  static const double trumpLengthWeight = 2.5;
  static const double trumpStrengthWeight = 0.45;

  /// Lower = play Joker sooner when the trick is contested.
  static const double jokerUrgencyThreshold = 0.08;
}
