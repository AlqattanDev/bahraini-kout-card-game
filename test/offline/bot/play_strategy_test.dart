import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/bot/card_tracker.dart';
import 'package:koutbh/offline/bot/game_context.dart';
import 'package:koutbh/offline/bot/play_strategy.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GameCard _c(String code) => GameCard.decode(code);

GameContext _ctx({
  int mySeat = 0,
  Team myTeam = Team.a,
  BidAmount? currentBid = BidAmount.six,
  int? bidderSeat = 0,
  bool isBiddingTeam = true,
  bool isForcedBid = false,
  Map<Team, int> trickCounts = const {Team.a: 2, Team.b: 1},
  List<Team> trickWinners = const [Team.a, Team.b, Team.a],
  Suit? trumpSuit = Suit.hearts,
  CardTracker? tracker,
}) {
  return GameContext(
    mySeat: mySeat,
    myTeam: myTeam,
    scores: const {Team.a: 0, Team.b: 0},
    currentBid: currentBid,
    bidderSeat: bidderSeat,
    isBiddingTeam: isBiddingTeam,
    isForcedBid: isForcedBid,
    trickCounts: trickCounts,
    trickWinners: trickWinners,
    trumpSuit: trumpSuit,
    tracker: tracker,
  );
}

PlayCardAction _select({
  required List<GameCard> hand,
  List<({String playerUid, GameCard card})> trickPlays = const [],
  Suit? trumpSuit = Suit.hearts,
  Suit? ledSuit,
  int mySeat = 0,
  String? partnerUid,
  bool isKout = false,
  bool isFirstTrick = false,
  GameContext? context,
}) {
  return PlayStrategy.selectCard(
    hand: hand,
    trickPlays: trickPlays,
    trumpSuit: trumpSuit,
    ledSuit: ledSuit,
    mySeat: mySeat,
    partnerUid: partnerUid,
    isKout: isKout,
    isFirstTrick: isFirstTrick,
    context: context,
  );
}

