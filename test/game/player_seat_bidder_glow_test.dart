import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/player_seat.dart';
import 'package:koutbh/game/theme/kout_theme.dart';
import 'package:koutbh/shared/models/game_state.dart';

void main() {
  group('PlayerSeatComponent bidder glow', () {
    test('isBidder defaults to false', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        team: Team.a,
      );
      expect(seat.isBidder, isFalse);
      expect(seat.bidderGlowColor, isNull);
    });

    test('setBidderGlow sets fields correctly', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        team: Team.a,
      );
      seat.setBidderGlow(true, KoutTheme.teamAColor);
      expect(seat.isBidder, isTrue);
      expect(seat.bidderGlowColor, KoutTheme.teamAColor);
    });

    test('clearBidderGlow resets fields', () {
      final seat = PlayerSeatComponent(
        seatIndex: 0,
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        team: Team.a,
      );
      seat.setBidderGlow(true, KoutTheme.teamAColor);
      seat.setBidderGlow(false, null);
      expect(seat.isBidder, isFalse);
      expect(seat.bidderGlowColor, isNull);
    });
  });
}
