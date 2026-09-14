import 'package:flutter/material.dart';

import '../models/delivery.dart';
import '../models/scan_record.dart';
import '../services/aade_client.dart';
import '../services/scan_history_store.dart';
import '../theme/app_theme.dart';
import 'scan_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.revision = 0,
    this.historyStore,
    this.client,
  });

  final int revision;
  final ScanHistoryStore? historyStore;
  final AadeClient? client;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScanHistoryStore _store;
  List<ScanRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store = widget.historyStore ?? ScanHistoryStore();
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
    final records = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _openRecord(ScanRecord record) async {
    final client =
        widget.client ?? await AadeClient.fromStore();
    if (!mounted) {
      return;
    }
    await showScanRecordSheet(
      context: context,
      record: record,
      historyStore: _store,
      client: client,
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
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
