import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:koutbh/app/models/client_game_state.dart';
import 'package:koutbh/app/models/seat_config.dart';
import 'package:koutbh/shared/models/card.dart';
import 'package:koutbh/shared/models/bid.dart';
import 'package:koutbh/shared/models/deck.dart';
import 'package:koutbh/shared/models/trick.dart';
import 'package:koutbh/shared/models/game_state.dart';
import 'package:koutbh/shared/logic/bid_validator.dart';
import 'package:koutbh/shared/logic/play_validator.dart';
import 'package:koutbh/shared/logic/trick_resolver.dart';
import 'package:koutbh/shared/logic/scorer.dart';
import 'package:koutbh/shared/constants/timing.dart';
import 'package:koutbh/offline/full_game_state.dart';
import 'package:koutbh/offline/player_controller.dart';
import 'package:koutbh/offline/human_player_controller.dart';
import 'package:koutbh/offline/bot/card_tracker.dart';

class LocalGameController {
  final List<SeatConfig> seats;
  final Map<int, PlayerController> controllers;
  final int humanSeat;
  final bool enableDelays;

  late FullGameState _state;
  final _stateController = StreamController<ClientGameState>.broadcast();
  bool _disposed = false;
  bool _bidWasForced = false; // Track if winning bid was forced

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

    // BID ANNOUNCEMENT (brief pause showing bid + trump)
    await _bidAnnouncement();
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
    _state.hands = {for (int i = 0; i < 4; i++) i: dealt[i]};

    // Validate all hands have exactly 8 cards
    for (int i = 0; i < 4; i++) {
      final handSize = _state.hands[i]?.length ?? 0;
      if (handSize != 8) {
        throw StateError(
          'Invalid hand size for seat $i: expected 8, got $handSize',
        );
      }
    }

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

  /// Context-aware bot delay for any phase.
  Future<void> _botDelay(
    int seat, {
    bool isBidding = false,
    bool isPassing = false,
    bool isForced = false,
    BidAmount? amount,
    int legalMoves = 1,
  }) async {
    if (controllers[seat] is! HumanPlayerController && enableDelays) {
      await Future.delayed(
        GameTiming.botThinkingDelay(
          legalMoves: legalMoves,
          trickNumber: isBidding ? 0 : _state.trickNumber,
          isBidding: isBidding,
          isPassing: isPassing,
          isForcedBid: isForced,
          bidAmount: amount,
        ),
      );
    }
  }

