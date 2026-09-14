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
    expect(
      dev
          .getDeliveryNoteStatusUri(
            qrUrl:
                'https://beta-epsilondigital.epsilonnet.gr/fd/d16134dbe38e49e8709308def398fa17:6',
          )
          .toString(),
      'https://mydataapidev.aade.gr/GetDeliveryNoteStatus?qrUrl=https%3A%2F%2Fbeta-epsilondigital.epsilonnet.gr%2Ffd%2Fd16134dbe38e49e8709308def398fa17%3A6',
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

  test('getDeliveryNoteStatus reads qrUrl and parses REGISTERED', () async {
    const xml = '''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111111111111111</invoiceMark>
  <status>REGISTERED</status>
</GetDeliveryNoteStatusResponse>
''';
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['qrUrl'], 'https://example.com/fd/x');
        return http.Response(xml, 200);
      }),
    );

    final result = await client.getDeliveryNoteStatus(
      qrUrl: 'https://example.com/fd/x',
    );
    expect(result.ok, isTrue);
    expect(result.mark, '111111111111111');
    expect(client.parseStatusXml(result.body)?.status, DeliveryStatus.registered);
  });

  test('registerTransfer posts Transport XML and reads transferMark', () async {
    const responseXml = '''
<ResponseDoc>
  <response>
    <transferMark>222222222222222</transferMark>
    <statusCode>Success</statusCode>
  </response>
</ResponseDoc>
''';
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/RegisterTransfer'));
        expect(request.body, contains('<qrUrl>https://example.com/fd/x</qrUrl>'));
        expect(request.body, contains('<vehicleNumber>AHN0011</vehicleNumber>'));
        return http.Response(responseXml, 200);
      }),
    );

    final result = await client.registerTransfer(
      qrUrl: 'https://example.com/fd/x',
      details: const TransportDetails(
        vehicleNumber: 'AHN0011',
        transportType: TransportType.privateTruck,
        carrierVatNumber: '123456789',
      ),
    );
    expect(result.ok, isTrue);
    expect(result.mark, '222222222222222');
  });

  test('confirmDeliveryOutcome posts FULL outcome XML', () async {
    const responseXml = '''
<ResponseDoc>
  <response>
    <deliveryOutcomeMark>333</deliveryOutcomeMark>
    <statusCode>Success</statusCode>
  </response>
</ResponseDoc>
''';
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/ConfirmDeliveryOutcome'));
        expect(request.body, contains('<outcome>FULL</outcome>'));
        return http.Response(responseXml, 200);
      }),
    );

    final result = await client.confirmDeliveryOutcome(
      qrUrl: 'https://example.com/fd/x',
      outcome: DeliveryOutcome.full,
    );
    expect(result.ok, isTrue);
    expect(result.mark, '333');
  });

  test('rejectDeliveryNote posts qrUrl and optional reason', () async {
    const responseXml = '''
<ResponseDoc>
  <response>
    <rejectMark>444</rejectMark>
    <statusCode>Success</statusCode>
  </response>
</ResponseDoc>
''';
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/RejectDeliveryNote'));
        expect(request.body, contains('<rejectionReason>Damaged</rejectionReason>'));
        return http.Response(responseXml, 200);
      }),
    );

    final result = await client.rejectDeliveryNote(
      qrUrl: 'https://example.com/fd/x',
      reason: 'Damaged',
    );
    expect(result.ok, isTrue);
    expect(result.mark, '444');
  });

  test('parseStatusXml reads vehicle from lifecycle history', () {
    const xml = '''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111111111111111</invoiceMark>
  <status>IN_TRANSIT</status>
  <lifecycleHistory>
    <transportDetails>
      <vehicleNumber>AHN0011</vehicleNumber>
      <transportType>2</transportType>
      <pNumber>P22345</pNumber>
    </transportDetails>
  </lifecycleHistory>
</GetDeliveryNoteStatusResponse>
''';
    final parsed = AadeClient(settings: settings).parseStatusXml(xml);
    expect(parsed?.vehicleNumber, 'AHN0011');
    expect(parsed?.transportType, TransportType.privateTruck);
    expect(parsed?.trailerNumber, 'P22345');
  });

  test('fetchInvoiceXml asks transmitted docs then recipient docs', () async {
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
    final paths = <String>[];
    final client = AadeClient(
      settings: settings,
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.queryParameters['mark'], '111111111111110');
        expect(request.url.queryParameters['maxMark'], '111111111111111');
        if (request.url.path.endsWith('/RequestTransmittedDocs')) {
          return http.Response('<RequestedDoc/>', 200);
        }
        return http.Response(invoiceXml, 200);
      }),
    );

    final xml = await client.fetchInvoiceXml(invoiceMark: '111111111111111');
    expect(paths.last, endsWith('/RequestDocs'));
    expect(extractVehicleNumberForMark(xml!, '111111111111111'), 'IYY1234');
  });
}
