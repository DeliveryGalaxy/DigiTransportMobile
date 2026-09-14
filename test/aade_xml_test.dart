import 'package:digi_transport/models/delivery.dart';
import 'package:digi_transport/services/aade_xml.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractQrUrl keeps a bare URL and strips surrounding text', () {
    const url =
        'https://beta-epsilondigital.epsilonnet.gr/fd/d16134dbe38e49e8709308def398fa17:6';
    expect(extractQrUrl(url), url);
    expect(extractQrUrl('QR $url extra'), url);
  });

  test('builds RegisterTransfer XML from AADE schema', () {
    final xml = buildRegisterTransferXml(
      qrUrl: 'https://example.com/fd/abc:6',
      vehicleNumber: 'AHN0011',
      transportType: 2,
      carrierVatNumber: '123456789',
      trailerNumber: 'P22345',
    );

    expect(xml, contains('<Transport>'));
    expect(xml, contains('<qrUrl>https://example.com/fd/abc:6</qrUrl>'));
    expect(xml, contains('<vehicleNumber>AHN0011</vehicleNumber>'));
    expect(xml, contains('<transportType>2</transportType>'));
    expect(xml, contains('<carrierVatNumber>123456789</carrierVatNumber>'));
    expect(xml, contains('<pNumber>P22345</pNumber>'));
  });

  test('escapes QR URLs in XML', () {
    final xml = buildConfirmDeliveryOutcomeXml(
      qrUrl: 'https://x.test/?q=a&b=<c>',
      outcome: 'FULL',
    );
    expect(xml, contains('https://x.test/?q=a&amp;b=&lt;c&gt;'));
    expect(xml, contains('<outcome>FULL</outcome>'));
  });

  test('parses namespaced invoiceHeader vehicleNumber for a MARK', () {
    const xml = '''
<RequestedDoc xmlns:inv="http://www.aade.gr/myDATA/invoice/v1.0">
  <invoices>
    <inv:invoice>
      <inv:invoiceHeader>
        <inv:vehicleNumber>IYY1234</inv:vehicleNumber>
      </inv:invoiceHeader>
      <mark>400001234567890</mark>
    </inv:invoice>
  </invoices>
</RequestedDoc>
''';
    expect(
      extractVehicleNumberForMark(xml, '400001234567890'),
      'IYY1234',
    );
    expect(lastVehicleNumber(xml), 'IYY1234');
  });

  test('parses last lifecycle vehicleNumber from delivery status XML', () {
    const xml = '''
<GetDeliveryNoteStatusResponse>
  <invoiceMark>111</invoiceMark>
  <status>IN_TRANSIT</status>
  <lifecycleHistory>
    <transportDetails>
      <vehicleNumber>AHN0011</vehicleNumber>
      <transportType>2</transportType>
    </transportDetails>
  </lifecycleHistory>
</GetDeliveryNoteStatusResponse>
''';
    expect(lastVehicleNumber(xml), 'AHN0011');
    expect(lastTransportTypeCode(xml), 2);
  });
}
