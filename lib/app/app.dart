import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/game_screen.dart';

class KoutApp extends StatelessWidget {
  const KoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bahraini Kout',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF3B2314),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/matchmaking': (_) => const MatchmakingScreen(),
        '/game': (_) => const GameScreen(),
      },
    );
  }
}
