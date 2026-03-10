import 'package:flutter/material.dart';
import 'screens/editor_screen.dart';

void main() {
  runApp(const ClipKidApp());
}

class ClipKidApp extends StatelessWidget {
  const ClipKidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipKid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}
