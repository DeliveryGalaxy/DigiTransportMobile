import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/aade_client.dart';
import '../services/scan_history_store.dart';
import '../services/scan_record_sync.dart';
import '../theme/app_theme.dart';

class ScanDetailSheet extends StatefulWidget {
  const ScanDetailSheet({
    super.key,
    required this.record,
    required this.onDelete,
    this.client,
    this.historyStore,
    this.onUpdated,
  });

  final ScanRecord record;
  final Future<void> Function() onDelete;
  final AadeClient? client;
  final ScanHistoryStore? historyStore;
  final ValueChanged<ScanRecord>? onUpdated;

  @override
  State<ScanDetailSheet> createState() => _ScanDetailSheetState();
}

class _ScanDetailSheetState extends State<ScanDetailSheet> {
  late ScanRecord _record;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _refresh();
  }

  Future<void> _refresh() async {
    final client = widget.client;
    final store = widget.historyStore;
    if (client == null || store == null || !client.isConfigured) {
      return;
    }
    setState(() => _refreshing = true);
    final updated = await ScanRecordSync.refresh(
      client: client,
      store: store,
      record: _record,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshing = false;
      _record = updated;
    });
    if (updated != widget.record && updated.id == widget.record.id) {
      widget.onUpdated?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DEE2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Text(
              record.action.title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              record.status.label,
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Σάρωση', value: record.scannedAtLabel),
            if (record.invoiceMark != null && record.invoiceMark!.isNotEmpty)
              _DetailRow(label: 'ΜΑΡΚ', value: record.invoiceMark!),
            if (record.dispatchTimestamp != null &&
                record.dispatchTimestamp!.isNotEmpty)
              _DetailRow(
                label: 'Έναρξη διακίνησης',
                value: record.dispatchTimestamp!,
              ),
            if (record.vehicleNumber != null &&
                record.vehicleNumber!.isNotEmpty)
              _DetailRow(label: 'Όχημα', value: record.vehicleNumber!),
            if (record.transportType != null)
              _DetailRow(
                label: 'Είδος μέσου',
                value: record.transportType!.label,
              ),
            if (record.lastAction != null && record.lastAction!.isNotEmpty)
              _DetailRow(label: 'Τελευταία ενέργεια', value: record.lastAction!),
            if (record.lastMessage != null && record.lastMessage!.isNotEmpty)
              _DetailRow(label: 'Μήνυμα', value: record.lastMessage!),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                side: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
              ),
              onPressed: widget.onDelete,
              child: const Text('Διαγραφή'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmLocalScanDelete(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Διαγραφή από τη λίστα'),
        content: const Text(
          'Αυτό θα διαγραφεί από τη λίστα χωρίς να επηρεάσει κάτι στην ΑΑΔΕ. '
          'Θέλετε να προχωρήσετε;',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ακύρωση'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Διαγραφή'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

Future<void> showScanRecordSheet({
  required BuildContext context,
  required ScanRecord record,
  required ScanHistoryStore historyStore,
  AadeClient? client,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return ScanDetailSheet(
        record: record,
        client: client,
        historyStore: historyStore,
        onUpdated: (_) => onChanged?.call(),
        onDelete: () async {
          final confirmed = await confirmLocalScanDelete(sheetContext);
          if (!confirmed || !sheetContext.mounted) {
            return;
          }
          await historyStore.delete(record.id);
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
          onChanged?.call();
        },
      );
    },
  );
}
