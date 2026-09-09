import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

class DigiTransportApp extends StatelessWidget {
  const DigiTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiTransport',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
