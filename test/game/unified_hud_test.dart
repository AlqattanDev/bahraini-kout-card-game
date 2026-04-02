import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/game/components/unified_hud.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';

void main() {
  group('UnifiedHudComponent', () {
    test('positions at top-right with 12px margin', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      expect(hud.position.x, closeTo(800 - 160 - 12, 1));
      expect(hud.position.y, 10);
    });

    test('updateWidth repositions for new screen width', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateWidth(1024);
      expect(hud.position.x, closeTo(1024 - 160 - 12, 1));
    });

    test('default state has score 0, round 1, no bid', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      expect(hud.score, 0);
      expect(hud.roundNumber, 1);
      expect(hud.bidValue, isNull);
      expect(hud.trumpSuit, isNull);
    });

    test('updateState sets score and round from state', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateState(
        phase: GamePhase.playing,
        teamAScore: 10,
        teamBScore: 0,
        roundNumber: 3,
        bidValue: 6,
        bidderTeam: Team.a,
        trumpSuit: Suit.hearts,
        bidderTricks: 2,
        opponentTricks: 1,
        opponentTarget: 3,
      );
      expect(hud.score, 10);
      expect(hud.roundNumber, 3);
      expect(hud.bidValue, 6);
      expect(hud.trumpSuit, Suit.hearts);
    });

    test('updateTimer sets elapsed duration', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateTimer(const Duration(minutes: 5, seconds: 30));
      expect(hud.timerText, '05:30');
    });

    test('timer clamps at 59:59', () {
      final hud = UnifiedHudComponent(screenWidth: 800);
      hud.updateTimer(const Duration(hours: 2));
      expect(hud.timerText, '59:59');
    });

    test('computePips clamps to target', () {
      expect(UnifiedHudComponent.computePips(target: 5, tricksTaken: 8), 5);
    });

    test('computePips returns actual tricks when under target', () {
      expect(UnifiedHudComponent.computePips(target: 6, tricksTaken: 3), 3);
    });

    test('computePips clamps negative to 0', () {
      expect(UnifiedHudComponent.computePips(target: 5, tricksTaken: -1), 0);
    });
  });
}
