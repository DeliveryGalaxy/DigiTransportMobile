import 'package:digi_transport/models/delivery.dart';
import 'package:digi_transport/models/scan_record.dart';
import 'package:digi_transport/services/digi_api.dart';

class FakeDigiApi extends DigiApi {
  FakeDigiApi({
    List<ScanRecord>? scans,
    this.openResult,
    this.refreshed,
  }) : scans = [...?scans],
       super(baseUrl: 'http://test.local', token: 'token', companyAfm: '123456789');

  List<ScanRecord> scans;
  OpenScanResult? openResult;
  ScanRecord? refreshed;

  @override
  Future<List<ScanRecord>> listScans() async => scans;

  @override
  Future<OpenScanResult> openScan({
    required String qrUrl,
    required QrFlowAction action,
  }) async {
    return openResult!;
  }

  @override
  Future<ScanRecord> refreshScan(String id) async {
    return refreshed ?? scans.firstWhere((scan) => scan.id == id);
  }

  @override
  Future<void> deleteScan(String id) async {
    scans = scans.where((scan) => scan.id != id).toList();
  }

  @override
  Future<List<DeliveryEvent>> history(String id) async => const [];
}
