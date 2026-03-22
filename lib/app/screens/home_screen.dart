import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bahraini Kout', style: TextStyle(fontSize: 32, color: Color(0xFFF5ECD7))),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/matchmaking'),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}
