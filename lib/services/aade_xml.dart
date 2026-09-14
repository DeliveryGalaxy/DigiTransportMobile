String xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String? xmlTag(String body, String tag) {
  final match = RegExp(
    '<(?:\\w+:)?$tag(?:\\s[^>]*)?>([^<]*)</(?:\\w+:)?$tag>',
    caseSensitive: false,
  ).firstMatch(body);
  return match?.group(1)?.trim();
}

List<String> xmlTags(String body, String tag) {
  return RegExp(
    '<(?:\\w+:)?$tag(?:\\s[^>]*)?>([^<]*)</(?:\\w+:)?$tag>',
    caseSensitive: false,
  ).allMatches(body).map((match) => match.group(1)!.trim()).toList();
}

String? extractInvoiceHeaderVehicleNumber(String xml) {
  final header = RegExp(
    '<(?:\\w+:)?invoiceHeader(?:\\s[^>]*)?>[\\s\\S]*?</(?:\\w+:)?invoiceHeader>',
    caseSensitive: false,
  ).firstMatch(xml);
  if (header == null) {
    return null;
  }
  final plate = xmlTag(header.group(0)!, 'vehicleNumber');
  if (plate == null || plate.isEmpty) {
    return null;
  }
  return plate;
}

String? extractVehicleNumberForMark(String xml, String mark) {
  final invoices = RegExp(
    '<(?:\\w+:)?invoice(?:\\s[^>]*)?>[\\s\\S]*?</(?:\\w+:)?invoice>',
    caseSensitive: false,
  ).allMatches(xml);
  for (final invoice in invoices) {
    final block = invoice.group(0)!;
    if (!block.contains(mark)) {
      continue;
    }
    return extractInvoiceHeaderVehicleNumber(block) ??
        _lastNonEmpty(xmlTags(block, 'vehicleNumber'));
  }
  return extractInvoiceHeaderVehicleNumber(xml) ??
      _lastNonEmpty(xmlTags(xml, 'vehicleNumber'));
}

String? lastVehicleNumber(String xml) {
  return _lastNonEmpty(xmlTags(xml, 'vehicleNumber'));
}

int? lastTransportTypeCode(String xml) {
  final raw = _lastNonEmpty(xmlTags(xml, 'transportType'));
  return raw == null ? null : int.tryParse(raw);
}

String? lastTrailerNumber(String xml) {
  return _lastNonEmpty(xmlTags(xml, 'pNumber'));
}

String? _lastNonEmpty(List<String> values) {
  for (final value in values.reversed) {
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? xmlErrorMessage(String body) {
  final messages = xmlTags(body, 'message');
  final codes = xmlTags(body, 'code');
  if (messages.isEmpty && codes.isEmpty) {
    return xmlTag(body, 'statusCode');
  }
  final parts = <String>[];
  for (var i = 0; i < messages.length; i++) {
    final code = i < codes.length && codes[i].isNotEmpty ? '${codes[i]}: ' : '';
    parts.add('$code${messages[i]}');
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join('\n');
}

bool xmlIsSuccess(String body) {
  final statusCode = xmlTag(body, 'statusCode');
  if (statusCode == null || statusCode.isEmpty) {
    return xmlTag(body, 'status') != null;
  }
  return statusCode.toLowerCase() == 'success';
}

String extractQrUrl(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return (match?.group(0) ?? trimmed).trim();
}

String buildRegisterTransferXml({
  required String qrUrl,
  required String vehicleNumber,
  required int transportType,
  required String carrierVatNumber,
  String? trailerNumber,
}) {
  final trailer = trailerNumber != null && trailerNumber.trim().isNotEmpty
      ? '        <pNumber>${xmlEscape(trailerNumber.trim())}</pNumber>\n'
      : '';
  return '''<?xml version="1.0" encoding="utf-8"?>
<Transport>
    <qrUrl>${xmlEscape(qrUrl)}</qrUrl>
    <transportDetail>
        <vehicleNumber>${xmlEscape(vehicleNumber.trim())}</vehicleNumber>
        <transportType>$transportType</transportType>
        <carrierVatNumber>${xmlEscape(carrierVatNumber.trim())}</carrierVatNumber>
$trailer    </transportDetail>
</Transport>
''';
}

String buildConfirmDeliveryOutcomeXml({
  required String qrUrl,
  required String outcome,
  bool? deliveredWithoutRecipient,
  int? packagingType,
  int? packagingQuantity,
}) {
  final extra = StringBuffer();
  if (deliveredWithoutRecipient != null) {
    extra.writeln(
      '    <deliveredWithoutRecipient>$deliveredWithoutRecipient</deliveredWithoutRecipient>',
    );
  }
  if (packagingType != null && packagingQuantity != null) {
    extra.writeln('    <deliveredPackaging>');
    extra.writeln('        <packagingType>$packagingType</packagingType>');
    extra.writeln('        <quantity>$packagingQuantity</quantity>');
    extra.writeln('    </deliveredPackaging>');
  }
  return '''<?xml version="1.0" encoding="utf-8"?>
<ConfirmDeliveryOutcomeRequest>
    <qrUrl>${xmlEscape(qrUrl)}</qrUrl>
    <outcome>${xmlEscape(outcome)}</outcome>
${extra.toString()}</ConfirmDeliveryOutcomeRequest>
''';
}

String buildRejectDeliveryNoteXml({
  required String qrUrl,
  String? reason,
}) {
  final reasonXml = reason != null && reason.trim().isNotEmpty
      ? '    <rejectionReason>${xmlEscape(reason.trim())}</rejectionReason>\n'
      : '';
  return '''<?xml version="1.0" encoding="utf-8"?>
<RejectDeliveryNoteRequest>
    <qrUrl>${xmlEscape(qrUrl)}</qrUrl>
$reasonXml</RejectDeliveryNoteRequest>
''';
}
