import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller/app_controller.dart';
import 'screens/family_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await AppController.instance.boot();
  runApp(const SinaApp());
}

class SinaApp extends StatelessWidget {
  const SinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    // First launch with no emergency contact → force the setup screen.
    final needsOnboarding = !s.firstRunDone && s.emergencyContacts.isEmpty;
    return MaterialApp(
      title: 'SINA',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0612),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFFE879F9),
          surface: Color(0xFF1A1030),
          onSurface: Color(0xFFF0EAFF),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFE879F9),
          thumbColor: Color(0xFFE879F9),
        ),
        useMaterial3: true,
      ),
      initialRoute: needsOnboarding ? '/onboarding' : '/',
      routes: {
        '/': (_) => const MainScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/family': (_) => const FamilyScreen(),
      },
    );
  }
}
