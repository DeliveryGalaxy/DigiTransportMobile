import 'package:digi_transport/models/app_settings.dart';
import 'package:digi_transport/models/delivery.dart';
import 'package:digi_transport/models/scan_record.dart';
import 'package:digi_transport/services/aade_client.dart';
import 'package:digi_transport/services/scan_history_store.dart';
import 'package:digi_transport/services/scan_record_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final record = ScanRecord(
    id: '1',
    qrUrl: 'https://example.com/fd/x',
    action: QrFlowAction.startRoute,
    scannedAt: DateTime.utc(2026, 1, 1),
    status: DeliveryStatus.registered,
    invoiceMark: '111',
  );

  test('detects a different AADE status and updates the local record', () async {
    const note = DeliveryNoteStatus(
      status: DeliveryStatus.inTransit,
      invoiceMark: '111',
      vehicleNumber: 'IYY1234',
    );
    expect(ScanRecordSync.isDifferent(record, note), isTrue);

    final store = ScanHistoryStore();
    await store.add(record);
    final client = AadeClient(
      settings: const AppSettings(
        username: 'user01',
        afm: '123456789',
        subscriptionKey: 'key',
      ),
      httpClient: MockClient(
        (_) async => http.Response('''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111</invoiceMark>
  <status>IN_TRANSIT</status>
</GetDeliveryNoteStatusResponse>
''', 200),
      ),
    );

    final updated = await ScanRecordSync.refresh(
      client: client,
      store: store,
      record: record,
    );
    expect(updated.status, DeliveryStatus.inTransit);
    expect((await store.load()).first.status, DeliveryStatus.inTransit);
  });
}
