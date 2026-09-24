import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/sync/mutation.dart';

/// The server ignores `Idempotency-Key` (BACKEND.md), so whether an outbox
/// row may be re-sent after an attempt with an unknown outcome depends
/// entirely on what its endpoint does twice. These verdicts were read off the
/// server source; changing one is a decision about duplicate emails, charges
/// and records, so it has to be made here, on purpose.
void main() {
  const nonIdempotent = DeliverySafety.nonIdempotent;
  const serverGuarded = DeliverySafety.serverGuarded;
  const idempotent = DeliverySafety.idempotent;

  const expected = <MutationKind, DeliverySafety>{
    // A replay does it again.
    MutationKind.create: nonIdempotent,
    MutationKind.addComment: nonIdempotent,
    MutationKind.documentUpload: nonIdempotent,
    MutationKind.emailEntity: nonIdempotent,
    MutationKind.scheduleEmail: nonIdempotent,
    MutationKind.cloneToInvoice: nonIdempotent,
    MutationKind.cloneToQuote: nonIdempotent,
    MutationKind.cloneToCredit: nonIdempotent,
    MutationKind.cloneToRecurring: nonIdempotent,
    MutationKind.cloneToPurchaseOrder: nonIdempotent,
    MutationKind.autoBill: nonIdempotent,
    MutationKind.increasePrices: nonIdempotent, // a percentage — compounds
    MutationKind.convertToProject: nonIdempotent,
    MutationKind.sendNow: nonIdempotent,
    MutationKind.inviteUser: nonIdempotent,
    MutationKind.refundPayment: nonIdempotent,
    MutationKind.applyPayment: nonIdempotent,
    MutationKind.locationCreate: nonIdempotent,
    MutationKind.paymentScheduleCreate: nonIdempotent,
    MutationKind.markPaid: nonIdempotent, // a credit replay writes a payment
    // The server has a guard, but it is racy and the effect — a second legal
    // e-invoice to the tax network — is not one to risk on a retry.
    MutationKind.sendEInvoice: nonIdempotent,
    // A replay is refused or ignored — never a double effect.
    MutationKind.cancelEntity: serverGuarded,
    MutationKind.peppolSetup: serverGuarded,
    MutationKind.peppolDisconnect: serverGuarded,
    MutationKind.peppolAddTaxIdentifier: serverGuarded,
    MutationKind.peppolRemoveTaxIdentifier: serverGuarded,
    MutationKind.detachFromCompany: serverGuarded,
    MutationKind.merge: serverGuarded,
    MutationKind.paymentScheduleCreateCustom: serverGuarded,
    // A replay leaves the server as one send would.
    MutationKind.update: idempotent,
    MutationKind.delete: idempotent,
    MutationKind.archive: idempotent,
    MutationKind.restore: idempotent,
    MutationKind.purge: idempotent,
    MutationKind.reactivateEmail: idempotent,
    MutationKind.documentDelete: idempotent,
    MutationKind.documentVisibility: idempotent,
    MutationKind.reorder: idempotent,
    MutationKind.start: idempotent,
    MutationKind.stop: idempotent,
    MutationKind.markSent: idempotent,
    MutationKind.approve: idempotent,
    MutationKind.convertToInvoice: idempotent,
    MutationKind.convertToExpense: idempotent,
    MutationKind.addToInventory: idempotent,
    MutationKind.acceptOrder: idempotent,
    MutationKind.runTemplate: idempotent, // PDF render only, never send_email
    MutationKind.updatePrices: idempotent,
    MutationKind.bulkUpdate: idempotent,
    MutationKind.setDefaultDesign: idempotent,
    MutationKind.uploadEInvoiceCertificate: idempotent,
    MutationKind.peppolUpdate: idempotent,
    MutationKind.eInvoicePaymentMeans: idempotent,
    MutationKind.regenerateEInvoiceToken: idempotent,
    MutationKind.refreshAccounts: idempotent,
    MutationKind.matchToPayment: idempotent,
    MutationKind.linkToPayment: idempotent,
    MutationKind.matchToExpense: idempotent,
    MutationKind.linkToExpense: idempotent,
    MutationKind.convertMatched: idempotent,
    MutationKind.unlinkTransaction: idempotent,
    MutationKind.locationUpdate: idempotent,
    MutationKind.locationDelete: idempotent,
    MutationKind.paymentScheduleDelete: idempotent,
  };

  test('every kind has a pinned verdict', () {
    expect(
      expected.keys.toSet(),
      MutationKind.values.toSet(),
      reason: 'a new MutationKind needs a verdict here, decided on purpose',
    );
  });

  for (final MapEntry(key: kind, value: safety) in expected.entries) {
    test('${kind.name} is ${safety.name}', () {
      expect(kind.deliverySafety, safety);
    });
  }

  test('only non-idempotent rows are held back from an automatic re-send', () {
    expect(nonIdempotent.autoResendable, isFalse);
    expect(serverGuarded.autoResendable, isTrue);
    expect(idempotent.autoResendable, isTrue);
  });

  group('deliverySafetyFor (the row can be stricter than its kind)', () {
    test('a save that also marks paid, auto-bills or sends escalates', () {
      for (final param in kNonIdempotentSaveParams) {
        expect(
          deliverySafetyFor(MutationKind.update, {
            'id': 'i1',
            kSaveQueryPayloadKey: {param: 'true'},
          }),
          nonIdempotent,
          reason: param,
        );
      }
    });

    test('a save that only sets a state stays idempotent', () {
      expect(
        deliverySafetyFor(MutationKind.update, {
          kSaveQueryPayloadKey: {'mark_sent': 'true'},
        }),
        idempotent,
      );
    });

    test('a company update that adds a document escalates; one that '
        'replaces the logo does not', () {
      expect(
        deliverySafetyFor(MutationKind.update, {'_action': 'upload_document'}),
        nonIdempotent,
      );
      expect(
        deliverySafetyFor(MutationKind.update, {'_action': 'upload_logo'}),
        idempotent,
      );
    });

    test('never relaxes a kind, and tolerates a non-map payload', () {
      expect(deliverySafetyFor(MutationKind.create, const {}), nonIdempotent);
      expect(deliverySafetyFor(MutationKind.update, 'not a map'), idempotent);
      expect(deliverySafetyFor(MutationKind.update, null), idempotent);
    });
  });

  test('the verdict switch has no wildcard (a new kind must not compile '
      'unclassified)', () {
    final source = File('lib/domain/sync/mutation.dart').readAsStringSync();
    final start = source.indexOf('DeliverySafety get deliverySafety');
    expect(start, isNonNegative, reason: 'getter moved — update this guard');
    final body = source.substring(start, source.indexOf('};', start));
    expect(body, isNot(contains('_ =>')));
    expect(body, isNot(contains('default')));
  });
}
