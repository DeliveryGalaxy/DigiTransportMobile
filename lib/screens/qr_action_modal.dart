import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'qr_scanner_page.dart';

class QrActionModal extends StatefulWidget {
  const QrActionModal({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<QrActionModal> createState() => _QrActionModalState();
}

class _QrActionModalState extends State<QrActionModal> {
  String? _scannedValue;
  String? _actionTitle;

  Future<void> _openScanner(String title) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => QrScannerPage(title: title)),
    );
    if (!mounted || value == null) {
      return;
    }
    setState(() {
      _actionTitle = title;
      _scannedValue = value;
    });
  }

  void _finish() {
    Navigator.of(context).pop();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_scannedValue == null ? 'QR' : 'Αποτέλεσμα'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: _scannedValue == null
              ? _ActionTiles(onSelect: _openScanner)
              : _ScanResult(
                  actionTitle: _actionTitle ?? '',
                  value: _scannedValue!,
                  onOk: _finish,
                ),
        ),
      ),
    );
  }
}

class _ActionTiles extends StatelessWidget {
  const _ActionTiles({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          title: 'Έναρξη Δρομολογίου',
          subtitle: 'Σάρωση QR για έναρξη',
          icon: Icons.route_outlined,
          onTap: () => onSelect('Έναρξη Δρομολογίου'),
        ),
        const SizedBox(height: 16),
        _ActionTile(
          title: 'Παραλαβή',
          subtitle: 'Σάρωση QR παραλαβής',
          icon: Icons.inventory_2_outlined,
          onTap: () => onSelect('Παραλαβή'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EAED)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.teal, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({
    required this.actionTitle,
    required this.value,
    required this.onOk,
  });

  final String actionTitle;
  final String value;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EAED)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_2, size: 48, color: AppColors.teal),
                  const SizedBox(height: 16),
                  Text(
                    actionTitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        FilledButton(onPressed: onOk, child: const Text('OK')),
      ],
    );
  }
}
