import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'DigiTransport',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
      ),
    );
  }
}
