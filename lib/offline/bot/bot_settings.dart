/// Bot tuning constants — single difficulty level (hardest).
class BotSettings {
  BotSettings._();

  // Trump selection weights
  static const double trumpLengthWeight = 2.5;
  static const double trumpStrengthWeight = 0.45;

  // Partner contribution estimates (tricks)
  static const double partnerEstimateDefault = 1.0;
  static const double partnerEstimateBid = 1.5;
  static const double partnerEstimatePass = 0.5;

  // Desperation: threshold reduction when losing means opponent wins
  static const double desperationThreshold = 1.0;
}
