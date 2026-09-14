enum QrFlowAction {
  startRoute,
  receive;

  String get title => switch (this) {
    QrFlowAction.startRoute => 'Έναρξη Δρομολογίου',
    QrFlowAction.receive => 'Παραλαβή',
  };
}

/// AADE InvoiceDeliveryStatus (docs §7.1). Accepts numeric or named XML values.
enum DeliveryStatus {
  registered(1, 'REGISTERED', 'Εκδόθηκε'),
  cancelled(2, 'CANCELLED', 'Ακυρώθηκε'),
  inTransit(3, 'IN_TRANSIT', 'Σε διακίνηση'),
  rejected(4, 'REJECTED', 'Απορρίφθηκε'),
  deliveredByCarrier(5, 'DELIVERED_BY_CARRIER', 'Παραδόθηκε από μεταφορέα'),
  failedDelivery(7, 'FAILED_DELIVERY', 'Αποτυχία παράδοσης'),
  completed(8, 'COMPLETED', 'Ολοκληρώθηκε'),
  inTransitReturn(9, 'IN_TRANSIT_RETURN', 'Επιστροφή σε διακίνηση'),
  unknown(0, 'UNKNOWN', 'Άγνωστη κατάσταση');

  const DeliveryStatus(this.code, this.apiName, this.label);

  final int code;
  final String apiName;
  final String label;

  bool get isTerminal =>
      this == DeliveryStatus.completed ||
      this == DeliveryStatus.cancelled;

  static DeliveryStatus parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return DeliveryStatus.unknown;
    }
    final value = raw.trim();
    final asInt = int.tryParse(value);
    if (asInt != null) {
      return DeliveryStatus.values.firstWhere(
        (status) => status.code == asInt,
        orElse: () => DeliveryStatus.unknown,
      );
    }
    final normalized = value
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-()]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return switch (normalized) {
      'REGISTERED' || '1' => DeliveryStatus.registered,
      'CANCELLED' || 'CANCELED' || '2' => DeliveryStatus.cancelled,
      'IN_TRANSIT' || 'INTRANSIT' || '3' => DeliveryStatus.inTransit,
      'REJECTED' || '4' => DeliveryStatus.rejected,
      'DELIVERED_BY_CARRIER' ||
      'DELIVEREDBYCARRIER' ||
      '5' => DeliveryStatus.deliveredByCarrier,
      'FAILED_DELIVERY' ||
      'FAILEDDELIVERY' ||
      '7' => DeliveryStatus.failedDelivery,
      'COMPLETED' || '8' => DeliveryStatus.completed,
      'IN_TRANSIT_RETURN' ||
      'INTRANSIT_RETURN' ||
      'IN_TRANSITRETURN' ||
      '9' => DeliveryStatus.inTransitReturn,
      _ => DeliveryStatus.unknown,
    };
  }
}

enum TransportType {
  publicTruck(1, 'Φορτηγό Δημόσιας Χρήσης'),
  privateTruck(2, 'Φορτηγό Ιδιωτικής Χρήσης'),
  ship(3, 'Πλοίο'),
  train(4, 'Τρένο'),
  airplane(5, 'Αεροπλάνο'),
  other(6, 'Λοιπά Μεταφορικά Μέσα'),
  none(7, 'Άνευ');

  const TransportType(this.code, this.label);

  final int code;
  final String label;

  static TransportType fromCode(int? code) {
    return TransportType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TransportType.privateTruck,
    );
  }
}

enum DeliveryOutcome {
  full('FULL', 'Πλήρης παράδοση'),
  partial('PARTIAL', 'Μερική παράδοση'),
  none('NONE', 'Αποτυχία παράδοσης');

  const DeliveryOutcome(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class DeliveryNoteStatus {
  const DeliveryNoteStatus({
    required this.status,
    this.invoiceMark,
    this.dispatchTimestamp,
    this.vehicleNumber,
    this.transportType,
    this.trailerNumber,
    this.rawXml,
  });

  final DeliveryStatus status;
  final String? invoiceMark;
  final String? dispatchTimestamp;
  final String? vehicleNumber;
  final TransportType? transportType;
  final String? trailerNumber;
  final String? rawXml;
}

class TransportDetails {
  const TransportDetails({
    required this.vehicleNumber,
    required this.transportType,
    required this.carrierVatNumber,
    this.trailerNumber,
  });

  final String vehicleNumber;
  final TransportType transportType;
  final String carrierVatNumber;
  final String? trailerNumber;
}

class AadeSubmitResult {
  const AadeSubmitResult({
    required this.ok,
    required this.message,
    this.statusCode,
    this.mark,
    this.body,
  });

  final bool ok;
  final String message;
  final int? statusCode;
  final String? mark;
  final String? body;
}
