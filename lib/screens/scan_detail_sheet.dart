import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/delivery.dart';
import '../models/scan_record.dart';
import '../services/digi_api.dart';
import '../services/plate_text.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class ScanDetailPage extends StatefulWidget {
  const ScanDetailPage({
    super.key,
    required this.record,
    required this.api,
    this.onChanged,
  });

  final ScanRecord record;
  final DigiApi api;
  final VoidCallback? onChanged;

  @override
  State<ScanDetailPage> createState() => _ScanDetailPageState();
}

class _ScanDetailPageState extends State<ScanDetailPage> {
  late ScanRecord _record;
  bool _busy = false;
  bool _loadingHistory = true;
  List<DeliveryEvent> _events = [];
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _refresh();
    _loadHistory();
  }

  Future<void> _refresh() async {
    try {
      final updated = await widget.api.refreshScan(_record.id);
      if (!mounted) return;
      setState(() => _record = updated);
      widget.onChanged?.call();
    } on DigiApiException {
      return;
    }
  }

  Future<void> _loadHistory() async {
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

  Future<void> _onAction(ScanAction action) async {
    switch (action.id) {
      case 'registerTransfer':
        await _transfer(action.label);
      case 'outcomeFull':
        if (await _confirm('Να δηλωθεί πλήρης παράδοση;')) {
          await _submitOutcome(DeliveryOutcome.full);
        }
      case 'outcomeNone':
        if (await _confirm('Να δηλωθεί ότι η παράδοση δεν έγινε;')) {
          await _submitOutcome(DeliveryOutcome.none);
        }
      case 'outcomePartial':
        await _partial();
      case 'reject':
        await _reject();
    }
  }

  Future<void> _transfer(String label) async {
    final vehicle = _record.vehicleNumber?.trim() ?? '';
    final transport = _record.transportType ?? TransportType.privateTruck;
    if (vehicle.isEmpty && transport != TransportType.none) {
      final typed = await _askPlate();
      if (typed == null || !mounted) return;
      await _submitTransfer(typed, transport);
      return;
    }
    final plate = vehicle.isEmpty ? 'χωρίς πινακίδα' : vehicle;
    if (await _confirm('Να δηλωθεί $label με όχημα $plate;')) {
      await _submitTransfer(vehicle, transport);
    }
  }

  Future<String?> _askPlate() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Πινακίδα'),
          content: SizedBox(
            width: 280,
            child: TextField(
              controller: controller,
              inputFormatters: const [PlateTextInputFormatter()],
              decoration: const InputDecoration(labelText: 'Πινακίδα'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                normalizePlate(controller.text.trim()),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    });
  }

  Future<void> _partial() async {
    final controller = TextEditingController();
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Μερική παράδοση'),
          content: SizedBox(
            width: 280,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Πόσες συσκευασίες;'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    });
    if (quantity == null || quantity <= 0 || !mounted) {
      if (mounted && quantity != null) {
        _showMessage('Συμπλήρωσε πλήθος συσκευασιών.');
      }
      return;
    }
    await _submitOutcome(DeliveryOutcome.partial, packagingQuantity: quantity);
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Απόρριψη παραλαβής'),
          content: SizedBox(
            width: 280,
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Γιατί; (προαιρετικό)'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    });
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.api.rejectDelivery(id: _record.id, reason: reason);
      _apply(updated, 'Η παραλαβή απορρίφθηκε.');
    } on DigiApiException catch (error) {
      _fail(error.message);
    }
  }

  Future<void> _submitTransfer(String vehicle, TransportType transport) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.registerTransfer(
        id: _record.id,
        vehicleNumber: vehicle,
        transportType: transport.code,
        trailerNumber: _record.trailerNumber,
      );
      await SettingsStore().saveLastVehicle(
        vehicleNumber: vehicle,
        transportType: transport.code,
        trailerNumber: _record.trailerNumber,
      );
      _apply(updated, 'Η διακίνηση καταχωρήθηκε.');
    } on DigiApiException catch (error) {
      _fail(error.message);
    }
  }

  Future<void> _submitOutcome(
    DeliveryOutcome outcome, {
    int? packagingQuantity,
  }) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.confirmOutcome(
        id: _record.id,
        outcome: outcome.apiValue,
        packagingType: packagingQuantity == null ? null : 6,
        packagingQuantity: packagingQuantity,
      );
      _apply(updated, outcome.label);
    } on DigiApiException catch (error) {
      _fail(error.message);
    }
  }

  void _apply(ScanRecord updated, String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _record = updated;
    });
    widget.onChanged?.call();
    _loadHistory();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    _showMessage(message);
  }

  Future<bool> _confirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((value) => value == true);
  }

  void _showMessage(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final actions = record.actions;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(record.status.label),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            record.invoiceMark == null || record.invoiceMark!.isEmpty
                ? 'Στοιχεία δελτίου'
                : 'ΜΑΡΚ ${record.invoiceMark}',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Κατάσταση', value: record.status.label),
          _DetailRow(label: 'Σάρωση', value: record.scannedAtLabel),
          if (record.dispatchTimestamp != null && record.dispatchTimestamp!.isNotEmpty)
            _DetailRow(label: 'Έναρξη', value: record.dispatchTimestamp!),
          if (record.vehicleNumber != null && record.vehicleNumber!.isNotEmpty)
            _DetailRow(label: 'Όχημα', value: record.vehicleNumber!),
          if (record.transportType != null)
            _DetailRow(label: 'Μέσο', value: record.transportType!.label),
          if (record.trailerNumber != null && record.trailerNumber!.isNotEmpty)
            _DetailRow(label: 'Ρυμουλκούμενο', value: record.trailerNumber!),
          if (record.lastAction != null && record.lastAction!.isNotEmpty)
            _DetailRow(label: 'Τελευταία ενέργεια', value: record.lastAction!),
          if (record.lastMessage != null && record.lastMessage!.isNotEmpty)
            _DetailRow(label: 'Μήνυμα', value: record.lastMessage!),
          const SizedBox(height: 8),
          const Text(
            'Τι θέλεις να κάνεις;',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (actions.isEmpty)
            const Text(
              'Δεν υπάρχει κάτι να δηλώσεις τώρα.',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            )
          else
            for (var index = 0; index < actions.length; index++) ...[
              SizedBox(
                width: double.infinity,
                child: index == 0
                    ? FilledButton(
                        onPressed: () => _onAction(actions[index]),
                        child: Text(actions[index].label),
                      )
                    : OutlinedButton(
                        onPressed: () => _onAction(actions[index]),
                        child: Text(actions[index].label),
                      ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 20),
          const Text(
            'QR για άλλον',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Δείξε αυτή την εικόνα για να τη σκανάρει άλλο κινητό.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: record.qrUrl,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ιστορικό',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _historyBody(),
        ],
      ),
    );
  }

  Widget _historyBody() {
    if (_loadingHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_historyError != null) {
      return Text(_historyError!, style: const TextStyle(color: AppColors.muted));
    }
    if (_events.isEmpty) {
      return const Text(
        'Δεν υπάρχει ιστορικό από την ΑΑΔΕ.',
        style: TextStyle(color: AppColors.muted, fontSize: 15),
      );
    }
    return Column(
      children: [
        for (final event in _events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DetailRow(
              label: event.eventTypeLabel,
              value: [
                if (event.eventTimestamp != null && event.eventTimestamp!.isNotEmpty)
                  event.eventTimestamp!,
                if (event.vehicleNumber != null && event.vehicleNumber!.isNotEmpty)
                  event.vehicleNumber!,
                if (event.outcome != null && event.outcome!.isNotEmpty) event.outcome!,
              ].join(' · '),
            ),
          ),
      ],
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
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
        content: const Text(
          'Να φύγει από τη λίστα; Δεν αλλάζει κάτι στην ΑΑΔΕ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('OK'),
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
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ScanDetailPage(
        record: record,
        api: api,
        onChanged: onChanged,
      ),
    ),
  );
}
