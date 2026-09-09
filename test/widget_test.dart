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
  });
}
