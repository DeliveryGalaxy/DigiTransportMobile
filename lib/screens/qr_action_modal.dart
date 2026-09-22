import 'package:flutter/material.dart';

import '../models/delivery.dart';
import '../services/aade_xml.dart';
import '../services/digi_api.dart';
import '../theme/app_theme.dart';
import 'delivery_flow_page.dart';
import 'qr_scanner_page.dart';
import 'scan_detail_sheet.dart';

class QrActionModal extends StatefulWidget {
  const QrActionModal({
    super.key,
    required this.onFinished,
    this.api,
    this.scanQr,
  });

  final VoidCallback onFinished;
  final DigiApi? api;
  final Future<String?> Function(String title)? scanQr;

  @override
  State<QrActionModal> createState() => _QrActionModalState();
}

class _QrActionModalState extends State<QrActionModal> {
  bool _lookingUp = false;

  Future<void> _openScanner(QrFlowAction action) async {
    final raw = widget.scanQr != null
        ? await widget.scanQr!(action.title)
        : await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => QrScannerPage(title: action.title),
            ),
          );
    if (!mounted || raw == null || raw.trim().isEmpty) {
      return;
    }

    final qrUrl = extractQrUrl(raw);
    final api = widget.api ?? await DigiApi.fromStore();
    if (!mounted) {
      return;
    }
    if (!api.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Συνδέσου από τις Ρυθμίσεις.')),
      );
      return;
    }

    setState(() => _lookingUp = true);
    try {
      final opened = await api.openScan(qrUrl: qrUrl, action: action);
      if (!mounted) {
        return;
      }
      setState(() => _lookingUp = false);
      if (opened.existed) {
        await showScanRecordSheet(
          context: context,
          record: opened.scan,
          api: api,
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => DeliveryFlowPage(
              api: api,
              record: opened.scan,
            ),
          ),
        );
      }
    } on DigiApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _lookingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    if (!mounted) {
      return;
    }
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
          onPressed: _lookingUp ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('QR'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: _lookingUp
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _ActionTile(
                      title: QrFlowAction.startRoute.title,
                      subtitle: 'Σάρωση QR για έναρξη',
                      icon: Icons.route_outlined,
                      onTap: () => _openScanner(QrFlowAction.startRoute),
                    ),
                    const SizedBox(height: 16),
                    _ActionTile(
                      title: QrFlowAction.receive.title,
                      subtitle: 'Σάρωση QR παραλαβής',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => _openScanner(QrFlowAction.receive),
                    ),
                  ],
                ),
        ),
      ),
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
