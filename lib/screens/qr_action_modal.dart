import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/aade_client.dart';
import '../services/scan_history_store.dart';
import '../services/scan_record_sync.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import 'delivery_flow_page.dart';
import 'qr_scanner_page.dart';
import 'scan_detail_sheet.dart';

class QrActionModal extends StatefulWidget {
  const QrActionModal({
    super.key,
    required this.onFinished,
    this.client,
    this.store,
    this.historyStore,
    this.scanQr,
  });

  final VoidCallback onFinished;
  final AadeClient? client;
  final SettingsStore? store;
  final ScanHistoryStore? historyStore;
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
    final client =
        widget.client ?? await AadeClient.fromStore(store: widget.store);
    final history = widget.historyStore ?? ScanHistoryStore();
    if (!mounted) {
      return;
    }

    setState(() => _lookingUp = true);
    final existing = await _findExistingRecord(
      client: client,
      history: history,
      qrUrl: qrUrl,
    );
    if (!mounted) {
      return;
    }
    setState(() => _lookingUp = false);

    if (existing != null) {
      await showScanRecordSheet(
        context: context,
        record: existing,
        historyStore: history,
        client: client,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onFinished();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DeliveryFlowPage(
          action: action,
          qrUrl: qrUrl,
          client: client,
          store: widget.store,
          historyStore: history,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    widget.onFinished();
  }

  Future<ScanRecord?> _findExistingRecord({
    required AadeClient client,
    required ScanHistoryStore history,
    required String qrUrl,
  }) async {
    final byUrl = await history.findByQrUrl(qrUrl);
    if (!client.isConfigured) {
      return byUrl;
    }
    try {
      final result = await client.getDeliveryNoteStatus(qrUrl: qrUrl);
      final note = client.parseStatusXml(result.body);
      final byMark = await history.findByMark(note?.invoiceMark);
      final found = byMark ?? byUrl;
      if (found == null) {
        return null;
      }
      if (note == null || !ScanRecordSync.isDifferent(found, note)) {
        return found;
      }
      final updated = ScanRecordSync.mergeStatus(found, note);
      await history.update(updated);
      return updated;
    } catch (_) {
      return byUrl;
    }
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
