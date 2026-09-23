import 'package:digi_transport/services/plate_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('greek lookalikes become the latin plate', () {
    expect(normalizePlate('ΙΚΕ1234'), 'IKE1234');
    expect(normalizePlate('ικε 1234'), 'IKE 1234');
    expect(normalizePlate('АВЕ123'), 'ABE123');
  });
}