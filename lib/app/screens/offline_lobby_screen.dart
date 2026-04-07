import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_mode.dart';
import '../models/seat_config.dart';
import '../../offline/bot/bot_difficulty.dart';
import '../../game/theme/kout_theme.dart';
import '../../game/theme/geometric_patterns.dart';

class OfflineLobbyScreen extends StatefulWidget {
  const OfflineLobbyScreen({super.key});

  @override
  State<OfflineLobbyScreen> createState() => _OfflineLobbyScreenState();
}

class _OfflineLobbyScreenState extends State<OfflineLobbyScreen> {
  BotDifficulty _difficulty = BotDifficulty.balanced;

  List<SeatConfig> get _seats => [
        const SeatConfig(
            seatIndex: 0,
            uid: 'human_0',
            displayName: 'You',
            isBot: false),
        SeatConfig(
            seatIndex: 1,
            uid: 'bot_1',
            displayName: 'Bot Khalid',
            isBot: true,
            difficulty: _difficulty),
        SeatConfig(
            seatIndex: 2,
            uid: 'bot_2',
            displayName: 'Bot Fatima',
            isBot: true,
            difficulty: _difficulty),
        SeatConfig(
            seatIndex: 3,
            uid: 'bot_3',
            displayName: 'Bot Ahmed',
            isBot: true,
            difficulty: _difficulty),
      ];

  @override
  Widget build(BuildContext context) {
    final seats = _seats;

    return Scaffold(
      backgroundColor: KoutTheme.table,
      appBar: AppBar(
        title: Text(
          'Offline Game',
          style: TextStyle(color: KoutTheme.textColor),
        ),
        backgroundColor: KoutTheme.primary,
        foregroundColor: KoutTheme.textColor,
        iconTheme: IconThemeData(color: KoutTheme.textColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Table background with gold shadow and geometric overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: KoutTheme.primary,
                          borderRadius: BorderRadius.circular(150),
                          border: Border.all(color: KoutTheme.accent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: KoutTheme.accent.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            children: [
                              // Geometric pattern overlay at 8% opacity
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GeometricPatterns.overlayPainter(opacity: 0.08),
                                ),
                              ),
                              // Centre text
                              Center(
                                child: Text(
                                  'Kout',
                                  style: TextStyle(
                                    fontFamily: KoutTheme.monoFontFamily,
                                    color: KoutTheme.accent.withValues(alpha: 0.2),
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Seat 2 (top - partner)
                    Positioned(
                      top: -20,
                      left: 0,
                      right: 0,
                      child: Center(child: _seatWidget(seats[2], 'Team A')),
                    ),
                    // Seat 1 (left - opponent)
                    Positioned(
                      left: -30,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _seatWidget(seats[1], 'Team B')),
                    ),
                    // Seat 3 (right - opponent)
                    Positioned(
                      right: -30,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _seatWidget(seats[3], 'Team B')),
                    ),
                    // Seat 0 (bottom - you)
                    Positioned(
                      bottom: -20,
                      left: 0,
                      right: 0,
                      child: Center(child: _seatWidget(seats[0], 'Team A')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Difficulty selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Bot Style: ',
                    style: KoutTheme.bodyStyle),
                const SizedBox(width: 8),
                ...BotDifficulty.values.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_difficultyLabel(d)),
                        selected: _difficulty == d,
                        onSelected: (_) => setState(() => _difficulty = d),
                        selectedColor: KoutTheme.accent,
                        backgroundColor: KoutTheme.primary,
                        labelStyle: TextStyle(
                          color: _difficulty == d
                              ? KoutTheme.table
                              : KoutTheme.textColor,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: _difficulty == d
                              ? KoutTheme.accent
                              : KoutTheme.secondary,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: _buildStartGameButton(seats),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStartGameButton(List<SeatConfig> seats) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pushNamed(
            context,
            '/game',
            arguments: OfflineGameMode(seats: seats),
          );
        },
        style: KoutTheme.primaryButtonStyle,
        child: Text(
          'Start Game',
          style: KoutTheme.bodyStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: KoutTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _seatWidget(SeatConfig seat, String team) {
    final isHuman = !seat.isBot;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHuman ? KoutTheme.accent : KoutTheme.primary,
            border: Border.all(
              color: isHuman ? KoutTheme.accent : KoutTheme.secondary,
              width: 2,
            ),
            boxShadow: isHuman
                ? [
                    BoxShadow(
                      color: const Color(0xFF738C5A).withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isHuman ? Icons.person : Icons.smart_toy,
            color: isHuman ? KoutTheme.table : KoutTheme.textColor,
            size: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          seat.displayName,
          style: TextStyle(
            color: KoutTheme.textColor,
            fontSize: 12,
            fontWeight: isHuman ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          team,
          style: TextStyle(
            color: team == 'Team A'
                ? KoutTheme.accent
                : KoutTheme.secondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _difficultyLabel(BotDifficulty d) => switch (d) {
        BotDifficulty.conservative => 'Safe',
        BotDifficulty.balanced => 'Balanced',
        BotDifficulty.aggressive => 'Bold',
      };
}
