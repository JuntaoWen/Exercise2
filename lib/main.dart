import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/game_controller.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const MemoryMatchApp());
}

class MemoryMatchApp extends StatelessWidget {
  const MemoryMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>(
      // Create one controller for the full app lifecycle.
      create: (_) => GameController()..initializeGame(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Memory Match',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
          useMaterial3: true,
        ),
        home: const GameScreen(),
      ),
    );
  }
}
