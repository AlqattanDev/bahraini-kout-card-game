import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';

abstract class GameInputSink {
  void playCard(GameCard card);
  void placeBid(BidAmount amount);
  void pass();
  void selectTrump(Suit suit);
}
