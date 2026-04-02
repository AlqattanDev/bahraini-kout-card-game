enum BotDifficulty {
  conservative,
  balanced,
  aggressive;

  /// Bid threshold adjustment. Positive = bids more aggressively.
  double get bidAdjust => switch (this) {
        conservative => -0.3,
        balanced => 0.0,
        aggressive => 0.3,
      };

  /// Trump selection weights.
  double get trumpLengthWeight => switch (this) {
        conservative => 1.5,
        balanced => 2.0,
        aggressive => 2.5,
      };

  double get trumpStrengthWeight => switch (this) {
        conservative => 2.0,
        balanced => 1.0,
        aggressive => 0.5,
      };

  /// Joker urgency threshold. Lower = plays Joker more aggressively.
  double get jokerUrgencyThreshold => switch (this) {
        conservative => 0.6,
        balanced => 0.3,
        aggressive => 0.1,
      };
}
