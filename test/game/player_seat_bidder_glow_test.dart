import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/player_seat.dart';
import 'package:koutbh/game/theme/kout_theme.dart';

void main() {
  group('PlayerSeatComponent bidder glow', () {
    test('isBidder defaults to false', () {
      final seat = PlayerSeatComponent(
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
      );
      expect(seat.isBidder, isFalse);
      expect(seat.bidderGlowColor, isNull);
    });

    test('setBidderGlow sets fields correctly', () {
      final seat = PlayerSeatComponent(
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
      );
      seat.setBidderGlow(true, KoutTheme.teamAColor);
      expect(seat.isBidder, isTrue);
      expect(seat.bidderGlowColor, KoutTheme.teamAColor);
    });

    test('clearBidderGlow resets fields', () {
      final seat = PlayerSeatComponent(
        playerName: 'test',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
      );
      seat.setBidderGlow(true, KoutTheme.teamAColor);
      seat.setBidderGlow(false, null);
      expect(seat.isBidder, isFalse);
      expect(seat.bidderGlowColor, isNull);
    });
  });
}
