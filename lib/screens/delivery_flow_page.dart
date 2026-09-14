import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/scan_record.dart';
import '../services/aade_client.dart';
import '../services/aade_xml.dart';
import '../services/delivery_flow.dart';
import '../services/scan_history_store.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

class DeliveryFlowPage extends StatefulWidget {
  const DeliveryFlowPage({
    super.key,
    required this.action,
    required this.qrUrl,
    required this.client,
    this.store,
    this.historyStore,
  });

  final QrFlowAction action;
  final String qrUrl;
  final AadeClient client;
  final SettingsStore? store;
  final ScanHistoryStore? historyStore;

  @override
  State<DeliveryFlowPage> createState() => _DeliveryFlowPageState();
}

class _DeliveryFlowPageState extends State<DeliveryFlowPage> {
  late final SettingsStore _store;
  late final ScanHistoryStore _history;
  final _vehicleController = TextEditingController();
  final _trailerController = TextEditingController();
  final _rejectReasonController = TextEditingController();
  final _partialQtyController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  DeliveryNoteStatus? _note;
  DeliveryFlowPlan? _plan;
  TransportType _transportType = TransportType.privateTruck;
  DeliveryOutcome _outcome = DeliveryOutcome.full;
  AadeSubmitResult? _submitResult;
  ScanRecord? _record;
  bool _vehicleFromDocument = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SettingsStore();
    _history = widget.historyStore ?? ScanHistoryStore();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _vehicleController.text = await _store.loadLastVehicleNumber();
    _trailerController.text = await _store.loadLastTrailerNumber();
    _transportType = TransportType.fromCode(await _store.loadLastTransportType());
    _record = ScanRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      qrUrl: widget.qrUrl,
      action: widget.action,
      scannedAt: DateTime.now(),
    );
    await _history.add(_record!);
    await _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
      _submitResult = null;
    });

    if (!widget.client.isConfigured) {
      setState(() {
        _loading = false;
        _error = 'Συμπλήρωσε Username και Subscription Key στις ρυθμίσεις.';
      });
      await _persistRecord(
        message: 'Συμπλήρωσε Username και Subscription Key στις ρυθμίσεις.',
      );
      return;
    }

    final result = await widget.client.getDeliveryNoteStatus(qrUrl: widget.qrUrl);
    if (!mounted) {
      return;
    }

    final note = widget.client.parseStatusXml(result.body);
    if (!result.ok || note == null) {
      final fallback = widget.action == QrFlowAction.startRoute
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
        _error = result.message;
        _note = note;
        _plan = fallback;
      });
      await _persistRecord(message: result.message);
      return;
    }

    setState(() {
      _loading = false;
      _note = note;
      _plan = DeliveryFlowPlan.forAction(
        action: widget.action,
        status: note.status,
      );
    });
    await _applyVehicleFromDocument(note);
    if (!mounted) {
      return;
    }
    await _persistRecord(
      vehicleNumber: _vehicleController.text.trim(),
      transportType: _transportType,
    );
  }

  Future<void> _applyVehicleFromDocument(DeliveryNoteStatus note) async {
    var plate = note.vehicleNumber;
    var fromDocument = plate != null && plate.isNotEmpty;
    if (note.invoiceMark != null && note.invoiceMark!.isNotEmpty) {
      final invoiceXml = await widget.client.fetchInvoiceXml(
        invoiceMark: note.invoiceMark!,
      );
      if (invoiceXml != null) {
        final fromInvoice = extractVehicleNumberForMark(
          invoiceXml,
          note.invoiceMark!,
        );
        if (fromInvoice != null && fromInvoice.isNotEmpty) {
          plate = fromInvoice;
          fromDocument = true;
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _vehicleFromDocument = fromDocument;
      if (plate != null && plate.isNotEmpty) {
        _vehicleController.text = plate;
      }
      if (note.transportType != null) {
        _transportType = note.transportType!;
      }
      if (note.trailerNumber != null && note.trailerNumber!.isNotEmpty) {
        _trailerController.text = note.trailerNumber!;
      }
    });
  }

  Future<void> _submitAdvance() async {
    final plan = _plan;
    if (plan == null || !plan.canAdvance || _submitting) {
      return;
    }
    if (widget.action == QrFlowAction.startRoute) {
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
    final vat = widget.client.entityVatNumber;
    if (vat.isEmpty) {
      _showSnack('Συμπλήρωσε ΑΦΜ στις ρυθμίσεις.');
      return;
    }

    setState(() => _submitting = true);
    final result = await widget.client.registerTransfer(
      qrUrl: widget.qrUrl,
      details: TransportDetails(
        vehicleNumber: vehicle,
        transportType: _transportType,
        carrierVatNumber: vat,
        trailerNumber: _trailerController.text.trim(),
      ),
    );
    if (result.ok) {
      await _store.saveLastVehicle(
        vehicleNumber: vehicle,
        transportType: _transportType.code,
        trailerNumber: _trailerController.text.trim(),
      );
    }
    await _finishSubmit(
      result,
      lastAction: _plan?.advanceLabel ?? 'Έναρξη διακίνησης',
      vehicleNumber: vehicle,
      transportType: _transportType,
    );
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
    final result = await widget.client.confirmDeliveryOutcome(
      qrUrl: widget.qrUrl,
      outcome: outcome,
      packagingType: packagingType,
      packagingQuantity: packagingQuantity,
    );
    await _finishSubmit(result, lastAction: outcome.label);
  }

  Future<void> _submitReject() async {
    setState(() => _submitting = true);
    final result = await widget.client.rejectDeliveryNote(
      qrUrl: widget.qrUrl,
      reason: _rejectReasonController.text.trim(),
    );
    await _finishSubmit(result, lastAction: 'Απόρριψη παραλαβής');
  }

  Future<void> _finishSubmit(
    AadeSubmitResult result, {
    String? lastAction,
    String? vehicleNumber,
    TransportType? transportType,
  }) async {
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      setState(() {
        _submitting = false;
        _submitResult = result;
      });
      await _persistRecord(
        lastAction: lastAction,
        message: result.message,
        vehicleNumber: vehicleNumber,
        transportType: transportType,
      );
      return;
    }

    final refresh = await widget.client.getDeliveryNoteStatus(
      qrUrl: widget.qrUrl,
    );
    if (!mounted) {
      return;
    }
    final note = widget.client.parseStatusXml(refresh.body);
    setState(() {
      _submitting = false;
      _submitResult = result;
      if (note != null) {
        _note = note;
        _plan = DeliveryFlowPlan.forAction(
          action: widget.action,
          status: note.status,
        );
      }
    });
    await _persistRecord(
      lastAction: lastAction,
      message: result.message,
      vehicleNumber: vehicleNumber,
      transportType: transportType,
    );
  }

  Future<void> _persistRecord({
    String? lastAction,
    String? message,
    String? vehicleNumber,
    TransportType? transportType,
  }) async {
    final current = _record;
    if (current == null) {
      return;
    }
    final xml = _note?.rawXml ?? _submitResult?.body;
    _record = current.copyWith(
      status: _note?.status,
      invoiceMark: _note?.invoiceMark ?? _submitResult?.mark,
      dispatchTimestamp: _note?.dispatchTimestamp,
      vehicleNumber: vehicleNumber ?? xmlTag(xml ?? '', 'vehicleNumber'),
      transportType: transportType,
      lastAction: lastAction,
      lastMessage: message ?? _submitResult?.message,
    );
    await _history.update(_record!);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _advanceLabel(DeliveryFlowPlan plan) {
    if (widget.action == QrFlowAction.receive) {
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
        title: Text(widget.action.title),
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
    if (_submitResult != null && _submitResult!.ok && _note != null) {
      return _ResultCard(
        ok: true,
        title: _submitResult!.message,
        status: _note!.status,
        mark: _submitResult!.mark ?? _note!.invoiceMark,
        onClose: _close,
      );
    }

    final plan = _plan;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              if (_note != null) _StatusCard(note: _note!),
              if (_error != null && _note == null) ...[
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
              if (_submitResult != null && !_submitResult!.ok) ...[
                const SizedBox(height: 16),
                _MessageBox(text: _submitResult!.message, isError: true),
              ],
              if (plan != null && plan.canAdvance) ...[
                const SizedBox(height: 20),
                if (widget.action == QrFlowAction.startRoute)
                  _TransferForm(
                    vehicleController: _vehicleController,
                    trailerController: _trailerController,
                    transportType: _transportType,
                    vehicleFromDocument: _vehicleFromDocument,
                    onTransportType: (type) {
                      _transportType = type;
                    },
                    carrierVat: widget.client.entityVatNumber,
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
              widget.action == QrFlowAction.receive) ...[
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
