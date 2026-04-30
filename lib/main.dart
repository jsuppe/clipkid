import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(ClipKidApp(showOnboarding: !onboardingDone));
}

class ClipKidApp extends StatefulWidget {
  final bool showOnboarding;
  const ClipKidApp({super.key, required this.showOnboarding});

  @override
  State<ClipKidApp> createState() => _ClipKidAppState();
}

class _ClipKidAppState extends State<ClipKidApp> {
  late bool _showOnboarding = widget.showOnboarding;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    setState(() => _showOnboarding = false);
  }

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
      home: _showOnboarding
          ? OnboardingScreen(onComplete: _completeOnboarding)
          : const HomeScreen(),
    );
  }
}
