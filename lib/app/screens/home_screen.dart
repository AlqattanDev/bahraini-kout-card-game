import 'package:flutter/material.dart';
import '../../game/theme/kout_theme.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    await _authService.signInAnonymously();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KoutTheme.table,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bahraini Kout',
              style: KoutTheme.headingStyle.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              'كوت البحريني',
              style: KoutTheme.arabicHeadingStyle,
            ),
            const SizedBox(height: 48),
            _isLoading
                ? CircularProgressIndicator(
                    color: KoutTheme.accent,
                  )
                : _buildButton(
                    label: 'Play Online',
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/matchmaking',
                        arguments: {
                          'uid': _authService.currentUid,
                          'token': _authService.token,
                        },
                      );
                    },
                  ),
            const SizedBox(height: 16),
            _buildButton(
              label: 'Play Offline',
              onPressed: () => Navigator.pushNamed(context, '/offline-lobby'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 220,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: KoutTheme.primary,
          foregroundColor: KoutTheme.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: KoutTheme.accent, width: 1.5),
          ),
          textStyle: KoutTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
