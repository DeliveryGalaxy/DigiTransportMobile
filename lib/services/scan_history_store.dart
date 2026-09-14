import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_record.dart';

class ScanHistoryStore {
  ScanHistoryStore({this.prefs});

  static const historyKey = 'scan_history';

  SharedPreferences? prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<ScanRecord>> load() async {
    final stored = await _ensurePrefs();
    final raw = stored.getString(historyKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      final records = decoded
          .whereType<Map>()
          .map((item) => ScanRecord.fromJson(Map<String, dynamic>.from(item)))
          .where((record) => record.id.isNotEmpty)
          .toList();
      records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return records;
    } on FormatException {
      return [];
    }
  }

  Future<void> add(ScanRecord record) async {
    final records = await load();
    records.removeWhere((item) => item.id == record.id);
    records.insert(0, record);
    await _save(records);
  }

  Future<void> update(ScanRecord record) async {
    final records = await load();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.insert(0, record);
    }
    await _save(records);
  }

  Future<void> delete(String id) async {
    final records = await load();
    records.removeWhere((item) => item.id == id);
    await _save(records);
  }

  Future<ScanRecord?> findByMark(String? mark) async {
    final trimmed = mark?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final records = await load();
    for (final record in records) {
      if (record.invoiceMark?.trim() == trimmed) {
        return record;
      }
    }
    return null;
  }

  Future<ScanRecord?> findByQrUrl(String qrUrl) async {
    final url = qrUrl.trim();
    if (url.isEmpty) {
      return null;
    }
    final records = await load();
    for (final record in records) {
      if (record.qrUrl.trim() == url) {
        return record;
      }
    }
    return null;
  }

  Future<void> _save(List<ScanRecord> records) async {
    records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    final stored = await _ensurePrefs();
    await stored.setString(
      historyKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}
