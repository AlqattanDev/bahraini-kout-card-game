import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_routes.dart';
import '../models/game_mode.dart';
import '../models/seat_config.dart';
import '../../game/theme/kout_theme.dart';
import '../../game/theme/geometric_patterns.dart';
import '../widgets/app_action_button.dart';

class OfflineLobbyScreen extends StatefulWidget {
  const OfflineLobbyScreen({super.key});

  @override
  State<OfflineLobbyScreen> createState() => _OfflineLobbyScreenState();
}

class _OfflineLobbyScreenState extends State<OfflineLobbyScreen> {
  List<SeatConfig> get _seats => const [
    SeatConfig(seatIndex: 0, uid: 'human_0', displayName: 'You', isBot: false),
    SeatConfig(
      seatIndex: 1,
      uid: 'bot_1',
      displayName: 'Bot Khalid',
      isBot: true,
    ),
    SeatConfig(
      seatIndex: 2,
      uid: 'bot_2',
      displayName: 'Bot Fatima',
      isBot: true,
    ),
    SeatConfig(
      seatIndex: 3,
      uid: 'bot_3',
      displayName: 'Bot Ahmed',
      isBot: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    final mq = MediaQuery.sizeOf(context);
    // Cap table by width and height so the stack + labels never overflow short screens.
    final tableSize = min(min(300.0, mq.width * 0.75), mq.height * 0.42);
    final avatarSize = tableSize * 0.21;

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
                width: tableSize,
                height: tableSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
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
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GeometricPatterns.overlayPainter(
                                    opacity: 0.08,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  'Kout',
                                  style: TextStyle(
                                    fontFamily: KoutTheme.monoFontFamily,
                                    color: KoutTheme.accent.withValues(
                                      alpha: 0.2,
                                    ),
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
                    Positioned(
                      top: -20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _seatWidget(seats[2], 'Team A', avatarSize),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _seatWidget(seats[1], 'Team B', avatarSize),
                      ),
                    ),
                    Positioned(
                      right: -30,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _seatWidget(seats[3], 'Team B', avatarSize),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _seatWidget(seats[0], 'Team A', avatarSize),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: AppPrimaryButton(
              width: double.infinity,
              height: 56,
              label: 'Start Game',
              textStyle: KoutTheme.bodyStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: KoutTheme.accent,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pushNamed(
                  context,
                  AppRoutes.game,
                  arguments: OfflineGameMode(seats: seats),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatWidget(SeatConfig seat, String team, double avatarSize) {
    final isHuman = !seat.isBot;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
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
                      color: KoutTheme.accent.withValues(alpha: 0.4),
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
        SizedBox(
          width: avatarSize * 1.6,
          child: Text(
            seat.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: KoutTheme.textColor,
              fontSize: 12,
              fontWeight: isHuman ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          team,
          style: TextStyle(
            color: team == 'Team A'
                ? KoutTheme.teamAColor
                : KoutTheme.teamBColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
