import 'dart:async';
import 'dart:math';

import 'package:bahraini_kout/app/models/client_game_state.dart';
import 'package:bahraini_kout/app/models/seat_config.dart';
import 'package:bahraini_kout/shared/models/card.dart';
import 'package:bahraini_kout/shared/models/bid.dart';
import 'package:bahraini_kout/shared/models/deck.dart';
import 'package:bahraini_kout/shared/models/trick.dart';
import 'package:bahraini_kout/shared/models/game_state.dart';
import 'package:bahraini_kout/shared/logic/bid_validator.dart';
import 'package:bahraini_kout/shared/logic/play_validator.dart';
import 'package:bahraini_kout/shared/logic/trick_resolver.dart';
import 'package:bahraini_kout/shared/logic/scorer.dart';
import 'package:bahraini_kout/shared/constants/timing.dart';
import 'package:bahraini_kout/offline/full_game_state.dart';
import 'package:bahraini_kout/offline/player_controller.dart';
import 'package:bahraini_kout/offline/human_player_controller.dart';

class LocalGameController {
  final List<SeatConfig> seats;
  final Map<int, PlayerController> controllers;
  final int humanSeat;
  final bool enableDelays;

  late FullGameState _state;
  final _stateController = StreamController<ClientGameState>.broadcast();
  bool _disposed = false;

  LocalGameController({
    required this.seats,
    required this.controllers,
    this.humanSeat = 0,
    this.enableDelays = true,
  });

  Stream<ClientGameState> get stateStream => _stateController.stream;

  Future<void> start() async {
    _state = FullGameState(
      phase: GamePhase.waiting,
      players: seats,
      hands: {},
      scores: {Team.a: 0, Team.b: 0},
      trickCounts: {Team.a: 0, Team.b: 0},
      dealerSeat: Random().nextInt(4),
      currentSeat: 1,
    );

    // Game loop: rounds until game over
    while (!_disposed) {
      await _playRound();
      if (_disposed) break;

      final winner = Scorer.checkGameOver(_state.scores);
      if (winner != null) {
        _state.phase = GamePhase.gameOver;
        _emitState();
        break;
      }

      // Losing team deals; dealer only rotates when losing team flips
      _state.dealerSeat = nextDealerSeat(_state.dealerSeat, _state.scores);
    }
  }

  Future<void> _playRound() async {
    // DEALING
    await _deal();
    if (_disposed) return;

    // BIDDING (no reshuffle, last player must bid)
    final bidSuccess = await _bidding();
    if (_disposed || !bidSuccess) return;

    // TRUMP SELECTION
    await _trumpSelection();
    if (_disposed) return;

    // PLAYING (8 tricks)
    final poisonJoker = await _playTricks();
    if (_disposed) return;

    // ROUND SCORING
    await _roundScoring(poisonJoker);
  }

  Future<void> _deal() async {
    _state.phase = GamePhase.dealing;
    final deck = Deck.fourPlayer();
    final dealt = deck.deal(4);
    _state.hands = {
      for (int i = 0; i < 4; i++) i: dealt[i],
    };
    _state.trickCounts = {Team.a: 0, Team.b: 0};
    _state.trickWinners = [];
    _state.currentTrickPlays = [];
    _state.bid = null;
    _state.bidderSeat = null;
    _state.trumpSuit = null;
    _state.passedPlayers = [];
    _state.bidHistory = [];
    _state.trickNumber = 1;
    _emitState();
    if (enableDelays) await Future.delayed(GameTiming.dealDelay);
  }

