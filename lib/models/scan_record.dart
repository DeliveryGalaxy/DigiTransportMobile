import 'delivery.dart';

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
    this.lastAction,
    this.lastMessage,
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
  final String? lastAction;
  final String? lastMessage;

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
    String? lastAction,
    String? lastMessage,
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
      lastAction: lastAction ?? this.lastAction,
      lastMessage: lastMessage ?? this.lastMessage,
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
      lastAction: json['lastAction'] as String?,
      lastMessage: json['lastMessage'] as String?,
    );
  }
}

String formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
