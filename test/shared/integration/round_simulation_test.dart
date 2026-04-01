import 'package:flutter_test/flutter_test.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/trick.dart';
import 'package:koutbh/shared/models/deck.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/logic/trick_resolver.dart';
import 'package:koutbh/shared/logic/play_validator.dart';
import 'package:koutbh/shared/logic/bid_validator.dart';
import 'package:koutbh/shared/logic/scorer.dart';

void main() {
  group('Full Round Integration', () {
    test('Full round simulation: deal → bid → play 8 tricks → score', () {
      // --- Deal ---
      final hands =
          Deck.fourPlayer().deal(4).map((h) => List<GameCard>.from(h)).toList();
      expect(hands.length, equals(4));
      expect(hands[0].length, equals(8));

      // --- Bid: Player 1 bids Bab (5), others pass ---
      const bidderIndex = 1;
      const bidAmount = BidAmount.bab;
      final passedPlayers = <int>[];

      // Player 0 passes
      var passResult = BidValidator.validatePass(
          passedPlayers: passedPlayers, playerIndex: 0);
      expect(passResult.isValid, isTrue);
      passedPlayers.add(0);

      // Player 1 bids bab
      var bidResult = BidValidator.validateBid(
        bidAmount: bidAmount,
        currentHighest: null,
        passedPlayers: passedPlayers,
        playerIndex: bidderIndex,
      );
      expect(bidResult.isValid, isTrue);
      BidAmount? currentHighest = bidAmount;
      int? highestBidderIndex = bidderIndex;

      // Player 2 passes
      passResult = BidValidator.validatePass(
          passedPlayers: passedPlayers, playerIndex: 2);
      expect(passResult.isValid, isTrue);
      passedPlayers.add(2);

      // Player 3 passes
      passResult = BidValidator.validatePass(
          passedPlayers: passedPlayers, playerIndex: 3);
      expect(passResult.isValid, isTrue);
      passedPlayers.add(3);

      // Check bidding complete: 3 players passed, bidder = 1 with bab
      final biddingOutcome = BidValidator.checkBiddingComplete(
        passedPlayers: passedPlayers,
        currentHighest: currentHighest,
        highestBidderIndex: highestBidderIndex,
      );
      expect(biddingOutcome.isComplete, isTrue);
      expect(biddingOutcome.winnerIndex, equals(bidderIndex));
      expect(biddingOutcome.winningBid, equals(bidAmount));

      // --- Trump selection ---
      const trumpSuit = Suit.spades;

      // --- Play 8 tricks ---
      // Bidder is seat 1 (Team.b), first leader is seat 2 (player after bidder)
      final tricksWon = {Team.a: 0, Team.b: 0};
      int leaderIndex = 2; // player after bid winner

      for (int trickNum = 0; trickNum < 8; trickNum++) {
        // Check for poison joker before each trick
        for (int p = 0; p < 4; p++) {
          if (PlayValidator.detectPoisonJoker(hands[p])) {
            // Poison joker detected — test just verifies detection, doesn't abort
            // In a real game this would end the round early
          }
        }

        final plays = <TrickPlay>[];
        Suit? ledSuit;

        // Four players play in clockwise order starting from leader
        for (int offset = 0; offset < 4; offset++) {
          final playerIndex = (leaderIndex + offset) % 4;
          final hand = hands[playerIndex];
          final isLeadPlay = offset == 0;

          // Find a valid card to play
          GameCard? chosenCard;
          for (final card in hand) {
            final result = PlayValidator.validatePlay(
              card: card,
              hand: hand,
              ledSuit: ledSuit,
              isLeadPlay: isLeadPlay,
            );
            if (result.isValid) {
              chosenCard = card;
              break;
            }
          }
          expect(chosenCard, isNotNull,
              reason:
                  'Player $playerIndex must have a valid card to play in trick $trickNum');

          plays.add(TrickPlay(playerIndex: playerIndex, card: chosenCard!));
          hand.remove(chosenCard);

          // Set led suit from lead play
          if (isLeadPlay && !chosenCard.isJoker) {
            ledSuit = chosenCard.suit;
          }
        }

        final trick = Trick(leadPlayerIndex: leaderIndex, plays: plays);
        final winnerIndex = TrickResolver.resolve(trick, trumpSuit: trumpSuit);

        // Award trick to winning team
        final winningTeam = teamForSeat(winnerIndex);
        tricksWon[winningTeam] = (tricksWon[winningTeam] ?? 0) + 1;

        // Winner leads next trick
        leaderIndex = winnerIndex;
      }

      // All 8 tricks played, all cards used
      expect(tricksWon[Team.a]! + tricksWon[Team.b]!, equals(8));
      for (final hand in hands) {
        expect(hand, isEmpty);
      }

      // --- Score ---
      final biddingTeam = teamForSeat(bidderIndex); // seat 1 → Team.b
      expect(biddingTeam, equals(Team.b));

      final roundResult = Scorer.calculateRoundResult(
        bid: bidAmount,
        biddingTeam: biddingTeam,
        tricksWon: tricksWon,
      );

      // Apply score and verify it's > 0
      var scores = {Team.a: 0, Team.b: 0};
      scores = Scorer.applyScore(
        scores: scores,
        winningTeam: roundResult.winningTeam,
        points: roundResult.pointsAwarded,
      );

      final totalPoints = (scores[Team.a] ?? 0) + (scores[Team.b] ?? 0);
      expect(totalPoints, greaterThan(0));
    });

    test('Kout success gives instant win', () {
      const bid = BidAmount.kout;
      const biddingTeam = Team.a;
      const tricksWon = {Team.a: 8, Team.b: 0};

      final roundResult = Scorer.calculateRoundResult(
        bid: bid,
        biddingTeam: biddingTeam,
        tricksWon: tricksWon,
      );

      expect(roundResult.winningTeam, equals(Team.a));
      expect(roundResult.pointsAwarded, equals(31));

      // Kout is instant win — bypasses tug-of-war math
      final scores = Scorer.applyKout(winningTeam: roundResult.winningTeam);

      expect(scores[Team.a], 31);
      final winner = Scorer.checkGameOver(scores);
      expect(winner, equals(Team.a));
    });

    test('Kout failure gives 16 penalty to opponent', () {
      const bid = BidAmount.kout;
      const biddingTeam = Team.a;
      // Team A only wins 7 tricks, needs 8 for kout → failure
      const tricksWon = {Team.a: 7, Team.b: 1};

      final roundResult = Scorer.calculateRoundResult(
        bid: bid,
        biddingTeam: biddingTeam,
        tricksWon: tricksWon,
      );

      // Failure: opponent (Team.b) wins 16 points (not instant loss)
      expect(roundResult.winningTeam, equals(Team.b));
      expect(roundResult.pointsAwarded, equals(16));

      // Regular tug-of-war scoring applies
      final scores = Scorer.applyScore(
        scores: {Team.a: 0, Team.b: 0},
        winningTeam: roundResult.winningTeam,
        points: roundResult.pointsAwarded,
      );

      expect(scores[Team.b], 16);
      final winner = Scorer.checkGameOver(scores);
      expect(winner, isNull); // 16 < 31, game continues
    });

    test('Forced bid: last player cannot pass when no bid exists', () {
      final passedPlayers = [0, 1, 2];

      // Player 3 is the last remaining — must bid
      expect(
        BidValidator.isLastBidder(
          passedPlayers: passedPlayers,
          playerIndex: 3,
        ),
        isTrue,
      );

      final result = BidValidator.validatePass(
        passedPlayers: passedPlayers,
        playerIndex: 3,
        currentHighest: null,
      );
      expect(result.isValid, isFalse);
      expect(result.error, equals('must-bid'));
    });

    test('Forced bid: last player can pass when a bid already exists', () {
      final passedPlayers = [0, 1, 2];

      // Player 3 is last remaining but someone already bid
      final result = BidValidator.validatePass(
        passedPlayers: passedPlayers,
        playerIndex: 3,
        currentHighest: BidAmount.bab,
      );
      expect(result.isValid, isTrue);
    });
  });
}
