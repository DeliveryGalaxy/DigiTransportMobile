import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import '../models/delivery.dart';
import '../models/scan_record.dart';
import 'settings_store.dart';

class OpenScanResult {
  const OpenScanResult({required this.scan, required this.existed});

  final ScanRecord scan;
  final bool existed;
}

class DigiApiException implements Exception {
  const DigiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DigiApi {
  DigiApi({
    required this.baseUrl,
    this.token = '',
    this.companyAfm = '',
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final String baseUrl;
  final String token;
  final String companyAfm;
  final http.Client? _httpClient;

  bool get isLoggedIn => token.trim().isNotEmpty;

  static Future<DigiApi> fromStore({
    SettingsStore? store,
    http.Client? httpClient,
  }) async {
    final settings = await (store ?? SettingsStore()).load();
    return DigiApi(
      baseUrl: digiApiBaseUrl,
      token: settings.token,
      companyAfm: settings.companyAfm,
      httpClient: httpClient,
    );
  }

  Future<CompanyDetails> lookupCompany(String afm) async {
    final body = await _send(
      'POST',
      '/companies/lookup',
      body: {'afm': afm},
      authenticated: false,
    );
    return CompanyDetails.fromJson(
      Map<String, dynamic>.from(body['company'] as Map),
    );
  }

  Future<VerifyIdentityResult> verifyIdentity({
    required int companyId,
    required String userId,
    required String pin,
  }) async {
    final body = await _send(
      'POST',
      '/companies/$companyId/verify',
      body: {'userId': userId, 'pin': pin},
      authenticated: false,
    );
    return VerifyIdentityResult(
      token: body['token'] as String? ?? '',
      userId: body['userId'] as String? ?? userId,
      company: CompanyDetails.fromJson(
        Map<String, dynamic>.from(body['company'] as Map),
      ),
    );
  }

  Future<AppSession> login({
    required String username,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
      authenticated: false,
    );
    return AppSession(
      token: body['token'] as String? ?? '',
      username: (body['user'] as Map?)?['username'] as String? ?? username,
      companyName: (body['company'] as Map?)?['name'] as String? ?? '',
      companyAfm: (body['company'] as Map?)?['afm'] as String? ?? '',
      isMetaforeas: (body['company'] as Map?)?['isMetaforeas'] != false,
    );
  }

  Future<String> testAade() async {
    final body = await _send('POST', '/auth/aade-test');
    return body['message'] as String? ?? 'Η ΑΑΔΕ απάντησε.';
  }

  Future<List<ScanRecord>> listScans() async {
    final body = await _send('GET', '/scans');
    final scans = body['scans'] as List<dynamic>? ?? [];
    return scans
        .map((item) => ScanRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<OpenScanResult> openScan({
    required String qrUrl,
    required QrFlowAction action,
  }) async {
    final body = await _send('POST', '/scans', body: {
      'qrUrl': qrUrl,
      'action': action.name,
    });
    return OpenScanResult(
      scan: ScanRecord.fromJson(Map<String, dynamic>.from(body['scan'] as Map)),
      existed: body['existed'] == true,
    );
  }

  Future<ScanRecord> refreshScan(String id) async {
    final body = await _send('GET', '/scans/$id');
    return ScanRecord.fromJson(Map<String, dynamic>.from(body['scan'] as Map));
  }

  Future<List<DeliveryEvent>> history(String id) async {
    final body = await _send('GET', '/scans/$id/history');
    final events = body['events'] as List<dynamic>? ?? [];
    return events
        .map((item) => DeliveryEvent.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> deleteScan(String id) async {
    await _send('DELETE', '/scans/$id');
  }

  Future<ScanRecord> registerTransfer({
    required String id,
    required String vehicleNumber,
    required int transportType,
    String? trailerNumber,
  }) async {
    final body = await _send('POST', '/scans/$id/transfer', body: {
      'vehicleNumber': vehicleNumber,
      'transportType': transportType,
      'trailerNumber': trailerNumber,
    });
    return _scanFromSubmit(body);
  }

  Future<ScanRecord> confirmOutcome({
    required String id,
    required String outcome,
    int? packagingType,
    int? packagingQuantity,
  }) async {
    final body = await _send('POST', '/scans/$id/outcome', body: {
      'outcome': outcome,
      'packagingType': packagingType,
      'packagingQuantity': packagingQuantity,
    });
    return _scanFromSubmit(body);
  }

  Future<ScanRecord> rejectDelivery({
    required String id,
    String? reason,
  }) async {
    final body = await _send('POST', '/scans/$id/reject', body: {
      'reason': reason,
    });
    return _scanFromSubmit(body);
  }

  ScanRecord _scanFromSubmit(Map<String, dynamic> body) {
    if (body['ok'] == false) {
      throw DigiApiException(body['message'] as String? ?? 'Η υποβολή απέτυχε.');
    }
    return ScanRecord.fromJson(Map<String, dynamic>.from(body['scan'] as Map));
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    if (authenticated && !isLoggedIn) {
      throw const DigiApiException('Συνδέσου από τις Ρυθμίσεις.');
    }
    final client = _httpClient ?? http.Client();
    final ownsClient = _httpClient == null;
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers['Accept'] = 'application/json';
      if (authenticated && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await client.send(request).timeout(const Duration(seconds: 25));
      final text = await response.stream.bytesToString();
      final decoded = text.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(text) as Map);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DigiApiException(
          decoded['message'] as String? ?? 'Σφάλμα διακομιστή (${response.statusCode}).',
        );
      }
      return decoded;
    } on DigiApiException {
      rethrow;
    } catch (error) {
      throw DigiApiException('Σφάλμα δικτύου: $error');
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}

class CompanyDetails {
  const CompanyDetails({
    required this.id,
    required this.name,
    required this.username,
    required this.afm,
    required this.subscriptionKey,
    required this.isMetaforiki,
    required this.isContainer,
    required this.isOther,
    required this.shouldDisplayPlated,
  });

  final int id;
  final String name;
  final String username;
  final String afm;
  final String subscriptionKey;
  final bool isMetaforiki;
  final bool isContainer;
  final bool isOther;
  final bool shouldDisplayPlated;

  factory CompanyDetails.fromJson(Map<String, dynamic> json) {
    return CompanyDetails(
      id: json['id'] as int? ?? int.tryParse('${json['id']}') ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      afm: json['afm'] as String? ?? '',
      subscriptionKey: json['subscriptionKey'] as String? ?? '',
      isMetaforiki: json['isMetaforiki'] == true,
      isContainer: json['isContainer'] == true,
      isOther: json['isOther'] == true,
      shouldDisplayPlated: json['shouldDisplayPlated'] == true,
    );
  }
}

class VerifyIdentityResult {
  const VerifyIdentityResult({
    required this.token,
    required this.userId,
    required this.company,
  });

  final String token;
  final String userId;
  final CompanyDetails company;
}

class AppSession {
  const AppSession({
    required this.token,
    required this.username,
    required this.companyName,
    required this.companyAfm,
    required this.isMetaforeas,
  });

  final String token;
  final String username;
  final String companyName;
  final String companyAfm;
  final bool isMetaforeas;
}
