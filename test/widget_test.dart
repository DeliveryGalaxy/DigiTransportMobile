import 'package:digi_transport/app.dart';
import 'package:digi_transport/models/app_settings.dart';
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
}
