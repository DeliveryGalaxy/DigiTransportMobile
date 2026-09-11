import 'package:digi_transport/models/app_settings.dart';
import 'package:digi_transport/services/aade_client.dart';
import 'package:digi_transport/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const settings = AppSettings(
    username: 'user01',
    afm: '123456789',
    subscriptionKey: 'sub-key-1',
  );

  test('builds AADE auth headers from settings', () {
    final client = AadeClient(settings: settings);

    expect(client.headers[AadeHeaders.userId], 'user01');
    expect(client.headers[AadeHeaders.subscriptionKey], 'sub-key-1');
    expect(client.headers['Content-Type'], 'application/xml');
    expect(client.headers['Accept'], 'application/xml');
    expect(client.entityVatNumber, '123456789');
    expect(client.environment, AadeEnvironment.development);
    expect(client.isConfigured, isTrue);
  });

  test('uses production and development base URLs from AADE docs', () {
    final prod = AadeClient(
      settings: settings.copyWith(environment: AadeEnvironment.production),
    );
    final dev = AadeClient(settings: settings);

    expect(
      prod.registerTransferUri().toString(),
      'https://mydatapi.aade.gr/myDATA/RegisterTransfer',
    );
    expect(
      dev.registerTransferUri().toString(),
      'https://mydataapidev.aade.gr/RegisterTransfer',
    );
    expect(
      prod
          .getDeliveryNoteStatusUri(mark: '100', issuerVatNumber: '999')
          .toString(),
      'https://mydatapi.aade.gr/myDATA/GetDeliveryNoteStatus?mark=100&issuerVatNumber=999',
    );
    expect(
      dev.getDeliveryNoteStatusUri(mark: '100').toString(),
      'https://mydataapidev.aade.gr/GetDeliveryNoteStatus?mark=100',
    );
  });

  test('fromStore loads credentials saved in settings', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();
    await store.save(settings);

    final client = await AadeClient.fromStore(store: store);

    expect(client.headers[AadeHeaders.userId], 'user01');
    expect(client.headers[AadeHeaders.subscriptionKey], 'sub-key-1');
    expect(client.environment, AadeEnvironment.development);
    expect(client.isConfigured, isTrue);
  });

  test('fromStore uses the saved AADE environment', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore();
    await store.save(
      settings.copyWith(environment: AadeEnvironment.production),
    );

    final client = await AadeClient.fromStore(store: store);

    expect(client.environment, AadeEnvironment.production);
    expect(
      client.registerTransferUri().toString(),
      'https://mydatapi.aade.gr/myDATA/RegisterTransfer',
    );
  });

  test('isConfigured is false when username or key is missing', () {
    const empty = AppSettings(afm: '123456789');
    expect(AadeClient(settings: empty).isConfigured, isFalse);
  });

  test('testConnection skips the network when credentials are missing', () async {
    final client = AadeClient(settings: const AppSettings(afm: '123456789'));
    final result = await client.testConnection();
    expect(result.ok, isFalse);
    expect(result.message, contains('Username'));
    expect(result.statusCode, isNull);
  });

  test('testConnection treats HTTP 401 as failed authentication', () async {
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.host, 'mydataapidev.aade.gr');
        expect(request.url.path, endsWith('/GetDeliveryNoteStatus'));
        expect(request.headers[AadeHeaders.userId], 'user01');
        expect(request.headers[AadeHeaders.subscriptionKey], 'sub-key-1');
        return http.Response('Aade-user-id header is missing', 401);
      }),
    );

    final result = await client.testConnection();
    expect(result.ok, isFalse);
    expect(result.statusCode, 401);
  });

  test('testConnection treats HTTP 200 business XML as successful auth', () async {
    const xml = '''
<DeliveryNoteStatusResponse>
  <statusCode>ValidationError</statusCode>
  <errors>
    <error>
      <code>800</code>
      <message>Unknown mark</message>
    </error>
  </errors>
</DeliveryNoteStatusResponse>
''';
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((_) async => http.Response(xml, 200)),
    );

    final result = await client.testConnection();
    expect(result.ok, isTrue);
    expect(result.statusCode, 200);
    expect(result.message, contains('ταυτοποίηση πέτυχε'));
    expect(result.message, contains('Unknown mark'));
  });
}
