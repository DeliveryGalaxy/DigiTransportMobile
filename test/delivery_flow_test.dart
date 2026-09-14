import 'package:digi_transport/models/delivery.dart';
import 'package:digi_transport/services/delivery_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('start route advances from registered, in transit and return', () {
    expect(
      DeliveryFlowPlan.forAction(
        action: QrFlowAction.startRoute,
        status: DeliveryStatus.registered,
      ).canAdvance,
      isTrue,
    );
    expect(
      DeliveryFlowPlan.forAction(
        action: QrFlowAction.startRoute,
        status: DeliveryStatus.inTransit,
      ).advanceLabel,
      'Μεταφόρτωση',
    );
    expect(
      DeliveryFlowPlan.forAction(
        action: QrFlowAction.startRoute,
        status: DeliveryStatus.completed,
      ).canAdvance,
      isFalse,
    );
  });

  test('receive advances from in transit and delivered by carrier', () {
    final inTransit = DeliveryFlowPlan.forAction(
      action: QrFlowAction.receive,
      status: DeliveryStatus.inTransit,
    );
    expect(inTransit.canAdvance, isTrue);
    expect(inTransit.allowsReject, isTrue);
    expect(inTransit.allowsFailedDelivery, isTrue);
    expect(inTransit.allowsPartial, isTrue);

    final delivered = DeliveryFlowPlan.forAction(
      action: QrFlowAction.receive,
      status: DeliveryStatus.deliveredByCarrier,
    );
    expect(delivered.canAdvance, isTrue);
    expect(delivered.allowsReject, isTrue);
    expect(delivered.allowsFailedDelivery, isFalse);

    expect(
      DeliveryFlowPlan.forAction(
        action: QrFlowAction.receive,
        status: DeliveryStatus.registered,
      ).canAdvance,
      isFalse,
    );
  });
}
