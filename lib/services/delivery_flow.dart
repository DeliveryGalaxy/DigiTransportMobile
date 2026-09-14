import '../models/delivery.dart';

/// Allowed next AADE calls for a scanned QR, based on docs §1.2 / §3.2.
class DeliveryFlowPlan {
  const DeliveryFlowPlan({
    required this.canAdvance,
    required this.explanation,
    this.advanceLabel,
    this.cancelLabel,
    this.allowsReject = false,
    this.allowsFailedDelivery = false,
    this.allowsPartial = false,
  });

  final bool canAdvance;
  final String explanation;
  final String? advanceLabel;
  final String? cancelLabel;
  final bool allowsReject;
  final bool allowsFailedDelivery;
  final bool allowsPartial;

  static DeliveryFlowPlan forAction({
    required QrFlowAction action,
    required DeliveryStatus status,
  }) {
    if (action == QrFlowAction.startRoute) {
      return switch (status) {
        DeliveryStatus.registered => const DeliveryFlowPlan(
          canAdvance: true,
          advanceLabel: 'Έναρξη διακίνησης',
          cancelLabel: 'Ακύρωση',
          explanation:
              'Το δελτίο έχει εκδοθεί. Η έναρξη δηλώνεται με RegisterTransfer.',
        ),
        DeliveryStatus.inTransit => const DeliveryFlowPlan(
          canAdvance: true,
          advanceLabel: 'Μεταφόρτωση',
          cancelLabel: 'Ακύρωση',
          explanation:
              'Η διακίνηση έχει ήδη ξεκινήσει. Νέο RegisterTransfer δηλώνει μεταφόρτωση.',
        ),
        DeliveryStatus.inTransitReturn => const DeliveryFlowPlan(
          canAdvance: true,
          advanceLabel: 'Συνέχεια επιστροφής',
          cancelLabel: 'Ακύρωση',
          explanation:
              'Το δελτίο είναι σε επιστροφή. RegisterTransfer συνεχίζει τη διακίνηση.',
        ),
        DeliveryStatus.rejected => const DeliveryFlowPlan(
          canAdvance: true,
          advanceLabel: 'Επιστροφή μετά από απόρριψη',
          cancelLabel: 'Ακύρωση',
          explanation:
              'Ο λήπτης απέρριψε την παραλαβή. RegisterTransfer δηλώνει την επιστροφή.',
        ),
        _ => DeliveryFlowPlan(
          canAdvance: false,
          cancelLabel: 'Κλείσιμο',
          explanation:
              'Η κατάσταση «${status.label}» δεν επιτρέπει έναρξη ή μεταφόρτωση.',
        ),
      };
    }

    return switch (status) {
      DeliveryStatus.inTransit => const DeliveryFlowPlan(
        canAdvance: true,
        advanceLabel: 'Πλήρης παράδοση',
        cancelLabel: 'Ακύρωση',
        allowsReject: true,
        allowsFailedDelivery: true,
        allowsPartial: true,
        explanation:
            'Το δελτίο είναι σε διακίνηση. Δηλώστε αποτέλεσμα παράδοσης ή απόρριψη.',
      ),
      DeliveryStatus.deliveredByCarrier => const DeliveryFlowPlan(
        canAdvance: true,
        advanceLabel: 'Επιβεβαίωση παραλαβής',
        cancelLabel: 'Ακύρωση',
        allowsReject: true,
        explanation:
            'Ο μεταφορέας δήλωσε παράδοση. Ο λήπτης επιβεβαιώνει ή απορρίπτει.',
      ),
      _ => DeliveryFlowPlan(
        canAdvance: false,
        cancelLabel: 'Κλείσιμο',
        explanation:
            'Η κατάσταση «${status.label}» δεν επιτρέπει δήλωση παραλαβής.',
      ),
    };
  }
}
