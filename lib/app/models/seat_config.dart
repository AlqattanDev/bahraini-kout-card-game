import 'package:koutbh/offline/bot/bot_difficulty.dart';

class SeatConfig {
  final int seatIndex;
  final String uid;
  final String displayName;
  final bool isBot;
  final BotDifficulty difficulty;

  const SeatConfig({
    required this.seatIndex,
    required this.uid,
    required this.displayName,
    required this.isBot,
    this.difficulty = BotDifficulty.balanced,
  });
}
