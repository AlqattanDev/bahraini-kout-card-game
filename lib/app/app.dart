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
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/': (_) => const HomeScreen(),
          '/matchmaking': (_) => const MatchmakingScreen(),
          '/game': (_) => const GameScreen(),
          '/offline-lobby': (_) => const OfflineLobbyScreen(),
          '/room-lobby': (_) => const RoomLobbyScreen(),
        };
        final builder = routes[settings.name];
        if (builder == null) return null;
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.0, 0.04), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    );
  }
}
