import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

class DigiTransportApp extends StatelessWidget {
  const DigiTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiTransport',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppStart(),
    );
  }
}

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  final SettingsStore _store = SettingsStore();
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: Text(
              'DigiTransport',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }
    if (settings.isReady) {
      return const MainShell();
    }
    return OnboardingScreen(
      settings: settings,
      onReady: (next) => setState(() => _settings = next),
    );
  }
}
