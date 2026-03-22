import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _signInIfNeeded();
  }

  Future<void> _signInIfNeeded() async {
    if (_authService.currentUser == null) {
      setState(() => _isSigningIn = true);
      try {
        await _authService.signInAnonymously();
      } finally {
        if (mounted) setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bahraini Kout',
              style: TextStyle(fontSize: 32, color: Color(0xFFF5ECD7)),
            ),
            const SizedBox(height: 40),
            if (_isSigningIn)
              const CircularProgressIndicator()
            else
              StreamBuilder(
                stream: _authService.authStateChanges,
                builder: (context, snapshot) {
                  final isAuthenticated = snapshot.data != null;
                  return ElevatedButton(
                    onPressed: isAuthenticated
                        ? () => Navigator.pushNamed(context, '/matchmaking')
                        : null,
                    child: const Text('Play'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