  /// Waits a random 3-5s if [seat] is a bot and delays are enabled.
  Future<void> _botThinkingDelay(int seat) async {
    if (controllers[seat] is! HumanPlayerController && enableDelays) {
      final delay = Random().nextInt(GameTiming.botThinkingRangeMs) +
          GameTiming.botThinkingMinMs;
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  Future<bool> _bidding() async {
    _state.phase = GamePhase.bidding;
    _state.currentSeat = nextSeat(_state.dealerSeat);
    _emitState();

    while (!_disposed) {
      // Skip players who already passed
      if (_state.passedPlayers.contains(_state.currentSeat)) {
        _state.currentSeat = nextSeat(_state.currentSeat);
        continue;
      }

      final isForced = BidValidator.isLastBidder(
        passedPlayers: _state.passedPlayers,
        playerIndex: _state.currentSeat,
      );

      _emitState();

      await _botThinkingDelay(_state.currentSeat);

      final clientState = _toClientState(_state, _state.currentSeat);
      final context = BidContext(
        currentHighBid: _state.bid,
        isForced: isForced,
        passedPlayers: List.unmodifiable(_state.passedPlayers),
      );
      final action = await controllers[_state.currentSeat]!
          .decideAction(clientState, context);
      if (_disposed) return false;

      if (action is BidAction) {
        final result = BidValidator.validateBid(
          bidAmount: action.amount,
          currentHighest: _state.bid,
          passedPlayers: _state.passedPlayers,
          playerIndex: _state.currentSeat,
        );
        if (result.isValid) {
          _state.bid = action.amount;
          _state.bidderSeat = _state.currentSeat;
          _state.bidHistory = [
            ..._state.bidHistory,
            (seat: _state.currentSeat, action: '${action.amount.value}'),
          ];
          _emitState();

          // Kout ends bidding immediately
          if (action.amount == BidAmount.kout) {
            return true;
          }
        }
      } else if (action is PassAction) {
        final result = BidValidator.validatePass(
          passedPlayers: _state.passedPlayers,
          playerIndex: _state.currentSeat,
          currentHighest: _state.bid,
        );
        if (result.isValid) {
          _state.passedPlayers = [..._state.passedPlayers, _state.currentSeat];
          _state.bidHistory = [
            ..._state.bidHistory,
            (seat: _state.currentSeat, action: 'pass'),
          ];
          _emitState();
        }
      }

      // Check if bidding complete (3 passed, 1 bidder with a bid)
      final outcome = BidValidator.checkBiddingComplete(
        passedPlayers: _state.passedPlayers,
        currentHighest: _state.bid,
        highestBidderIndex: _state.bidderSeat,
      );
      if (outcome.isComplete) return true;

      _state.currentSeat = nextSeat(_state.currentSeat);
    }
    return false;
  }

  Future<void> _trumpSelection() async {
    _state.phase = GamePhase.trumpSelection;
    _state.currentSeat = _state.bidderSeat!;
    _emitState();

    await _botThinkingDelay(_state.bidderSeat!);

    final clientState = _toClientState(_state, _state.bidderSeat!);
    final action = await controllers[_state.bidderSeat!]!
        .decideAction(clientState, TrumpContext());
    if (_disposed) return;

    if (action is TrumpAction) {
      _state.trumpSuit = action.suit;
      _emitState();
    }
  }

  Future<bool> _playTricks() async {
    _state.phase = GamePhase.playing;

    // First trick: seat after bidder leads
    int leaderSeat = nextSeat(_state.bidderSeat!);

    for (int trick = 1; trick <= 8 && !_disposed; trick++) {
      _state.trickNumber = trick;
      _state.currentTrickPlays = [];
      _state.currentSeat = leaderSeat;
      _emitState();

      final trickPlays = <TrickPlay>[];

      for (int play = 0; play < 4 && !_disposed; play++) {
        final result = await _playSingleCard(
          seat: _state.currentSeat,
          isLead: play == 0,
          isLastPlay: play == 3,
          trickPlays: trickPlays,
        );
        if (_disposed) return false;
        if (result == _PlayResult.poisonJoker) return true;

        if (play < 3) {
          _state.currentSeat = nextSeat(_state.currentSeat);
        }
      }

      if (_disposed) return false;

      // Resolve trick winner
      final resolvedTrick = Trick(
        leadPlayerIndex: leaderSeat,
        plays: trickPlays,
      );
      final winnerSeat =
          TrickResolver.resolve(resolvedTrick, trumpSuit: _state.trumpSuit!);
      final winnerTeam = teamForSeat(winnerSeat);
      _state.trickCounts[winnerTeam] =
          (_state.trickCounts[winnerTeam] ?? 0) + 1;
      _state.trickWinners = [..._state.trickWinners, winnerTeam];
      _emitState();

      // Early termination: round decided before all 8 tricks
      if (Scorer.isRoundDecided(
        bidValue: _state.bid!.value,
        biddingTeam: teamForSeat(_state.bidderSeat!),
        tricksWon: _state.trickCounts,
      )) {
        break;
      }

      if (enableDelays) await Future.delayed(GameTiming.trickResolutionDelay);

      // Winner leads next trick
      leaderSeat = winnerSeat;
    }

    return false; // No poison joker
  }

  /// Play a single card for [seat]. Returns [_PlayResult.poisonJoker] if the
  /// round should end immediately, or [_PlayResult.ok] on a normal play.
  Future<_PlayResult> _playSingleCard({
    required int seat,
    required bool isLead,
    required bool isLastPlay,
    required List<TrickPlay> trickPlays,
  }) async {
    final hand = _state.hands[seat]!;

    // Poison Joker: last card is joker → automatic loss
    if (PlayValidator.detectPoisonJoker(hand)) {
      _state.currentSeat = seat;
      _emitState();
      return _PlayResult.poisonJoker;
    }

    final ledSuit = isLead ? null : _getLedSuit();
    _emitState();

    await _botThinkingDelay(seat);

    // Retry loop: bots always play valid cards; humans might tap invalid.
    while (!_disposed) {
      final clientState = _toClientState(_state, seat);
      final context = PlayContext(ledSuit: ledSuit);
      final action = await controllers[seat]!.decideAction(clientState, context);
      if (_disposed) return _PlayResult.ok;

      if (action is! PlayCardAction) continue;

      final validation = PlayValidator.validatePlay(
        card: action.card,
        hand: hand,
        ledSuit: ledSuit,
        isLeadPlay: isLead,
      );
      if (!validation.isValid) continue;

      // Valid play — commit it
      _state.hands[seat]!.remove(action.card);
      _state.currentTrickPlays = [
        ..._state.currentTrickPlays,
        (seat: seat, card: action.card),
      ];
      trickPlays.add(TrickPlay(playerIndex: seat, card: action.card));
      _emitState();

      // Joker led = immediate round loss
      if (PlayValidator.detectJokerLead(action.card, isLead)) {
        _state.currentSeat = seat;
        if (enableDelays) await Future.delayed(GameTiming.cardPlayDelay);
        return _PlayResult.poisonJoker;
      }

      // Delay between cards so the user can see each play
      if (enableDelays && !isLastPlay) {
        await Future.delayed(GameTiming.cardPlayDelay);
      }
      return _PlayResult.ok;
    }

    return _PlayResult.ok;
  }

  Future<void> _roundScoring(bool poisonJoker) async {
    _state.phase = GamePhase.roundScoring;

    RoundResult result;
    if (poisonJoker) {
      final poisonTeam = teamForSeat(_state.currentSeat);
      result = Scorer.calculatePoisonJokerResult(
        biddingTeam: teamForSeat(_state.bidderSeat!),
        poisonTeam: poisonTeam,
      );
    } else {
      result = Scorer.calculateRoundResult(
        bid: _state.bid!,
        biddingTeam: teamForSeat(_state.bidderSeat!),
        tricksWon: _state.trickCounts,
      );
    }

    // Kout success = instant win (set to 31). Kout failure = 16 penalty (regular scoring).
    final bidderTeam = teamForSeat(_state.bidderSeat!);
    if (!poisonJoker && _state.bid!.isKout && result.winningTeam == bidderTeam) {
      _state.scores = Scorer.applyKout(winningTeam: result.winningTeam);
    } else {
      _state.scores = Scorer.applyScore(
        scores: _state.scores,
        winningTeam: result.winningTeam,
        points: result.pointsAwarded,
      );
    }

    _emitState();

    if (enableDelays) await Future.delayed(GameTiming.scoringDelay);
  }

  Suit? _getLedSuit() {
    if (_state.currentTrickPlays.isEmpty) return null;
    final leadCard = _state.currentTrickPlays.first.card;
    return leadCard.isJoker ? null : leadCard.suit;
  }

  ClientGameState _toClientState(FullGameState full, int forSeat) {
    return ClientGameState(
      phase: full.phase,
      playerUids: full.players.map((p) => p.uid).toList(),
      scores: full.scores,
      tricks: full.trickCounts,
      currentPlayerUid: full.players[full.currentSeat].uid,
      dealerUid: full.players[full.dealerSeat].uid,
      trumpSuit: full.trumpSuit,
      currentBid: full.bid,
      bidderUid: full.bidderSeat != null
          ? full.players[full.bidderSeat!].uid
          : null,
      currentTrickPlays: full.currentTrickPlays
          .map(
            (p) => (playerUid: full.players[p.seat].uid, card: p.card),
          )
          .toList(),
      myHand: List<GameCard>.from(full.hands[forSeat] ?? []),
      myUid: full.players[forSeat].uid,
      passedPlayers: List.unmodifiable(full.passedPlayers),
      bidHistory: full.bidHistory
          .map((e) => (playerUid: full.players[e.seat].uid, action: e.action))
          .toList(),
      trickWinners: List.unmodifiable(full.trickWinners),
    );
  }

  void _emitState() {
    if (_disposed) return;
    _stateController.add(_toClientState(_state, humanSeat));
  }

  void dispose() {
    _disposed = true;
    _stateController.close();
  }
}

/// Internal result of a single card play attempt.
enum _PlayResult { ok, poisonJoker }
