import 'package:digi_transport/models/delivery.dart';
import 'package:digi_transport/models/scan_record.dart';
import 'package:digi_transport/services/scan_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores scans newest first and deletes only locally', () async {
    final store = ScanHistoryStore();
    final older = ScanRecord(
      id: '1',
      qrUrl: 'https://example.com/fd/old',
      action: QrFlowAction.startRoute,
      scannedAt: DateTime.utc(2026, 1, 1, 10),
      status: DeliveryStatus.registered,
    );
    final newer = ScanRecord(
      id: '2',
      qrUrl: 'https://example.com/fd/new',
      action: QrFlowAction.receive,
      scannedAt: DateTime.utc(2026, 9, 11, 14),
      status: DeliveryStatus.inTransit,
      invoiceMark: '111',
    );

    await store.add(older);
    await store.add(newer);

    final loaded = await store.load();
    expect(loaded.map((record) => record.id), ['2', '1']);

    await store.update(newer.copyWith(status: DeliveryStatus.completed));
    final updated = await store.load();
    expect(updated.first.id, '2');
    expect(updated.first.status, DeliveryStatus.completed);
    expect(updated.first.scannedAt, newer.scannedAt);

    await store.delete('2');
    final remaining = await store.load();
    expect(remaining.map((record) => record.id), ['1']);

    await store.add(newer);
    expect((await store.findByMark('111'))?.id, '2');
    expect((await store.findByQrUrl('https://example.com/fd/old'))?.id, '1');
  });
}
