import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/scan_record.dart';
import '../services/digi_api.dart';
import '../theme/app_theme.dart';
import 'delivery_flow_page.dart';

class ScanDetailSheet extends StatefulWidget {
  const ScanDetailSheet({
    super.key,
    required this.record,
    required this.api,
    required this.onDelete,
    this.onUpdated,
  });

  final ScanRecord record;
  final DigiApi api;
  final Future<void> Function() onDelete;
  final ValueChanged<ScanRecord>? onUpdated;

  @override
  State<ScanDetailSheet> createState() => _ScanDetailSheetState();
}

class _ScanDetailSheetState extends State<ScanDetailSheet> {
  late ScanRecord _record;
  _Pane _pane = _Pane.details;
  bool _refreshing = false;
  bool _loadingHistory = false;
  List<DeliveryEvent> _events = [];
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final updated = await widget.api.refreshScan(_record.id);
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _record = updated;
      });
      widget.onUpdated?.call(updated);
    } on DigiApiException {
      if (!mounted) return;
      setState(() => _refreshing = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final events = await widget.api.history(_record.id);
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _events = events;
      });
    } on DigiApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyError = error.message;
      });
    }
  }

  Future<void> _runAction(ScanAction action) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DeliveryFlowPage(
          api: widget.api,
          record: _record,
          focusAction: action.id,
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
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
              const SizedBox(height: 16),
              SegmentedButton<_Pane>(
                segments: const [
                  ButtonSegment(value: _Pane.details, label: Text('Στοιχεία')),
                  ButtonSegment(value: _Pane.qr, label: Text('QR Code')),
                  ButtonSegment(value: _Pane.history, label: Text('Ιστορικό')),
                ],
                selected: {_pane},
                onSelectionChanged: (selection) {
                  setState(() => _pane = selection.first);
                  if (selection.first == _Pane.history &&
                      _events.isEmpty &&
                      !_loadingHistory) {
                    _loadHistory();
                  }
                },
              ),
              const SizedBox(height: 16),
              Expanded(child: _paneBody(record)),
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              for (final action in record.actions) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _runAction(action),
                    child: Text(action.label),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB3261E),
                    side: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
                  ),
                  onPressed: widget.onDelete,
                  child: const Text('Διαγραφή'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paneBody(ScanRecord record) {
    return switch (_pane) {
      _Pane.details => ListView(
          children: [
            _DetailRow(label: 'Σάρωση', value: record.scannedAtLabel),
            if (record.invoiceMark != null && record.invoiceMark!.isNotEmpty)
              _DetailRow(label: 'ΜΑΡΚ', value: record.invoiceMark!),
            if (record.dispatchTimestamp != null &&
                record.dispatchTimestamp!.isNotEmpty)
              _DetailRow(
                label: 'Έναρξη διακίνησης',
                value: record.dispatchTimestamp!,
              ),
            if (record.vehicleNumber != null && record.vehicleNumber!.isNotEmpty)
              _DetailRow(label: 'Όχημα', value: record.vehicleNumber!),
            if (record.transportType != null)
              _DetailRow(label: 'Είδος μέσου', value: record.transportType!.label),
            if (record.lastAction != null && record.lastAction!.isNotEmpty)
              _DetailRow(label: 'Τελευταία ενέργεια', value: record.lastAction!),
            if (record.lastMessage != null && record.lastMessage!.isNotEmpty)
              _DetailRow(label: 'Μήνυμα', value: record.lastMessage!),
          ],
        ),
      _Pane.qr => Center(
          child: QrImageView(
            data: record.qrUrl,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
      _Pane.history => _historyBody(),
    };
  }

  Widget _historyBody() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyError != null) {
      return Text(_historyError!, style: const TextStyle(color: AppColors.muted));
    }
    if (_events.isEmpty) {
      return const Text(
        'Δεν υπάρχει ιστορικό διακίνησης από την ΑΑΔΕ.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return ListView.separated(
      itemCount: _events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = _events[index];
        final details = [
          if (event.eventTimestamp != null && event.eventTimestamp!.isNotEmpty)
            event.eventTimestamp!,
          if (event.vehicleNumber != null && event.vehicleNumber!.isNotEmpty)
            'Όχημα ${event.vehicleNumber}',
          if (event.actorVat != null && event.actorVat!.isNotEmpty)
            'ΑΦΜ ${event.actorVat}',
          if (event.outcome != null && event.outcome!.isNotEmpty)
            event.outcome!,
          if (event.reason != null && event.reason!.isNotEmpty) event.reason!,
        ].join(' · ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.eventTypeLabel,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (details.isNotEmpty)
              Text(details, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        );
      },
    );
  }
}

enum _Pane { details, qr, history }

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
  required DigiApi api,
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
        api: api,
        onUpdated: (_) => onChanged?.call(),
        onDelete: () async {
          final confirmed = await confirmLocalScanDelete(sheetContext);
          if (!confirmed || !sheetContext.mounted) {
            return;
          }
          await api.deleteScan(record.id);
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
          onChanged?.call();
        },
      );
    },
  );
}