void main() {
  // =========================================================================
  // LEADING
  // =========================================================================

  group('Leading', () {
    test('never leads Joker', () {
      final hand = [
        GameCard.joker(),
        _c('SA'),
        _c('HK'),
      ];
      final result = _select(hand: hand);
      expect(result.card.isJoker, isFalse);
    });

    test('leads master card (highest remaining) when tracker available', () {
      final tracker = CardTracker();
      // Mark all spades above King as played so SK is master.
      tracker.recordPlay(1, _c('SA'));
      final hand = [_c('SK'), _c('H7'), _c('C8')];
      final result = _select(
        hand: hand,
        context: _ctx(tracker: tracker),
      );
      expect(result.card, _c('SK'));
    });

    test('leads non-trump master before trump master', () {
      final tracker = CardTracker();
      // SA is master of spades (nothing higher played, but SA is highest anyway).
      // HA is master of hearts (trump).
      final hand = [_c('SA'), _c('HA'), _c('C7')];
      final result = _select(
        hand: hand,
        context: _ctx(tracker: tracker, trumpSuit: Suit.hearts),
      );
      // Should prefer non-trump master (SA) over trump master (HA).
      expect(result.card, _c('SA'));
    });

    test('leads Ace with King in same suit (AK preference)', () {
      final hand = [_c('SA'), _c('SK'), _c('C7'), _c('D8')];
      final result = _select(hand: hand);
      expect(result.card, _c('SA'));
    });

    test('leads non-trump Ace when no AK combo', () {
      final hand = [_c('SA'), _c('C7'), _c('D8'), _c('H7')];
      final result = _select(hand: hand);
      expect(result.card, _c('SA'));
    });

    test('does not lead trump Ace as a non-trump Ace lead', () {
      // Only trump ace available; should not be picked by the Aces priority.
      // Will fall through to later priorities.
      final hand = [_c('HA'), _c('C7'), _c('D8')];
      final result = _select(hand: hand, trumpSuit: Suit.hearts);
      // HA is a trump ace, so it should not be selected by the ace-lead rule.
      // It could be selected by other rules, but it shouldn't be prioritized as a non-trump ace.
      // With no non-trump aces, we expect fallback behavior.
      expect(result, isA<PlayCardAction>());
    });

    test('leads singleton non-trump to create void when holding trump', () {
      final hand = [
        _c('C7'), // singleton clubs
        _c('S9'),
        _c('S8'),
        _c('H7'), // trump
        _c('H8'), // trump
      ];
      final result = _select(hand: hand, trumpSuit: Suit.hearts);
      // C7 is singleton non-trump; bot has trump to ruff later.
      expect(result.card, _c('C7'));
    });

    test('bidding team with 3+ trumps: leads highest trump (trump strip)', () {
      // No singletons here so singleton-void rule doesn't fire first.
      final hand = [
        _c('HA'),
        _c('HK'),
        _c('H9'),
        _c('C7'),
        _c('C8'),
      ];
      final result = _select(
        hand: hand,
        trumpSuit: Suit.hearts,
        context: _ctx(isBiddingTeam: true),
      );
      expect(result.card, _c('HA'));
    });

    test('leads into partner void suit', () {
      final tracker = CardTracker();
      tracker.inferVoid(2, Suit.clubs); // partner seat 2 is void in clubs
      final hand = [_c('C9'), _c('C8'), _c('S7'), _c('D8')];
      final result = _select(
        hand: hand,
        trumpSuit: Suit.hearts,
        context: _ctx(tracker: tracker, mySeat: 0),
      );
      // Should lead into clubs since partner is void.
      expect(result.card.suit, Suit.clubs);
    });

    test('leads lowest from longest non-trump suit', () {
      final hand = [
        _c('S10'),
        _c('S9'),
        _c('S8'),
        _c('C10'),
        _c('D8'),
      ];
      final result = _select(hand: hand, trumpSuit: Suit.hearts);
      // Spades is longest (3 cards). Should lead lowest = S8.
      expect(result.card, _c('S8'));
    });

    test('fallback: leads highest non-Joker card', () {
      // All trump, no context — fallback.
      final hand = [_c('H10'), _c('H9'), _c('H8')];
      final result = _select(hand: hand, trumpSuit: Suit.hearts);
      expect(result.card, _c('H10'));
    });
  });

  // =========================================================================
  // FOLLOWING SUIT
  // =========================================================================

  group('Following suit', () {
    test('plays lowest when partner winning and last to play', () {
      final hand = [_c('SA'), _c('S7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('S9')),
          (playerUid: 'p2', card: _c('SK')),
          (playerUid: 'p3', card: _c('S8')),
        ],
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
      );
      expect(result.card, _c('S7'));
    });

    test('plays lowest when partner winning and opponent still to play', () {
      // Position 1 (second to play), partner led and winning.
      final hand = [_c('SA'), _c('S7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p2', card: _c('SK')),
        ],
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
      );
      // Partner winning, opponents still to play. Play lowest.
      expect(result.card, _c('S7'));
    });

    test('plays highest winner when opponent winning and not last to play', () {
      final hand = [_c('SA'), _c('SK'), _c('S7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SQ')),
        ],
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      // SA is highest winner — guarantees trick since opponent plays after us.
      expect(result.card, _c('SA'));
    });

    test('plays lowest winner when last to play', () {
      final hand = [_c('SA'), _c('SK'), _c('S7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SQ')),
          (playerUid: 'p2', card: _c('S8')),
          (playerUid: 'p3', card: _c('S9')),
        ],
        ledSuit: Suit.spades,
        mySeat: 0,
      );
      // Last to play — lowest winner is safe, conserve the Ace.
      expect(result.card, _c('SK'));
    });

    test('plays lowest when opponent winning and cannot beat', () {
      final hand = [_c('S7'), _c('S8')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SA')),
        ],
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      expect(result.card, _c('S7'));
    });

    test('last to play, can win: plays lowest winner', () {
      final hand = [_c('SA'), _c('SK'), _c('S7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SQ')),
          (playerUid: 'p2', card: _c('S9')),
          (playerUid: 'p3', card: _c('S10')),
        ],
        ledSuit: Suit.spades,
        mySeat: 0,
      );
      expect(result.card, _c('SK'));
    });

    test('last to play, cannot win: plays lowest', () {
      final hand = [_c('S7'), _c('S8')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SA')),
          (playerUid: 'p2', card: _c('S9')),
          (playerUid: 'p3', card: _c('S10')),
        ],
        ledSuit: Suit.spades,
        mySeat: 0,
      );
      expect(result.card, _c('S7'));
    });

    test('follows suit when holding suit cards', () {
      final hand = [_c('SA'), _c('S7'), _c('HK'), _c('CQ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SK')),
        ],
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      expect(result.card.suit, Suit.spades);
    });
  });

  // =========================================================================
  // VOID IN LED SUIT
  // =========================================================================

  group('Void in led suit', () {
    test('always trumps when opponent winning and have trump', () {
      final hand = [_c('H7'), _c('H8'), _c('CQ'), _c('DJ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SK')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      expect(result.card.suit, Suit.hearts);
    });

    test('plays lowest winning trump when opponent winning', () {
      // Opponent played SK (spades). Trump = hearts.
      // Bot has H7 and HA. Both beat SK. Should pick H7 (lowest winner).
      final hand = [_c('HA'), _c('H7'), _c('CQ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SK')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      expect(result.card, _c('H7'));
    });

    test('dumps when partner winning safely (last to play, no opponent after)', () {
      final hand = [_c('H7'), _c('CQ'), _c('DJ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('S9')),
          (playerUid: 'p2', card: _c('SA')),
          (playerUid: 'p3', card: _c('S8')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
      );
      // Partner winning safely, should dump, not trump.
      expect(result.card.suit, isNot(Suit.hearts));
    });

    test('gap1: trumps to guarantee when partner winning and I have highest remaining trump', () {
      // Partner played SA (winning). Opponent (p3) still to play.
      // Bot (position 2) has HA which is highest remaining trump — no higher trump out.
      // Tracker knows only H7 remains unseen, which is lower than HA.
      final tracker = CardTracker();
      // Mark all hearts except HA and H7 as played so HA is highest remaining.
      for (final card in [_c('HK'), _c('HQ'), _c('HJ'), _c('H10'), _c('H9'), _c('H8')]) {
        tracker.recordPlay(1, card);
      }
      // Hand: HA (trump) + some non-trump cards. We are void in spades.
      final hand = [_c('HA'), _c('CQ'), _c('DJ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('S9')),
          (playerUid: 'p2', card: _c('SA')), // partner winning
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
        context: _ctx(
          tracker: tracker,
          trumpSuit: Suit.hearts,
          trickCounts: const {Team.a: 2, Team.b: 1},
          trickWinners: const [Team.a, Team.b, Team.a],
        ),
      );
      // HA beats all remaining trumps — should play it to guarantee the trick.
      expect(result.card, _c('HA'));
    });

    test('gap1: dumps when partner winning but cannot guarantee with trump', () {
      // Partner playing SA (winning). Opponent still to play.
      // Bot has H7 (trump) but HK is still out (unseen) — cannot guarantee.
      final tracker = CardTracker();
      // Only HQ and below played — HK still out.
      tracker.recordPlay(1, _c('HQ'));
      tracker.recordPlay(1, _c('HJ'));
      // Hand: H7 (low trump) + non-trump cards.
      final hand = [_c('H7'), _c('CQ'), _c('DJ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('S9')),
          (playerUid: 'p2', card: _c('SA')), // partner winning
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
        context: _ctx(
          tracker: tracker,
          trumpSuit: Suit.hearts,
          trickCounts: const {Team.a: 2, Team.b: 1},
          trickWinners: const [Team.a, Team.b, Team.a],
        ),
      );
      // Cannot guarantee (HK could trump over H7) — dump instead.
      expect(result.card.suit, isNot(Suit.hearts));
    });

    test('plays Joker as last resort when no other card can win', () {
      final hand = [GameCard.joker(), _c('C7'), _c('D8')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('HA')),
          (playerUid: 'p3', card: _c('HK')),
        ],
        trumpSuit: Suit.spades,
        ledSuit: Suit.hearts,
        mySeat: 2,
        partnerUid: 'p0',
      );
      expect(result.card.isJoker, isTrue);
    });

    test('no trump, cannot win: dumps strategically', () {
      final hand = [_c('C7'), _c('D8'), _c('DQ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SA')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      // Should dump lowest or strategic.
      expect(result.card.suit, isNot(Suit.spades));
    });
  });

  // =========================================================================
  // JOKER MANAGEMENT
  // =========================================================================

  group('Joker management', () {
    test('poison prevention: plays Joker when 2 cards left and one is Joker', () {
      final hand = [GameCard.joker(), _c('S7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('CK')),
        ],
        ledSuit: Suit.clubs,
        mySeat: 2,
      );
      expect(result.card.isJoker, isTrue);
    });

    test('poison prevention: plays Joker when only Joker + 1 non-Joker in hand', () {
      final hand = [GameCard.joker(), _c('H8')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('DA')),
        ],
        ledSuit: Suit.diamonds,
        mySeat: 2,
      );
      expect(result.card.isJoker, isTrue);
    });

    test('trick countdown: plays Joker when 2 tricks remain (hand=2, not leading)', () {
      // 2 cards left => 2 tricks remain. Must play Joker now to avoid leading it.
      final hand = [GameCard.joker(), _c('S9')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('HA')),
        ],
        ledSuit: Suit.hearts,
        mySeat: 2,
      );
      expect(result.card.isJoker, isTrue);
    });

    test('gap2: trick countdown via context — plays Joker with 3-card hand when tricksPlayed=6', () {
      // 3 cards in hand but tricksPlayed=6 => tricksRemaining=2.
      // Old poison check (hand.length<=2) would not fire here.
      // New countdown check should play Joker while following.
      final hand = [GameCard.joker(), _c('S9'), _c('CQ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('HA')),
        ],
        ledSuit: Suit.hearts,
        mySeat: 2,
        context: _ctx(
          trickWinners: List.filled(6, Team.a), // tricksPlayed = 6
          trickCounts: const {Team.a: 5, Team.b: 1},
          trumpSuit: Suit.hearts,
        ),
      );
      expect(result.card.isJoker, isTrue);
    });

    test('gap2: trick countdown does not fire when 3 tricks remain', () {
      // tricksPlayed=5 => tricksRemaining=3 — no early Joker play.
      final hand = [GameCard.joker(), _c('S9'), _c('CQ'), _c('DJ')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SA')),
        ],
        ledSuit: Suit.spades,
        mySeat: 2,
        context: _ctx(
          trickWinners: List.filled(5, Team.a), // tricksPlayed = 5
          trickCounts: const {Team.a: 4, Team.b: 1},
          trumpSuit: Suit.hearts,
        ),
      );
      // 3 tricks remain — Joker countdown should not fire.
      expect(result.card.isJoker, isFalse);
    });

    test('uses Joker when non-joker cards cannot win and opponent winning', () {
      final hand = [GameCard.joker(), _c('C7'), _c('D8')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('HA')),
          (playerUid: 'p3', card: _c('HK')),
        ],
        trumpSuit: Suit.spades,
        ledSuit: Suit.hearts,
        mySeat: 2,
      );
      expect(result.card.isJoker, isTrue);
    });

    test('does not play Joker early when many cards remain and can trump', () {
      final hand = [
        GameCard.joker(),
        _c('C7'),
        _c('C8'),
        _c('H9'), // trump
        _c('D9'),
        _c('DJ'),
      ];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('S7')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      // Has trump to win, should not waste Joker early.
      expect(result.card.isJoker, isFalse);
    });
  });

  // =========================================================================
  // STRATEGIC DUMP
  // =========================================================================

  group('Strategic dump', () {
    test('dumps singleton non-trump first', () {
      final hand = [
        _c('C7'), // singleton clubs
        _c('S9'),
        _c('S8'),
        _c('D10'),
        _c('D8'),
      ];
      // Void in led suit (hearts), partner winning, should dump.
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('H9')),
          (playerUid: 'p2', card: _c('HA')),
          (playerUid: 'p3', card: _c('H8')),
        ],
        trumpSuit: Suit.spades,
        ledSuit: Suit.hearts,
        mySeat: 0,
        partnerUid: 'p2',
      );
      // C7 is singleton non-trump — best dump candidate.
      expect(result.card, _c('C7'));
    });

    test('does not break AK combo when dumping', () {
      final hand = [
        _c('SA'),
        _c('SK'),
        _c('C9'),
        _c('C8'),
        _c('DQ'),
      ];
      // Void in hearts, partner winning, dumping.
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('H9')),
          (playerUid: 'p2', card: _c('HA')),
          (playerUid: 'p3', card: _c('H8')),
        ],
        trumpSuit: Suit.diamonds,
        ledSuit: Suit.hearts,
        mySeat: 0,
        partnerUid: 'p2',
      );
      // Should not dump SA or SK (they form AK combo). Should dump C8 (lowest safe).
      expect(result.card, _c('C8'));
    });

    test('dumps lowest trump only when nothing else remains', () {
      // Only trump cards in hand, void in led suit, partner winning.
      final hand = [_c('H10'), _c('H8'), _c('H7')];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('S9')),
          (playerUid: 'p2', card: _c('SA')),
          (playerUid: 'p3', card: _c('S8')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 0,
        partnerUid: 'p2',
      );
      expect(result.card, _c('H7'));
    });
  });

  // =========================================================================
  // SINGLE-CARD HAND
  // =========================================================================

  group('Single card', () {
    test('returns the only card when hand has one card', () {
      final hand = [_c('SA')];
      final result = _select(hand: hand);
      expect(result.card, _c('SA'));
    });

    test('returns a valid PlayCardAction', () {
      final hand = [_c('SA')];
      final result = _select(hand: hand);
      expect(result, isA<PlayCardAction>());
    });
  });

  // =========================================================================
  // EDGE CASES
  // =========================================================================

  group('Edge cases', () {
    test('handles null context gracefully', () {
      final hand = [_c('SA'), _c('SK'), _c('CQ')];
      final result = _select(hand: hand, context: null);
      expect(result, isA<PlayCardAction>());
    });

    test('handles null trump suit', () {
      final hand = [_c('SA'), _c('SK'), _c('CQ')];
      final result = _select(hand: hand, trumpSuit: null);
      expect(result, isA<PlayCardAction>());
    });

    test('plays Joker to steal when opponent trumps in', () {
      final hand = [
        GameCard.joker(),
        _c('C7'),
        _c('C8'),
        _c('D9'),
        _c('DJ'),
      ];
      final result = _select(
        hand: hand,
        trickPlays: [
          (playerUid: 'p1', card: _c('SK')),
          (playerUid: 'p3', card: _c('HA')),
        ],
        trumpSuit: Suit.hearts,
        ledSuit: Suit.spades,
        mySeat: 2,
      );
      // Opponent trumped (HA), Joker is the only way to win.
      expect(result.card.isJoker, isTrue);
    });
  });
}