  Future<bool> _bidding() async {
    _state.phase = GamePhase.bidding;
    _state.currentSeat = nextSeat(_state.dealerSeat);
    // One CCW orbit: each seat has exactly one successful bid or pass (Kout ends early).
    final seatsActed = <int>{};
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

      await _botDelay(_state.currentSeat, isBidding: true, isForced: isForced);

      final clientState = _toClientState(_state, _state.currentSeat);
      final context = BidContext(
        currentHighBid: _state.bid,
        isForced: isForced,
        passedPlayers: List.unmodifiable(_state.passedPlayers),
      );
      final action = await controllers[_state.currentSeat]!.decideAction(
        clientState,
        context,
      );
      if (_disposed) return false;

      var actionAccepted = false;
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
          _bidWasForced = isForced; // Track forced bid for play phase
          actionAccepted = true;
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
          actionAccepted = true;
          _state.bidHistory = [
            ..._state.bidHistory,
            (seat: _state.currentSeat, action: 'pass'),
          ];
          _emitState();
        }
      }

      // Invalid bid/pass: same seat tries again (do not advance).
      if (!actionAccepted) {
        continue;
      }

      seatsActed.add(_state.currentSeat);
      if (seatsActed.length >= seats.length) {
        return _state.bid != null;
      }

      _state.currentSeat = nextSeat(_state.currentSeat);
    }
    return false;
  }

  Future<void> _trumpSelection() async {
    _state.phase = GamePhase.trumpSelection;
    _state.currentSeat = _state.bidderSeat!;
    _emitState();

    await _botDelay(_state.bidderSeat!, isBidding: true, amount: _state.bid);

    final clientState = _toClientState(_state, _state.bidderSeat!);
    final action = await controllers[_state.bidderSeat!]!.decideAction(
      clientState,
      TrumpContext(isForcedBid: _bidWasForced),
    );
    if (_disposed) return;

    if (action is TrumpAction) {
      _state.trumpSuit = action.suit;
      _emitState();
    }
  }

  Future<void> _bidAnnouncement() async {
    _state.phase = GamePhase.bidAnnouncement;
    _emitState();
    if (enableDelays) await Future.delayed(GameTiming.bidAnnouncementDelay);
  }

  Future<bool> _playTricks() async {
    _state.phase = GamePhase.playing;
    final tracker = CardTracker();

    // First trick: seat after bidder leads
    int leaderSeat = nextSeat(_state.bidderSeat!);

    for (int trick = 1; trick <= 8 && !_disposed; trick++) {
      _state.trickNumber = trick;
      final trickPlays = await _playSingleTrick(trick, leaderSeat, tracker);
      if (_disposed) return false;
      if (trickPlays == null) return true; // poison joker

      // Resolve trick winner and update state
      final winnerSeat = await _resolveTrick(trickPlays, leaderSeat);
      if (_disposed) return false;

      // Early termination check
      if (_checkEarlyTermination()) break;

      if (enableDelays) await Future.delayed(GameTiming.trickResolutionDelay);

      // Winner leads next trick
      leaderSeat = winnerSeat;
    }

    return false; // No poison joker
  }

  /// Play a single trick (all 4 cards). Returns the trick plays, or null if
  /// poison joker was encountered.
  Future<List<TrickPlay>?> _playSingleTrick(
    int trickNumber,
    int leaderSeat,
    CardTracker tracker,
  ) async {
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
        tracker: tracker,
      );
      if (_disposed) return null;
      if (result == _PlayResult.poisonJoker) return null;

      if (play < 3) {
        _state.currentSeat = nextSeat(_state.currentSeat);
      }
    }

    return trickPlays;
  }

  /// Resolve trick winner and update trick counts.
  Future<int> _resolveTrick(List<TrickPlay> trickPlays, int leaderSeat) async {
    final resolvedTrick = Trick(leadPlayerIndex: leaderSeat, plays: trickPlays);
    final winnerSeat = TrickResolver.resolve(
      resolvedTrick,
      trumpSuit: _state.trumpSuit!,
    );
    final winnerTeam = teamForSeat(winnerSeat);
    _state.trickCounts[winnerTeam] = (_state.trickCounts[winnerTeam] ?? 0) + 1;
    _state.trickWinners = [..._state.trickWinners, winnerTeam];
    _emitState();
    return winnerSeat;
  }

  /// Check if round is decided before all 8 tricks are played.
  bool _checkEarlyTermination() {
    return Scorer.isRoundDecided(
      bidValue: _state.bid!.value,
      biddingTeam: teamForSeat(_state.bidderSeat!),
      tricksWon: _state.trickCounts,
    );
  }

  /// Play a single card for [seat]. Returns [_PlayResult.poisonJoker] if the
  /// round should end immediately, or [_PlayResult.ok] on a normal play.
  Future<_PlayResult> _playSingleCard({
    required int seat,
    required bool isLead,
    required bool isLastPlay,
    required List<TrickPlay> trickPlays,
    required CardTracker tracker,
  }) async {
    final hand = _state.hands[seat]!;

    // Poison Joker: only triggers when must lead and only card is Joker.
    // When following, Joker is a legal play — no poison.
    if (isLead && PlayValidator.detectPoisonJoker(hand)) {
      _state.currentSeat = seat;
      _emitState();
      return _PlayResult.poisonJoker;
    }

    final ledSuit = isLead ? null : _getLedSuit();
    _emitState();

    final suitCards = ledSuit != null
        ? hand.where((c) => !c.isJoker && c.suit == ledSuit).toList()
        : <GameCard>[];
    final legalMoves = suitCards.isNotEmpty ? suitCards.length : hand.length;
    await _botDelay(seat, legalMoves: legalMoves);

    // Retry loop: bots always play valid cards; humans might tap invalid.
    while (!_disposed) {
      final clientState = _toClientState(_state, seat);
      final context = PlayContext(
        ledSuit: ledSuit,
        isForced: _bidWasForced,
        tracker: tracker,
      );
      final action = await controllers[seat]!.decideAction(
        clientState,
        context,
      );
      if (_disposed) return _PlayResult.ok;

      if (action is! PlayCardAction) continue;

      final validation = PlayValidator.validatePlay(
        card: action.card,
        hand: hand,
        ledSuit: ledSuit,
        isLeadPlay: isLead,
        trumpSuit: _state.trumpSuit,
        isKout: _state.bid?.isKout ?? false,
        isFirstTrick: _state.trickNumber == 1,
      );
      if (!validation.isValid) continue;

      // Valid play — commit it
      _state.hands[seat]!.remove(action.card);
      _state.currentTrickPlays = [
        ..._state.currentTrickPlays,
        (seat: seat, card: action.card),
      ];
      trickPlays.add(TrickPlay(playerIndex: seat, card: action.card));

      // Track play and infer voids
      tracker.recordPlay(seat, action.card);
      if (!isLead &&
          ledSuit != null &&
          !action.card.isJoker &&
          action.card.suit != ledSuit) {
        tracker.inferVoid(seat, ledSuit);
      }

      _emitState();

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
      final jokerHolderTeam = teamForSeat(_state.currentSeat);
      result = Scorer.calculatePoisonJokerResult(
        jokerHolderTeam: jokerHolderTeam,
      );
      // Poison joker = instant game loss (same as Kout).
      _state.scores = Scorer.applyPoisonJoker(jokerHolderTeam: jokerHolderTeam);
    } else {
      result = Scorer.calculateRoundResult(
        bid: _state.bid!,
        biddingTeam: teamForSeat(_state.bidderSeat!),
        tricksWon: _state.trickCounts,
      );

      // Kout success = instant win (set to 31). Kout failure = 16 penalty (regular scoring).
      final bidderTeam = teamForSeat(_state.bidderSeat!);
      if (_state.bid!.isKout && result.winningTeam == bidderTeam) {
        _state.scores = Scorer.applyKout(winningTeam: result.winningTeam);
      } else {
        _state.scores = Scorer.applyScore(
          scores: _state.scores,
          winningTeam: result.winningTeam,
          points: result.pointsAwarded,
        );
      }
    }

    _emitState();

    if (enableDelays) await Future.delayed(GameTiming.scoringDelay);
    _state.roundIndex++;
  }

  Suit? _getLedSuit() {
    if (_state.currentTrickPlays.isEmpty) return null;
    final leadCard = _state.currentTrickPlays.first.card;
    return leadCard.isJoker ? null : leadCard.suit;
  }

  ClientGameState _toClientState(FullGameState full, int forSeat) {
    final cardCounts = <int, int>{};
    for (int seat = 0; seat < full.players.length; seat++) {
      cardCounts[seat] = (full.hands[seat] ?? []).length;
    }

    return ClientGameState(
      phase: full.phase,
      roundIndex: full.roundIndex,
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
          .map((p) => (playerUid: full.players[p.seat].uid, card: p.card))
          .toList(),
      myHand: List<GameCard>.from(full.hands[forSeat] ?? []),
      myUid: full.players[forSeat].uid,
      passedPlayers: List.unmodifiable(full.passedPlayers),
      bidHistory: full.bidHistory
          .map((e) => (playerUid: full.players[e.seat].uid, action: e.action))
          .toList(),
      trickWinners: List.unmodifiable(full.trickWinners),
      cardCounts: cardCounts,
      debugAllHands: kDebugMode
          ? {
              for (int i = 0; i < full.players.length; i++)
                full.players[i].uid: List<GameCard>.from(
                  full.hands[i] ?? const [],
                ),
            }
          : null,
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
