import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/delivery.dart';
import '../models/scan_record.dart';
import '../services/delivery_flow.dart';
import '../services/digi_api.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class DeliveryFlowPage extends StatefulWidget {
  const DeliveryFlowPage({
    super.key,
    required this.api,
    required this.record,
    this.store,
    this.focusAction,
  });

  final DigiApi api;
  final ScanRecord record;
  final SettingsStore? store;
  final String? focusAction;

  @override
  State<DeliveryFlowPage> createState() => _DeliveryFlowPageState();
}

class _DeliveryFlowPageState extends State<DeliveryFlowPage> {
  late final SettingsStore _store;
  final _vehicleController = TextEditingController();
  final _trailerController = TextEditingController();
  final _rejectReasonController = TextEditingController();
  final _partialQtyController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  DeliveryFlowPlan? _plan;
  TransportType _transportType = TransportType.privateTruck;
  DeliveryOutcome _outcome = DeliveryOutcome.full;
  String? _submitMessage;
  bool _submitOk = false;
  late ScanRecord _record;
  bool _vehicleFromDocument = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SettingsStore();
    _record = widget.record;
    _bootstrap();
  }

  QrFlowAction get _action => _record.action;

  Future<void> _bootstrap() async {
    _vehicleController.text = _record.vehicleNumber?.trim().isNotEmpty == true
        ? _record.vehicleNumber!.trim()
        : await _store.loadLastVehicleNumber();
    _trailerController.text = _record.trailerNumber?.trim().isNotEmpty == true
        ? _record.trailerNumber!.trim()
        : await _store.loadLastTrailerNumber();
    _transportType = _record.transportType ??
        TransportType.fromCode(await _store.loadLastTransportType());
    _vehicleFromDocument = _record.vehicleFromDocument;
    if (widget.focusAction == 'outcomePartial') {
      _outcome = DeliveryOutcome.partial;
    } else if (widget.focusAction == 'outcomeNone') {
      _outcome = DeliveryOutcome.none;
    }
    await _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
      _submitMessage = null;
      _submitOk = false;
    });

    try {
      final refreshed = await widget.api.refreshScan(_record.id);
      if (!mounted) return;
      _applyRecord(refreshed);
      setState(() {
        _loading = false;
        _record = refreshed;
        _plan = DeliveryFlowPlan.forAction(
          action: refreshed.action,
          status: refreshed.status,
        );
      });
    } on DigiApiException catch (error) {
      if (!mounted) return;
      final fallback = _action == QrFlowAction.startRoute
          ? const DeliveryFlowPlan(
              canAdvance: true,
              advanceLabel: 'Έναρξη διακίνησης',
              cancelLabel: 'Ακύρωση',
              explanation:
                  'Δεν βρέθηκε κατάσταση. Μπορείς να δηλώσεις έναρξη αν το QR είναι έγκυρο.',
            )
          : const DeliveryFlowPlan(
              canAdvance: false,
              cancelLabel: 'Κλείσιμο',
              explanation: 'Δεν βρέθηκε κατάσταση δελτίου για παραλαβή.',
            );
      setState(() {
        _loading = false;
        _error = error.message;
        _plan = _record.status == DeliveryStatus.unknown
            ? fallback
            : DeliveryFlowPlan.forAction(
                action: _record.action,
                status: _record.status,
              );
      });
    }
  }

  void _applyRecord(ScanRecord record) {
    _vehicleFromDocument = record.vehicleFromDocument;
    if (record.vehicleNumber != null && record.vehicleNumber!.isNotEmpty) {
      _vehicleController.text = record.vehicleNumber!;
    }
    if (record.transportType != null) {
      _transportType = record.transportType!;
    }
    if (record.trailerNumber != null && record.trailerNumber!.isNotEmpty) {
      _trailerController.text = record.trailerNumber!;
    }
  }

  Future<void> _submitAdvance() async {
    final plan = _plan;
    if (plan == null || !plan.canAdvance || _submitting) {
      return;
    }
    if (_action == QrFlowAction.startRoute || widget.focusAction == 'registerTransfer') {
      await _submitRegisterTransfer();
      return;
    }
    await _submitConfirm(_outcome);
  }

  Future<void> _submitRegisterTransfer() async {
    final vehicle = _vehicleController.text.trim();
    if (vehicle.isEmpty && _transportType != TransportType.none) {
      _showSnack('Δεν βρέθηκε πινακίδα στο παραστατικό. Συμπλήρωσε αριθμό κυκλοφορίας.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final updated = await widget.api.registerTransfer(
        id: _record.id,
        vehicleNumber: vehicle,
        transportType: _transportType.code,
        trailerNumber: _trailerController.text.trim(),
      );
      await _store.saveLastVehicle(
        vehicleNumber: vehicle,
        transportType: _transportType.code,
        trailerNumber: _trailerController.text.trim(),
      );
      _finishOk(updated, 'Η διακίνηση καταχωρήθηκε.');
    } on DigiApiException catch (error) {
      _finishError(error.message);
    }
  }

  Future<void> _submitConfirm(DeliveryOutcome outcome) async {
    int? packagingType;
    int? packagingQuantity;
    if (outcome == DeliveryOutcome.partial) {
      packagingQuantity = int.tryParse(_partialQtyController.text.trim());
      if (packagingQuantity == null || packagingQuantity <= 0) {
        _showSnack('Για μερική παράδοση συμπλήρωσε πλήθος συσκευασιών.');
        return;
      }
      packagingType = 6;
    }

    setState(() => _submitting = true);
    try {
      final updated = await widget.api.confirmOutcome(
        id: _record.id,
        outcome: outcome.apiValue,
        packagingType: packagingType,
        packagingQuantity: packagingQuantity,
      );
      _finishOk(updated, outcome.label);
    } on DigiApiException catch (error) {
      _finishError(error.message);
    }
  }

  Future<void> _submitReject() async {
    setState(() => _submitting = true);
    try {
      final updated = await widget.api.rejectDelivery(
        id: _record.id,
        reason: _rejectReasonController.text.trim(),
      );
      _finishOk(updated, 'Η παραλαβή απορρίφθηκε.');
    } on DigiApiException catch (error) {
      _finishError(error.message);
    }
  }

  void _finishOk(ScanRecord updated, String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _submitOk = true;
      _submitMessage = message;
      _record = updated;
      _plan = DeliveryFlowPlan.forAction(
        action: updated.action,
        status: updated.status,
      );
    });
  }

  void _finishError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _submitOk = false;
      _submitMessage = message;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _advanceLabel(DeliveryFlowPlan plan) {
    if (_action == QrFlowAction.receive && widget.focusAction != 'registerTransfer') {
      return _outcome.label;
    }
    return plan.advanceLabel ?? 'Συνέχεια';
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _trailerController.dispose();
    _rejectReasonController.dispose();
    _partialQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _submitting ? null : _close,
        ),
        title: Text(_record.action.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_submitOk) {
      return _ResultCard(
        ok: true,
        title: _submitMessage ?? 'Καταχωρήθηκε',
        status: _record.status,
        mark: _record.invoiceMark,
        onClose: _close,
      );
    }

    final plan = _plan;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              _StatusCard(
                note: DeliveryNoteStatus(
                  status: _record.status,
                  invoiceMark: _record.invoiceMark,
                ),
              ),
              if (_error != null && _record.status == DeliveryStatus.unknown) ...[
                const SizedBox(height: 12),
                _MessageBox(text: _error!, isError: true),
              ],
              if (plan != null) ...[
                const SizedBox(height: 16),
                Text(
                  plan.explanation,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
              if (_submitMessage != null && !_submitOk) ...[
                const SizedBox(height: 16),
                _MessageBox(text: _submitMessage!, isError: true),
              ],
              if (plan != null && plan.canAdvance) ...[
                const SizedBox(height: 20),
                if (_action == QrFlowAction.startRoute ||
                    widget.focusAction == 'registerTransfer')
                  _TransferForm(
                    vehicleController: _vehicleController,
                    trailerController: _trailerController,
                    transportType: _transportType,
                    vehicleFromDocument: _vehicleFromDocument,
                    onTransportType: (type) {
                      setState(() => _transportType = type);
                    },
                    carrierVat: widget.api.companyAfm,
                  )
                else
                  _ReceiveForm(
                    plan: plan,
                    outcome: _outcome,
                    onOutcome: (value) => setState(() => _outcome = value),
                    rejectReasonController: _rejectReasonController,
                    partialQtyController: _partialQtyController,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: CircularProgressIndicator(),
          )
        else ...[
          if (plan != null && plan.canAdvance)
            FilledButton(
              onPressed: _submitAdvance,
              child: Text(_advanceLabel(plan)),
            ),
          if (plan != null &&
              plan.allowsFailedDelivery &&
              _action == QrFlowAction.receive) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _submitConfirm(DeliveryOutcome.none),
              child: const Text('Αποτυχία παράδοσης'),
            ),
          ],
          if (plan != null && plan.allowsReject) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                side: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
              ),
              onPressed: _submitReject,
              child: const Text('Απόρριψη παραλαβής'),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: _close,
            child: Text(plan?.cancelLabel ?? 'Ακύρωση'),
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.note});

  final DeliveryNoteStatus note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAED)),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_shipping_outlined, size: 44, color: AppColors.teal),
          const SizedBox(height: 12),
          Text(
            note.status.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (note.invoiceMark != null && note.invoiceMark!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ΜΑΡΚ ${note.invoiceMark}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF2F1) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? const Color(0xFFE8B4B0) : const Color(0xFFE2EAED),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? const Color(0xFF8C1D18) : AppColors.navy,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.ok,
    required this.title,
    required this.status,
    required this.onClose,
    this.mark,
  });

  final bool ok;
  final String title;
  final DeliveryStatus status;
  final String? mark;
  final VoidCallback onClose;

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
                  Icon(
                    ok ? Icons.check_circle_outline : Icons.error_outline,
                    size: 48,
                    color: ok ? AppColors.teal : const Color(0xFFB3261E),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status.label,
                    style: const TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                  if (mark != null && mark!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ΜΑΡΚ $mark',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        FilledButton(onPressed: onClose, child: const Text('OK')),
      ],
    );
  }
}

