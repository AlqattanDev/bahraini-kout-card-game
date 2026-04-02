import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/player_seat.dart';

void main() {
  group('PlayerSeatComponent', () {
    test('creates with required parameters', () {
      final seat = PlayerSeatComponent(
        playerName: 'TestUser',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
        avatarSeed: 0,
      );
      expect(seat.playerName, 'TestUser');
      expect(seat.cardCount, 8);
      expect(seat.isActive, false);
      expect(seat.isTeamA, true);
    });

    test('updateState changes properties', () {
      final seat = PlayerSeatComponent(
        playerName: 'OldName',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
        avatarSeed: 0,
      );
      seat.updateState(
        name: 'NewName',
        cards: 5,
        active: true,
        teamA: false,
      );
      expect(seat.playerName, 'NewName');
      expect(seat.cardCount, 5);
      expect(seat.isActive, true);
      expect(seat.isTeamA, false);
    });

    test('name truncation works for long names', () {
      final seat = PlayerSeatComponent(
        playerName: 'VeryLongPlayerName',
        cardCount: 8,
        isActive: false,
        isTeamA: true,
        avatarSeed: 0,
      );
      expect(seat.playerName, 'VeryLongPlayerName');
    });
  });
}
