import 'package:digi_transport/app.dart';
import 'package:digi_transport/models/app_settings.dart';
import 'package:digi_transport/models/scan_record.dart';
import 'package:digi_transport/screens/home_screen.dart';
import 'package:digi_transport/screens/qr_action_modal.dart';
import 'package:digi_transport/services/aade_client.dart';
import 'package:digi_transport/services/scan_history_store.dart';
import 'package:digi_transport/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home shows the app name', (tester) async {
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pump();

    expect(find.text('DigiTransport'), findsOneWidget);
  });

  testWidgets('QR button opens the action modal', (tester) async {
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.qr_code_2));
    await tester.pumpAndSettle();

    expect(find.text('Έναρξη Δρομολογίου'), findsOneWidget);
    expect(find.text('Παραλαβή'), findsOneWidget);
  });

  testWidgets('settings persist username, AFM and subscription key', (
    tester,
  ) async {
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'driver01');
    await tester.enterText(find.byType(TextField).at(1), '123456789');
    await tester.enterText(find.byType(TextField).at(2), 'sub-key-1');
    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();

    expect(find.text('Αποθηκεύτηκε'), findsOneWidget);

    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('driver01'), findsOneWidget);
    expect(find.text('123456789'), findsOneWidget);
  });

  testWidgets('AADE test button reports missing credentials', (tester) async {
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(find.text('Αποτυχία σύνδεσης'), findsOneWidget);
    expect(find.textContaining('Username και Subscription Key'), findsOneWidget);
  });

  test('settings store writes values locally', () async {
    final store = SettingsStore();
    await store.save(
      const AppSettings(
        username: 'nick',
        afm: '999999999',
        subscriptionKey: 'abc',
      ),
    );

    final loaded = await store.load();
    expect(loaded.username, 'nick');
    expect(loaded.afm, '999999999');
    expect(loaded.subscriptionKey, 'abc');
    expect(loaded.environment, AadeEnvironment.development);
  });

  testWidgets('settings persist AADE environment', (tester) async {
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('https://mydataapidev.aade.gr'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('https://mydatapi.aade.gr/myDATA'), findsOneWidget);

    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('https://mydatapi.aade.gr/myDATA'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('QR start flow shows AADE status instead of the scanned URL', (
    tester,
  ) async {
    const qrUrl =
        'https://beta-epsilondigital.epsilonnet.gr/fd/d16134dbe38e49e8709308def398fa17:6';
    const statusXml = '''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111111111111111</invoiceMark>
  <status>REGISTERED</status>
</GetDeliveryNoteStatusResponse>
''';
    final client = AadeClient(
      settings: const AppSettings(
        username: 'user01',
        afm: '123456789',
        subscriptionKey: 'key',
      ),
      httpClient: MockClient((_) async => http.Response(statusXml, 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QrActionModal(
          onFinished: () {},
          client: client,
          scanQr: (_) async => qrUrl,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Έναρξη Δρομολογίου'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(qrUrl), findsNothing);
    expect(find.text('Εκδόθηκε'), findsOneWidget);
    expect(find.text('Έναρξη διακίνησης'), findsOneWidget);
    expect(find.text('ΜΑΡΚ 111111111111111'), findsOneWidget);
  });

  testWidgets('start route uses vehicle number from the delivery note', (
    tester,
  ) async {
    const qrUrl = 'https://example.com/fd/abc:6';
    const statusXml = '''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111111111111111</invoiceMark>
  <status>REGISTERED</status>
</GetDeliveryNoteStatusResponse>
''';
    const invoiceXml = '''
<RequestedDoc>
  <invoice>
    <invoiceHeader>
      <vehicleNumber>IYY1234</vehicleNumber>
    </invoiceHeader>
    <mark>111111111111111</mark>
  </invoice>
</RequestedDoc>
''';
    final client = AadeClient(
      settings: const AppSettings(
        username: 'user01',
        afm: '123456789',
        subscriptionKey: 'key',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.contains('Request')) {
          return http.Response(invoiceXml, 200);
        }
        return http.Response(statusXml, 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QrActionModal(
          onFinished: () {},
          client: client,
          scanQr: (_) async => qrUrl,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Έναρξη Δρομολογίου'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Πινακίδα από παραστατικό: IYY1234'), findsOneWidget);
    expect(find.text('Αριθμός κυκλοφορίας'), findsNothing);
  });

  testWidgets('home lists scans newest first and deletes only from the list', (
    tester,
  ) async {
    final store = ScanHistoryStore();
    await store.add(
      ScanRecord(
        id: 'old',
        qrUrl: 'https://example.com/fd/old',
        action: QrFlowAction.startRoute,
        scannedAt: DateTime(2026, 1, 1, 10),
        status: DeliveryStatus.registered,
      ),
    );
    await store.add(
      ScanRecord(
        id: 'new',
        qrUrl: 'https://example.com/fd/new',
        action: QrFlowAction.receive,
        scannedAt: DateTime(2026, 9, 11, 15, 30),
        status: DeliveryStatus.inTransit,
        invoiceMark: '999',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(historyStore: store)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Παραλαβή'), findsOneWidget);
    expect(find.text('Έναρξη Δρομολογίου'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Παραλαβή')).dy <
          tester.getTopLeft(find.text('Έναρξη Δρομολογίου')).dy,
      isTrue,
    );

    await tester.tap(find.text('Παραλαβή'));
    await tester.pumpAndSettle();
    expect(find.text('ΜΑΡΚ'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);

    await tester.tap(find.text('Διαγραφή'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('χωρίς να επηρεάσει κάτι στην ΑΑΔΕ'),
      findsOneWidget,
    );

    await tester.tap(find.text('Διαγραφή').last);
    await tester.pumpAndSettle();

    expect(find.text('Παραλαβή'), findsNothing);
    expect(find.text('Έναρξη Δρομολογίου'), findsOneWidget);
    expect((await store.load()).map((record) => record.id), ['old']);
  });

  testWidgets('opening a list item refreshes AADE status when it changed', (
    tester,
  ) async {
    final store = ScanHistoryStore();
    await store.add(
      ScanRecord(
        id: 'saved',
        qrUrl: 'https://example.com/fd/saved',
        action: QrFlowAction.startRoute,
        scannedAt: DateTime(2026, 9, 1, 10),
        status: DeliveryStatus.registered,
        invoiceMark: '111',
      ),
    );
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
  <vehicleNumber>IYY1234</vehicleNumber>
</GetDeliveryNoteStatusResponse>
''', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(historyStore: store, client: client),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Εκδόθηκε'), findsOneWidget);

    await tester.tap(find.text('Έναρξη Δρομολογίου'));
    await tester.pumpAndSettle();

    expect(find.text('Σε διακίνηση'), findsWidgets);
    expect(find.text('IYY1234'), findsOneWidget);
    expect(find.text('Έναρξη διακίνησης'), findsNothing);
    expect((await store.load()).first.status, DeliveryStatus.inTransit);
  });

  testWidgets('scanning a known MARK opens the saved card instead of the flow', (
    tester,
  ) async {
    const qrUrl = 'https://example.com/fd/abc:6';
    final history = ScanHistoryStore();
    await history.add(
      ScanRecord(
        id: 'saved',
        qrUrl: 'https://example.com/fd/previous',
        action: QrFlowAction.startRoute,
        scannedAt: DateTime(2026, 9, 1, 10),
        status: DeliveryStatus.registered,
        invoiceMark: '111111111111111',
        vehicleNumber: 'IYY1234',
      ),
    );
    final client = AadeClient(
      settings: const AppSettings(
        username: 'user01',
        afm: '123456789',
        subscriptionKey: 'key',
      ),
      httpClient: MockClient(
        (_) async => http.Response('''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111111111111111</invoiceMark>
  <status>IN_TRANSIT</status>
</GetDeliveryNoteStatusResponse>
''', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QrActionModal(
          onFinished: () {},
          client: client,
          historyStore: history,
          scanQr: (_) async => qrUrl,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Έναρξη Δρομολογίου'));
    await tester.pumpAndSettle();

    expect(find.text('Διαγραφή'), findsOneWidget);
    expect(find.text('Έναρξη διακίνησης'), findsNothing);
    expect(find.text('Σε διακίνηση'), findsOneWidget);
    expect(find.text('IYY1234'), findsOneWidget);
    expect((await history.load()).map((record) => record.id), ['saved']);
  });
}
