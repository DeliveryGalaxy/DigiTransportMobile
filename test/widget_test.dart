import 'package:digi_transport/app.dart';
import 'package:digi_transport/models/app_settings.dart';
import 'package:digi_transport/models/delivery.dart';
import 'package:digi_transport/models/scan_record.dart';
import 'package:digi_transport/screens/home_screen.dart';
import 'package:digi_transport/screens/qr_action_modal.dart';
import 'package:digi_transport/services/digi_api.dart';
import 'fake_digi_api.dart';
import 'package:digi_transport/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<void> seedReadyProfile() async {
    SharedPreferences.setMockInitialValues({
      SettingsStore.companyIdKey: 1,
      SettingsStore.companyConfirmedKey: true,
      SettingsStore.companyNameKey: 'ACME',
      SettingsStore.firstNameKey: 'Nikos',
      SettingsStore.lastNameKey: 'Papas',
      SettingsStore.identityUserIdKey: 'ABC1234',
      SettingsStore.tokenKey: 'token',
    });
  }

  testWidgets('QR button opens the action modal', (tester) async {
    await seedReadyProfile();
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_2));
    await tester.pumpAndSettle();

    expect(find.text('Έναρξη Δρομολογίου'), findsOneWidget);
    expect(find.text('Παραλαβή'), findsOneWidget);
  });

  testWidgets('settings persist first name', (tester) async {
    await seedReadyProfile();
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'driver01');
    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();

    expect(find.text('Αποθηκεύτηκε'), findsOneWidget);

    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('driver01'), findsOneWidget);
  });

  testWidgets('afm step asks for a value', (tester) async {
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Συνέχεια'));
    await tester.pumpAndSettle();

    expect(find.text('Συμπλήρωσε ΑΦΜ.'), findsOneWidget);
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
    await seedReadyProfile();
    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('https://i-deliver3.gr/digitransport/api/dev'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('https://i-deliver3.gr/digitransport/api/prod'), findsOneWidget);

    await tester.tap(find.text('Αποθήκευση'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const DigiTransportApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('https://i-deliver3.gr/digitransport/api/prod'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  ScanRecord sampleScan({
    required String id,
    required QrFlowAction action,
    required DeliveryStatus status,
    DateTime? scannedAt,
    String? invoiceMark,
    String? vehicleNumber,
    bool vehicleFromDocument = false,
    List<ScanAction> actions = const [],
  }) {
    return ScanRecord(
      id: id,
      qrUrl: 'https://example.com/fd/$id',
      action: action,
      scannedAt: scannedAt ?? DateTime(2026, 9, 1, 10),
      status: status,
      invoiceMark: invoiceMark,
      vehicleNumber: vehicleNumber,
      vehicleFromDocument: vehicleFromDocument,
      actions: actions,
    );
  }

  testWidgets('QR start flow shows AADE status instead of the scanned URL', (
    tester,
  ) async {
    const qrUrl =
        'https://beta-epsilondigital.epsilonnet.gr/fd/d16134dbe38e49e8709308def398fa17:6';
    final scan = sampleScan(
      id: '1',
      action: QrFlowAction.startRoute,
      status: DeliveryStatus.registered,
      invoiceMark: '111111111111111',
      actions: const [
        ScanAction(id: 'registerTransfer', label: 'Έναρξη διακίνησης'),
      ],
    );
    final api = FakeDigiApi(
      scans: [scan],
      openResult: OpenScanResult(scan: scan, existed: false),
      refreshed: scan,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QrActionModal(
          onFinished: () {},
          api: api,
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
    final scan = sampleScan(
      id: '1',
      action: QrFlowAction.startRoute,
      status: DeliveryStatus.registered,
      invoiceMark: '111111111111111',
      vehicleNumber: 'IYY1234',
      vehicleFromDocument: true,
    );
    final api = FakeDigiApi(
      scans: [scan],
      openResult: OpenScanResult(scan: scan, existed: false),
      refreshed: scan,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QrActionModal(
          onFinished: () {},
          api: api,
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
    final newer = sampleScan(
      id: 'new',
      action: QrFlowAction.receive,
      status: DeliveryStatus.inTransit,
      scannedAt: DateTime(2026, 9, 11, 15, 30),
      invoiceMark: '999',
    );
    final older = sampleScan(
      id: 'old',
      action: QrFlowAction.startRoute,
      status: DeliveryStatus.registered,
      scannedAt: DateTime(2026, 1, 1, 10),
    );
    final api = FakeDigiApi(scans: [newer, older], refreshed: newer);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(api: api)),
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
    expect(api.scans.map((record) => record.id), ['old']);
  });

  testWidgets('opening a list item refreshes AADE status when it changed', (
    tester,
  ) async {
    final saved = sampleScan(
      id: 'saved',
      action: QrFlowAction.startRoute,
      status: DeliveryStatus.registered,
      invoiceMark: '111',
    );
    final refreshed = saved.copyWith(
      status: DeliveryStatus.inTransit,
      vehicleNumber: 'IYY1234',
      actions: const [
        ScanAction(id: 'registerTransfer', label: 'Μεταφόρτωση'),
      ],
    );
    final api = FakeDigiApi(scans: [saved], refreshed: refreshed);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(api: api)),
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
    expect(find.text('Μεταφόρτωση'), findsOneWidget);
  });

  testWidgets('scanning a known MARK opens the saved card instead of the flow', (
    tester,
  ) async {
    const qrUrl = 'https://example.com/fd/abc:6';
    final saved = sampleScan(
      id: 'saved',
      action: QrFlowAction.startRoute,
      status: DeliveryStatus.inTransit,
      invoiceMark: '111111111111111',
      vehicleNumber: 'IYY1234',
      actions: const [
        ScanAction(id: 'registerTransfer', label: 'Μεταφόρτωση'),
      ],
    );
    final api = FakeDigiApi(
      scans: [saved],
      openResult: OpenScanResult(scan: saved, existed: true),
      refreshed: saved,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QrActionModal(
          onFinished: () {},
          api: api,
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
    expect(api.scans.map((record) => record.id), ['saved']);
  });
}
