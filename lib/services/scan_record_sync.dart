import '../models/delivery.dart';
import '../models/scan_record.dart';
import 'aade_client.dart';
import 'scan_history_store.dart';

abstract final class ScanRecordSync {
  static ScanRecord mergeStatus(ScanRecord record, DeliveryNoteStatus note) {
    return record.copyWith(
      status: note.status,
      invoiceMark: _nonEmpty(note.invoiceMark),
      dispatchTimestamp: _nonEmpty(note.dispatchTimestamp),
      vehicleNumber: _nonEmpty(note.vehicleNumber),
      transportType: note.transportType,
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static bool isDifferent(ScanRecord record, DeliveryNoteStatus note) {
    return record.status != note.status ||
        (note.invoiceMark != null &&
            note.invoiceMark!.isNotEmpty &&
            note.invoiceMark != record.invoiceMark) ||
        (note.dispatchTimestamp != null &&
            note.dispatchTimestamp != record.dispatchTimestamp) ||
        (note.vehicleNumber != null &&
            note.vehicleNumber!.isNotEmpty &&
            note.vehicleNumber != record.vehicleNumber);
  }

  static Future<ScanRecord> refresh({
    required AadeClient client,
    required ScanHistoryStore store,
    required ScanRecord record,
  }) async {
    if (!client.isConfigured) {
      return record;
    }
    final result = await client.getDeliveryNoteStatus(qrUrl: record.qrUrl);
    final note = client.parseStatusXml(result.body);
    if (!result.ok || note == null || !isDifferent(record, note)) {
      return record;
    }
    final updated = mergeStatus(record, note);
    await store.update(updated);
    return updated;
  }
}
