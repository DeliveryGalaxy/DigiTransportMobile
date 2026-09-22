import 'delivery.dart';

class ScanAction {
  const ScanAction({required this.id, required this.label});

  final String id;
  final String label;

  factory ScanAction.fromJson(Map<String, dynamic> json) {
    return ScanAction(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class DeliveryEvent {
  const DeliveryEvent({
    required this.eventType,
    required this.eventTypeLabel,
    this.eventTimestamp,
    this.actorVat,
    this.mark,
    this.vehicleNumber,
    this.outcome,
    this.reason,
  });

  final String eventType;
  final String eventTypeLabel;
  final String? eventTimestamp;
  final String? actorVat;
  final String? mark;
  final String? vehicleNumber;
  final String? outcome;
  final String? reason;

  factory DeliveryEvent.fromJson(Map<String, dynamic> json) {
    return DeliveryEvent(
      eventType: json['eventType'] as String? ?? '',
      eventTypeLabel: json['eventTypeLabel'] as String? ?? '',
      eventTimestamp: json['eventTimestamp'] as String?,
      actorVat: json['actorVat'] as String?,
      mark: json['mark'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      outcome: json['outcome'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.qrUrl,
    required this.action,
    required this.scannedAt,
    this.status = DeliveryStatus.unknown,
    this.invoiceMark,
    this.dispatchTimestamp,
    this.vehicleNumber,
    this.transportType,
    this.trailerNumber,
    this.vehicleFromDocument = false,
    this.lastAction,
    this.lastMessage,
    this.actions = const [],
  });

  final String id;
  final String qrUrl;
  final QrFlowAction action;
  final DateTime scannedAt;
  final DeliveryStatus status;
  final String? invoiceMark;
  final String? dispatchTimestamp;
  final String? vehicleNumber;
  final TransportType? transportType;
  final String? trailerNumber;
  final bool vehicleFromDocument;
  final String? lastAction;
  final String? lastMessage;
  final List<ScanAction> actions;

  String get title {
    if (invoiceMark != null && invoiceMark!.isNotEmpty) {
      return 'ΜΑΡΚ $invoiceMark';
    }
    return action.title;
  }

  String get scannedAtLabel => formatLocalDateTime(scannedAt);

  ScanRecord copyWith({
    DeliveryStatus? status,
    String? invoiceMark,
    String? dispatchTimestamp,
    String? vehicleNumber,
    TransportType? transportType,
    String? trailerNumber,
    bool? vehicleFromDocument,
    String? lastAction,
    String? lastMessage,
    List<ScanAction>? actions,
  }) {
    return ScanRecord(
      id: id,
      qrUrl: qrUrl,
      action: action,
      scannedAt: scannedAt,
      status: status ?? this.status,
      invoiceMark: invoiceMark ?? this.invoiceMark,
      dispatchTimestamp: dispatchTimestamp ?? this.dispatchTimestamp,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      transportType: transportType ?? this.transportType,
      trailerNumber: trailerNumber ?? this.trailerNumber,
      vehicleFromDocument: vehicleFromDocument ?? this.vehicleFromDocument,
      lastAction: lastAction ?? this.lastAction,
      lastMessage: lastMessage ?? this.lastMessage,
      actions: actions ?? this.actions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'qrUrl': qrUrl,
      'action': action.name,
      'scannedAt': scannedAt.toIso8601String(),
      'status': status.apiName,
      'invoiceMark': invoiceMark,
      'dispatchTimestamp': dispatchTimestamp,
      'vehicleNumber': vehicleNumber,
      'transportType': transportType?.code,
      'trailerNumber': trailerNumber,
      'vehicleFromDocument': vehicleFromDocument,
      'lastAction': lastAction,
      'lastMessage': lastMessage,
    };
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      id: json['id'] as String? ?? '',
      qrUrl: json['qrUrl'] as String? ?? '',
      action: QrFlowAction.values.firstWhere(
        (value) => value.name == json['action'],
        orElse: () => QrFlowAction.startRoute,
      ),
      scannedAt:
          DateTime.tryParse(json['scannedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: DeliveryStatus.parse(json['status'] as String?),
      invoiceMark: json['invoiceMark'] as String?,
      dispatchTimestamp: json['dispatchTimestamp'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      transportType: json['transportType'] is int
          ? TransportType.fromCode(json['transportType'] as int)
          : null,
      trailerNumber: json['trailerNumber'] as String?,
      vehicleFromDocument: json['vehicleFromDocument'] == true,
      lastAction: json['lastAction'] as String?,
      lastMessage: json['lastMessage'] as String?,
      actions: (json['actions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ScanAction.fromJson)
          .toList(),
    );
  }
}

String formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
