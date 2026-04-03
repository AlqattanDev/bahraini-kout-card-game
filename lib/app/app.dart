import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/game_screen.dart';
import 'screens/offline_lobby_screen.dart';
import 'screens/room_lobby_screen.dart';

class KoutApp extends StatelessWidget {
  const KoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bahraini Kout',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF2F403E),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/matchmaking': (_) => const MatchmakingScreen(),
        '/game': (_) => const GameScreen(),
        '/offline-lobby': (_) => const OfflineLobbyScreen(),
        '/room-lobby': (_) => const RoomLobbyScreen(),
      },
    );
  }
}
