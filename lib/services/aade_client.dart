import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import '../models/delivery.dart';
import 'aade_xml.dart';
import 'settings_store.dart';

export '../models/app_settings.dart' show AadeEnvironment;
export '../models/delivery.dart';
export 'aade_xml.dart' show extractQrUrl, extractVehicleNumberForMark;

/// Official AADE method paths (no leading slash).
abstract final class AadePaths {
  static const registerTransfer = 'RegisterTransfer';
  static const confirmDeliveryOutcome = 'ConfirmDeliveryOutcome';
  static const rejectDeliveryNote = 'RejectDeliveryNote';
  static const getDeliveryNoteStatus = 'GetDeliveryNoteStatus';
  static const generateGroupQRCode = 'GenerateGroupQRCode';
  static const requestGroupQRDetails = 'RequestGroupQRDetails';
  static const requestDocs = 'RequestDocs';
  static const requestTransmittedDocs = 'RequestTransmittedDocs';
}

/// Header names required by AADE myDATA (section 3.1.1).
abstract final class AadeHeaders {
  static const userId = 'aade-user-id';
  static const subscriptionKey = 'ocp-apim-subscription-key';
}

class AadeConnectionResult {
  const AadeConnectionResult({
    required this.ok,
    required this.message,
    this.statusCode,
    this.endpoint,
    this.body,
  });

  /// True when AADE answered and the credentials were accepted (not HTTP 401/403).
  final bool ok;
  final String message;
  final int? statusCode;
  final String? endpoint;
  final String? body;
}

