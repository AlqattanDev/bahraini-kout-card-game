import 'package:flutter_test/flutter_test.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';

void main() {
  group('nextDealerSeat', () {
    test('dealer stays when scores are tied', () {
      expect(nextDealerSeat(0, {Team.a: 0, Team.b: 0}), equals(0));
      expect(nextDealerSeat(1, {Team.a: 10, Team.b: 10}), equals(1));
      expect(nextDealerSeat(3, {Team.a: 5, Team.b: 5}), equals(3));
    });

    test('dealer stays when already on losing team', () {
      // Seat 0 (Team A), Team A losing (5 < 10)
      expect(nextDealerSeat(0, {Team.a: 5, Team.b: 10}), equals(0));
      // Seat 2 (Team A), Team A losing
      expect(nextDealerSeat(2, {Team.a: 5, Team.b: 10}), equals(2));
      // Seat 1 (Team B), Team B losing (3 < 7)
      expect(nextDealerSeat(1, {Team.a: 7, Team.b: 3}), equals(1));
      // Seat 3 (Team B), Team B losing
      expect(nextDealerSeat(3, {Team.a: 7, Team.b: 3}), equals(3));
    });

    test('dealer rotates when on winning team', () {
      // Seat 0 (Team A winning) → seat 3 (Team B)
      expect(nextDealerSeat(0, {Team.a: 10, Team.b: 5}), equals(3));
      // Seat 2 (Team A winning) → seat 1 (Team B)
      expect(nextDealerSeat(2, {Team.a: 10, Team.b: 5}), equals(1));
      // Seat 1 (Team B winning) → seat 0 (Team A)
      expect(nextDealerSeat(1, {Team.a: 5, Team.b: 15}), equals(0));
      // Seat 3 (Team B winning) → seat 2 (Team A)
      expect(nextDealerSeat(3, {Team.a: 5, Team.b: 15}), equals(2));
    });

    test('rotated seat is always on the losing team', () {
      for (int seat = 0; seat < 4; seat++) {
        final seatTeam = teamForSeat(seat);
        final scores = seatTeam == Team.a
            ? {Team.a: 20, Team.b: 5}
            : {Team.a: 5, Team.b: 20};
        final newSeat = nextDealerSeat(seat, scores);
        final losingTeam = seatTeam.opponent;
        expect(teamForSeat(newSeat), equals(losingTeam),
            reason: 'From seat $seat ($seatTeam), new dealer should be on $losingTeam');
      }
    });
  });
}
