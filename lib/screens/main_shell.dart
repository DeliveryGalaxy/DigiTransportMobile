import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'qr_action_modal.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  Future<void> _openQrModal() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QrActionModal(
          onFinished: () {
            setState(() => _index = 0);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), SettingsScreen()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: _openQrModal,
          tooltip: 'QR',
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.qr_code_2, size: 36),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        elevation: 10,
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _NavButton(
                    icon: Icons.home_rounded,
                    label: 'Αρχική',
                    selected: _index == 0,
                    onPressed: () => setState(() => _index = 0),
                  ),
                ),
                const SizedBox(width: 72),
                Expanded(
                  child: _NavButton(
                    icon: Icons.settings_rounded,
                    label: 'Ρυθμίσεις',
                    selected: _index == 1,
                    onPressed: () => setState(() => _index = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : AppColors.muted;
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
