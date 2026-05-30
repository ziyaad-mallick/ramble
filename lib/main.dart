import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/ramble_theme.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.instance.init();
  await SettingsService.instance.init();
  await NotificationService.instance.init();
  runApp(const RambleApp());
}

class RambleApp extends StatelessWidget {
  const RambleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ramble',
      debugShowCheckedModeBanner: false,
      theme: RambleTheme.themeData(Brightness.light),
      darkTheme: RambleTheme.themeData(Brightness.dark),
      themeMode: ThemeMode.system,
      home: SettingsService.instance.onboarded
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