class _TransferForm extends StatelessWidget {
  const _TransferForm({
    required this.vehicleController,
    required this.trailerController,
    required this.transportType,
    required this.onTransportType,
    required this.carrierVat,
    required this.vehicleFromDocument,
  });

  final TextEditingController vehicleController;
  final TextEditingController trailerController;
  final TransportType transportType;
  final ValueChanged<TransportType> onTransportType;
  final String carrierVat;
  final bool vehicleFromDocument;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (vehicleFromDocument && vehicleController.text.trim().isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Πινακίδα από παραστατικό: ${vehicleController.text.trim()}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          TextField(
            controller: vehicleController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zΑ-Ωα-ω0-9\- ]')),
              LengthLimitingTextInputFormatter(50),
            ],
            decoration: const InputDecoration(labelText: 'Αριθμός κυκλοφορίας'),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TransportType>(
          initialValue: transportType,
          decoration: const InputDecoration(labelText: 'Είδος μέσου'),
          items: [
            for (final type in TransportType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
          ],
          onChanged: (value) {
            if (value != null) {
              onTransportType(value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: trailerController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          decoration: const InputDecoration(
            labelText: 'Ρυμουλκούμενο (προαιρετικό)',
          ),
        ),
        if (carrierVat.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ΑΦΜ μεταφορέα: $carrierVat',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReceiveForm extends StatefulWidget {
  const _ReceiveForm({
    required this.plan,
    required this.outcome,
    required this.onOutcome,
    required this.rejectReasonController,
    required this.partialQtyController,
  });

  final DeliveryFlowPlan plan;
  final DeliveryOutcome outcome;
  final ValueChanged<DeliveryOutcome> onOutcome;
  final TextEditingController rejectReasonController;
  final TextEditingController partialQtyController;

  @override
  State<_ReceiveForm> createState() => _ReceiveFormState();
}

class _ReceiveFormState extends State<_ReceiveForm> {
  late DeliveryOutcome _outcome;

  @override
  void initState() {
    super.initState();
    _outcome = widget.outcome;
  }

  @override
  Widget build(BuildContext context) {
    final outcomes = [
      DeliveryOutcome.full,
      if (widget.plan.allowsPartial) DeliveryOutcome.partial,
    ];
    return Column(
      children: [
        DropdownButtonFormField<DeliveryOutcome>(
          initialValue: outcomes.contains(_outcome)
              ? _outcome
              : DeliveryOutcome.full,
          decoration: const InputDecoration(labelText: 'Αποτέλεσμα'),
          items: [
            for (final value in outcomes)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _outcome = value);
            widget.onOutcome(value);
          },
        ),
        if (_outcome == DeliveryOutcome.partial) ...[
          const SizedBox(height: 12),
          TextField(
            controller: widget.partialQtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Πλήθος συσκευασιών',
            ),
          ),
        ],
        if (widget.plan.allowsReject) ...[
          const SizedBox(height: 12),
          TextField(
            controller: widget.rejectReasonController,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Αιτιολογία απόρριψης (προαιρετικό)',
            ),
          ),
        ],
      ],
    );
  }
}
