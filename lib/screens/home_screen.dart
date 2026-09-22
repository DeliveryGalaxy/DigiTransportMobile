import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/delivery.dart';
import '../models/scan_record.dart';
import '../services/digi_api.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import 'scan_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.revision = 0,
    this.api,
  });

  final int revision;
  final DigiApi? api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScanRecord> _records = [];
  AppSettings _profile = const AppSettings();
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final profile = await SettingsStore().load();
    final api = widget.api ?? await DigiApi.fromStore();
    if (!mounted) {
      return;
    }
    setState(() => _profile = profile);
    if (!api.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _records = [];
        _loading = false;
        _needsLogin = true;
        _error = null;
      });
      return;
    }
    try {
      final records = await api.listScans();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
        _needsLogin = false;
        _error = null;
      });
    } on DigiApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _openRecord(ScanRecord record) async {
    final api = widget.api ?? await DigiApi.fromStore();
    if (!mounted) {
      return;
    }
    await showScanRecordSheet(
      context: context,
      record: record,
      api: api,
      onChanged: _load,
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DigiTransport',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ιστορικό σαρώσεων',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_profile.shouldDisplayPlated) ...[
              _vehicleCard(),
              const SizedBox(height: 16),
            ],
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _vehicleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5DEE2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Όχημα',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  _profile.identityUserId,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _changeVehicle,
            child: const Text('Αλλαγή'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeVehicle() async {
    final identityController = TextEditingController();
    final pinController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        var obscure = true;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Αλλαγή οχήματος'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: identityController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Πινακίδα'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    obscureText: obscure,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      suffixIcon: IconButton(
                        onPressed: () => setLocal(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Άκυρο'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Έλεγχος'),
                ),
              ],
            );
          },
        );
      },
    );
    final identity = identityController.text.trim();
    final pin = pinController.text.trim();
    identityController.dispose();
    pinController.dispose();
    if (confirmed != true || !mounted) {
      return;
    }
    if (identity.isEmpty || pin.isEmpty) {
      _showMessage('Συμπλήρωσε πινακίδα και PIN.');
      return;
    }
    try {
      final api = widget.api ?? await DigiApi.fromStore();
      final result = await api.verifyIdentity(
        companyId: _profile.companyId,
        userId: identity,
        pin: pin,
      );
      final next = _profile.copyWith(
        token: result.token,
        identityUserId: result.userId,
        pin: pin,
      );
      await SettingsStore().save(next);
      if (!mounted) {
        return;
      }
      setState(() => _profile = next);
    } on DigiApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsLogin) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'Συνδέσου από τις Ρυθμίσεις.',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          _error!,
          style: const TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      );
    }
    if (_records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'Δεν υπάρχουν σαρώσεις ακόμα.',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 108),
      itemCount: _records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = _records[index];
        return Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openRecord(record),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      record.action == QrFlowAction.startRoute
                          ? Icons.route_outlined
                          : Icons.inventory_2_outlined,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.action.title,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.status.label,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.scannedAtLabel,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        if (record.invoiceMark != null &&
                            record.invoiceMark!.isNotEmpty)
                          Text(
                            'ΜΑΡΚ ${record.invoiceMark}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
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
      },
    );
  }
}
