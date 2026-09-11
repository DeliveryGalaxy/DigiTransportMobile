import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import 'settings_store.dart';

export '../models/app_settings.dart' show AadeEnvironment;

/// Official AADE method paths (no leading slash).
abstract final class AadePaths {
  static const registerTransfer = 'RegisterTransfer';
  static const confirmDeliveryOutcome = 'ConfirmDeliveryOutcome';
  static const rejectDeliveryNote = 'RejectDeliveryNote';
  static const getDeliveryNoteStatus = 'GetDeliveryNoteStatus';
  static const generateGroupQRCode = 'GenerateGroupQRCode';
  static const requestGroupQRDetails = 'RequestGroupQRDetails';
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
    required String mark,
    String? issuerVatNumber,
  }) {
    return uriFor(AadePaths.getDeliveryNoteStatus, {
      'mark': mark,
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
    final client = _httpClient ?? http.Client();
    final ownsClient = _httpClient == null;

    try {
      final response = await client
          .get(
            endpoint,
            headers: {...authHeaders, 'Accept': 'application/xml'},
          )
          .timeout(_timeout);
      return _resultFromResponse(response, endpoint);
    } on TimeoutException {
      return AadeConnectionResult(
        ok: false,
        message: 'Η ΑΑΔΕ δεν απάντησε εγκαίρως.',
        endpoint: endpoint.toString(),
      );
    } on http.ClientException catch (error) {
      return AadeConnectionResult(
        ok: false,
        message: 'Σφάλμα δικτύου: ${error.message}',
        endpoint: endpoint.toString(),
      );
    } catch (error) {
      return AadeConnectionResult(
        ok: false,
        message: 'Σφάλμα δικτύου: $error',
        endpoint: endpoint.toString(),
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  AadeConnectionResult _resultFromResponse(http.Response response, Uri endpoint) {
    final body = response.body.trim();
    final xmlMessage = _xmlTag(body, 'message');
    final xmlCode = _xmlTag(body, 'code') ?? _xmlTag(body, 'statusCode');

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

  static String? _xmlTag(String body, String tag) {
    final match = RegExp(
      '<$tag[^>]*>([^<]*)</$tag>',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.trim();
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
