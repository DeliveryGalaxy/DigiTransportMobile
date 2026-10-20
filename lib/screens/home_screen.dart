import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/scan_record.dart';
import '../services/digi_api.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import 'change_vehicle_dialog.dart';
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
            const SizedBox(height: 16),
            if (_profile.shouldDisplayPlated) ...[
              _vehicleCard(),
              const SizedBox(height: 20),
            ],
            const Text(
              'Ιστορικό σαρώσεων',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
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
    final next = await changeDeclaredVehicle(context, api: widget.api);
    if (next == null || !mounted) {
      return;
    }
    setState(() => _profile = next);
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

  Widget _swipeBackground(Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Widget _buildList() {
    if (_loading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsLogin) {
      return _refreshableMessage('Συνδέσου από τις Ρυθμίσεις.');
    }
    if (_error != null && _records.isEmpty) {
      return _refreshableMessage(_error!);
    }
    if (_records.isEmpty) {
      return _refreshableMessage('Δεν υπάρχουν σαρώσεις ακόμα.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 108),
      itemCount: _records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = _records[index];
        return LayoutBuilder(
          builder: (context, constraints) {
            return Dismissible(
              key: ValueKey(record.id),
              direction: DismissDirection.horizontal,
              confirmDismiss: (_) => confirmLocalScanDelete(context),
              onDismissed: (_) async {
                final api = widget.api ?? await DigiApi.fromStore();
                await api.deleteScan(record.id);
                if (!mounted) return;
                setState(() {
                  _records = _records.where((item) => item.id != record.id).toList();
                });
              },
              background: _swipeBackground(Alignment.centerLeft),
              secondaryBackground: _swipeBackground(Alignment.centerRight),
              child: SizedBox(
                width: constraints.maxWidth,
                child: Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openRecord(record),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.status.label,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (record.vehicleNumber != null && record.vehicleNumber!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              record.vehicleNumber!,
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (record.invoiceMark != null && record.invoiceMark!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'ΜΑΡΚ ${record.invoiceMark}',
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            record.scannedAtLabel,
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      ),
    );
  }

  Widget _refreshableMessage(String message) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