/// Prepares AADE myDATA auth headers and endpoint URIs.
///
/// Username → `aade-user-id`, subscription key → `ocp-apim-subscription-key`.
class AadeClient {
  AadeClient({
    required this.settings,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final AppSettings settings;
  final http.Client? _httpClient;

  AadeEnvironment get environment => settings.environment;

  static const _timeout = Duration(seconds: 20);
  static const _probeMark = '1';

  static Future<AadeClient> fromStore({
    SettingsStore? store,
    http.Client? httpClient,
  }) async {
    final loaded = await (store ?? SettingsStore()).load();
    return AadeClient(
      settings: loaded,
      httpClient: httpClient,
    );
  }

  Uri get baseUri => Uri.parse(environment.baseUrl);

  /// True when the two headers AADE requires for authentication are present.
  /// AFM is stored locally but is not part of the auth headers.
  bool get isConfigured =>
      settings.username.trim().isNotEmpty &&
      settings.subscriptionKey.trim().isNotEmpty;

  /// AFM from settings. AADE resolves AFM from the registered user; keep
  /// this for methods that later need `issuerVatNumber` / entity VAT.
  String get entityVatNumber => settings.afm.trim();

  Map<String, String> get authHeaders {
    return {
      AadeHeaders.userId: settings.username.trim(),
      AadeHeaders.subscriptionKey: settings.subscriptionKey.trim(),
    };
  }

  Map<String, String> get headers {
    return {
      ...authHeaders,
      'Content-Type': 'application/xml',
      'Accept': 'application/xml',
    };
  }

  Uri uriFor(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${environment.baseUrl}/$path');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  Uri registerTransferUri() => uriFor(AadePaths.registerTransfer);

  Uri confirmDeliveryOutcomeUri() => uriFor(AadePaths.confirmDeliveryOutcome);

  Uri rejectDeliveryNoteUri() => uriFor(AadePaths.rejectDeliveryNote);

  Uri getDeliveryNoteStatusUri({
    String? mark,
    String? qrUrl,
    String? issuerVatNumber,
  }) {
    return uriFor(AadePaths.getDeliveryNoteStatus, {
      if (mark != null && mark.isNotEmpty) 'mark': mark,
      if (qrUrl != null && qrUrl.isNotEmpty) 'qrUrl': qrUrl,
      if (issuerVatNumber != null && issuerVatNumber.isNotEmpty)
        'issuerVatNumber': issuerVatNumber,
    });
  }

  Uri generateGroupQRCodeUri() => uriFor(AadePaths.generateGroupQRCode);

  Uri requestGroupQRDetailsUri({required String groupId}) {
    return uriFor(AadePaths.requestGroupQRDetails, {'groupId': groupId});
  }

  /// GET [GetDeliveryNoteStatus] with a dummy MARK to verify credentials.
  ///
  /// HTTP 401/403 means the username/key were rejected. HTTP 200 with a
  /// business XML error (e.g. unknown MARK) still means authentication worked.
  Future<AadeConnectionResult> testConnection() async {
    if (!isConfigured) {
      return const AadeConnectionResult(
        ok: false,
        message: 'Συμπλήρωσε Username και Subscription Key.',
      );
    }

    final endpoint = getDeliveryNoteStatusUri(
      mark: _probeMark,
      issuerVatNumber: entityVatNumber.isEmpty ? null : entityVatNumber,
    );
    final response = await _get(endpoint);
    if (response is _NetworkFailure) {
      return AadeConnectionResult(
        ok: false,
        message: response.message,
        endpoint: endpoint.toString(),
      );
    }
    return _resultFromResponse(response as http.Response, endpoint);
  }

  Future<AadeSubmitResult> getDeliveryNoteStatus({
    required String qrUrl,
  }) async {
    if (!isConfigured) {
      return const AadeSubmitResult(
        ok: false,
        message: 'Συμπλήρωσε Username και Subscription Key στις ρυθμίσεις.',
      );
    }

    final endpoint = getDeliveryNoteStatusUri(qrUrl: qrUrl);
    final response = await _get(endpoint);
    if (response is _NetworkFailure) {
      return AadeSubmitResult(ok: false, message: response.message);
    }
    return _statusFromResponse(response as http.Response);
  }

  /// Loads the original invoice XML (issuer first, then recipient).
  ///
  /// `RequestTransmittedDocs` / `RequestDocs` return documents with MARK
  /// greater than the given `mark`, so we query `invoiceMark - 1`.
  Future<String?> fetchInvoiceXml({required String invoiceMark}) async {
    if (!isConfigured || invoiceMark.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(invoiceMark.trim());
    final minMark = parsed == null || parsed <= 0 ? '0' : '${parsed - 1}';
    for (final path in [
      AadePaths.requestTransmittedDocs,
      AadePaths.requestDocs,
    ]) {
      final endpoint = uriFor(path, {
        'mark': minMark,
        'maxMark': invoiceMark.trim(),
      });
      final response = await _get(endpoint);
      if (response is! http.Response) {
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }
      final body = response.body.trim();
      if (body.isEmpty) {
        continue;
      }
      final looksLikeInvoice = RegExp(
        '<(?:\\w+:)?invoiceHeader',
        caseSensitive: false,
      ).hasMatch(body);
      if (looksLikeInvoice ||
          extractVehicleNumberForMark(body, invoiceMark.trim()) != null) {
        return body;
      }
    }
    return null;
  }

  Future<AadeSubmitResult> registerTransfer({
    required String qrUrl,
    required TransportDetails details,
  }) async {
    final xml = buildRegisterTransferXml(
      qrUrl: qrUrl,
      vehicleNumber: details.vehicleNumber,
      transportType: details.transportType.code,
      carrierVatNumber: details.carrierVatNumber,
      trailerNumber: details.trailerNumber,
    );
    return _postXml(
      registerTransferUri(),
      xml,
      markTag: 'transferMark',
      successMessage: 'Η διακίνηση καταχωρήθηκε.',
    );
  }

  Future<AadeSubmitResult> confirmDeliveryOutcome({
    required String qrUrl,
    required DeliveryOutcome outcome,
    bool? deliveredWithoutRecipient,
    int? packagingType,
    int? packagingQuantity,
  }) async {
    final xml = buildConfirmDeliveryOutcomeXml(
      qrUrl: qrUrl,
      outcome: outcome.apiValue,
      deliveredWithoutRecipient: deliveredWithoutRecipient,
      packagingType: packagingType,
      packagingQuantity: packagingQuantity,
    );
    return _postXml(
      confirmDeliveryOutcomeUri(),
      xml,
      markTag: 'deliveryOutcomeMark',
      successMessage: 'Η παράδοση καταχωρήθηκε.',
    );
  }

  Future<AadeSubmitResult> rejectDeliveryNote({
    required String qrUrl,
    String? reason,
  }) async {
    final xml = buildRejectDeliveryNoteXml(qrUrl: qrUrl, reason: reason);
    return _postXml(
      rejectDeliveryNoteUri(),
      xml,
      markTag: 'rejectMark',
      successMessage: 'Η παραλαβή απορρίφθηκε.',
    );
  }

  Future<AadeSubmitResult> _postXml(
    Uri endpoint,
    String xml, {
    required String markTag,
    required String successMessage,
  }) async {
    if (!isConfigured) {
      return const AadeSubmitResult(
        ok: false,
        message: 'Συμπλήρωσε Username και Subscription Key στις ρυθμίσεις.',
      );
    }

    final response = await _send(
      (client) => client.post(endpoint, headers: headers, body: xml),
    );
    if (response is _NetworkFailure) {
      return AadeSubmitResult(ok: false, message: response.message);
    }
    return _submitFromResponse(
      response as http.Response,
      markTag: markTag,
      successMessage: successMessage,
    );
  }

  Future<Object> _get(Uri endpoint) {
    return _send(
      (client) => client.get(
        endpoint,
        headers: {...authHeaders, 'Accept': 'application/xml'},
      ),
    );
  }

  Future<Object> _send(
    Future<http.Response> Function(http.Client client) send,
  ) async {
    final client = _httpClient ?? http.Client();
    final ownsClient = _httpClient == null;
    try {
      return await send(client).timeout(_timeout);
    } on TimeoutException {
      return const _NetworkFailure('Η ΑΑΔΕ δεν απάντησε εγκαίρως.');
    } on http.ClientException catch (error) {
      return _NetworkFailure('Σφάλμα δικτύου: ${error.message}');
    } catch (error) {
      return _NetworkFailure('Σφάλμα δικτύου: $error');
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  AadeSubmitResult _statusFromResponse(http.Response response) {
    final body = response.body.trim();
    if (response.statusCode == 401 || response.statusCode == 403) {
      return AadeSubmitResult(
        ok: false,
        message:
            xmlTag(body, 'message') ??
            'Η ΑΑΔΕ απέρριψε τα credentials (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        body: body,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return AadeSubmitResult(
        ok: false,
        message:
            xmlErrorMessage(body) ?? 'Σφάλμα ΑΑΔΕ (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        body: body,
      );
    }

    final statusValue = xmlTag(body, 'status');
    if (statusValue != null && statusValue.isNotEmpty) {
      return AadeSubmitResult(
        ok: true,
        message: DeliveryStatus.parse(statusValue).label,
        statusCode: response.statusCode,
        mark: xmlTag(body, 'invoiceMark'),
        body: body,
      );
    }

    return AadeSubmitResult(
      ok: false,
      message: xmlErrorMessage(body) ?? 'Δεν βρέθηκε κατάσταση δελτίου.',
      statusCode: response.statusCode,
      body: body,
    );
  }

  AadeSubmitResult _submitFromResponse(
    http.Response response, {
    required String markTag,
    required String successMessage,
  }) {
    final body = response.body.trim();
    if (response.statusCode == 401 || response.statusCode == 403) {
      return AadeSubmitResult(
        ok: false,
        message:
            xmlTag(body, 'message') ??
            'Η ΑΑΔΕ απέρριψε τα credentials (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        body: body,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return AadeSubmitResult(
        ok: false,
        message:
            xmlErrorMessage(body) ?? 'Σφάλμα ΑΑΔΕ (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        body: body,
      );
    }

    if (xmlIsSuccess(body)) {
      return AadeSubmitResult(
        ok: true,
        message: successMessage,
        statusCode: response.statusCode,
        mark: xmlTag(body, markTag),
        body: body,
      );
    }

    return AadeSubmitResult(
      ok: false,
      message: xmlErrorMessage(body) ?? 'Η ΑΑΔΕ απέρριψε την υποβολή.',
      statusCode: response.statusCode,
      body: body,
    );
  }

  DeliveryNoteStatus? parseStatusXml(String? xml) {
    if (xml == null || xml.trim().isEmpty) {
      return null;
    }
    final statusValue = xmlTag(xml, 'status');
    if (statusValue == null || statusValue.isEmpty) {
      return null;
    }
    final typeCode = lastTransportTypeCode(xml);
    return DeliveryNoteStatus(
      status: DeliveryStatus.parse(statusValue),
      invoiceMark: xmlTag(xml, 'invoiceMark'),
      dispatchTimestamp: xmlTag(xml, 'dispatchTimestamp'),
      vehicleNumber: lastVehicleNumber(xml),
      transportType: typeCode == null ? null : TransportType.fromCode(typeCode),
      trailerNumber: lastTrailerNumber(xml),
      rawXml: xml,
    );
  }

  AadeConnectionResult _resultFromResponse(
    http.Response response,
    Uri endpoint,
  ) {
    final body = response.body.trim();
    final xmlMessage = xmlTag(body, 'message');
    final xmlCode = xmlTag(body, 'code') ?? xmlTag(body, 'statusCode');

    if (response.statusCode == 401 || response.statusCode == 403) {
      return AadeConnectionResult(
        ok: false,
        message:
            xmlMessage ??
            'Η ΑΑΔΕ απέρριψε τα credentials (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        endpoint: endpoint.toString(),
        body: _truncate(body),
      );
    }

    final detail = [
      'HTTP ${response.statusCode}',
      if (xmlCode != null && xmlCode.isNotEmpty) 'status: $xmlCode',
      if (xmlMessage != null && xmlMessage.isNotEmpty) xmlMessage,
    ].join('\n');

    return AadeConnectionResult(
      ok: true,
      message: 'Η ΑΑΔΕ απάντησε. Η ταυτοποίηση πέτυχε.\n$detail',
      statusCode: response.statusCode,
      endpoint: endpoint.toString(),
      body: _truncate(body),
    );
  }

  static String? _truncate(String body) {
    if (body.isEmpty) {
      return null;
    }
    if (body.length <= 800) {
      return body;
    }
    return '${body.substring(0, 800)}…';
  }
}

class _NetworkFailure {
  const _NetworkFailure(this.message);

  final String message;
}
