import 'package:flutter/material.dart';

import '../models/delivery.dart';
import '../services/aade_xml.dart';
import '../services/digi_api.dart';
import '../theme/app_theme.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final raw = widget.scanQr != null
        ? await widget.scanQr!('Σάρωση')
        : await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => const QrScannerPage(title: 'Σάρωση'),
            ),
          );
    if (!mounted) {
      return;
    }
    if (raw == null || raw.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final qrUrl = extractQrUrl(raw);
    final api = widget.api ?? await DigiApi.fromStore();
    if (!mounted) {
      return;
    }
    if (!api.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ολοκλήρωσε πρώτα την είσοδο.')),
      );
      Navigator.of(context).pop();
      return;
    }

    try {
      final opened = await api.openScan(
        qrUrl: qrUrl,
        action: QrFlowAction.startRoute,
      );
      if (!mounted) {
        return;
      }
      await showScanRecordSheet(
        context: context,
        record: opened.scan,
        api: api,
      );
    } on DigiApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      Navigator.of(context).pop();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Σάρωση'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
