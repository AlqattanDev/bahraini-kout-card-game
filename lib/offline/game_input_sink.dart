import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/bid.dart';

abstract class GameInputSink {
  void playCard(GameCard card);
  void placeBid(BidAmount amount);
  void pass();
  void selectTrump(Suit suit);
}
