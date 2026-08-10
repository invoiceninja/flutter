import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Minimal billing doc carrying just the client id + invitations array
/// that `selectClient` reads and rewrites.
class _Doc {
  const _Doc({this.clientId = '', this.invitations = const []});
  final String clientId;
  final List<Invitation> invitations;
}

/// Concrete VM to exercise `selectClient` in isolation.
class _Vm extends GenericBillingDocEditViewModel<_Doc> {
  _Vm(_Doc seed) : super(initialDraft: seed);

  @override
  List<LineItem> lineItemsOf(_Doc d) => const [];
  @override
  _Doc copyWithLineItems(_Doc d, List<LineItem> items) => d;
  @override
  List<Invitation> invitationsOf(_Doc d) => d.invitations;
  @override
  _Doc copyWithInvitations(_Doc d, List<Invitation> inv) =>
      _Doc(clientId: d.clientId, invitations: inv);
  @override
  String clientIdOf(_Doc d) => d.clientId;
  @override
  _Doc copyWithClientId(_Doc d, String clientId) =>
      _Doc(clientId: clientId, invitations: d.invitations);
  @override
  Map<String, dynamic>? eInvoiceOf(_Doc d) => null;
  @override
  _Doc copyWithEInvoice(_Doc d, Map<String, dynamic>? e) => d;
  @override
  _Doc copyWithStampedTotals(
    _Doc d, {
    required Decimal amount,
    required Decimal taxAmount,
  }) => d;
  @override
  BillingTotalsInput totalsInputOf(_Doc d) => BillingTotalsInput(
    lineItems: const [],
    discount: Decimal.zero,
    isAmountDiscount: false,
    usesInclusiveTaxes: false,
  );
  @override
  Future<SaveResult<_Doc>> performSave() async =>
      SaveResult(entity: draft, outboxRowId: 1);
}

Contact _contact(
  String id, {
  bool sendEmail = false,
  bool ccOnly = false,
  bool isPrimary = false,
  bool isDeleted = false,
}) => Contact(
  id: id,
  firstName: 'F$id',
  lastName: 'L$id',
  email: '$id@example.com',
  phone: '',
  isPrimary: isPrimary,
  sendEmail: sendEmail,
  ccOnly: ccOnly,
  isDeleted: isDeleted,
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('selectClient auto-invitations', () {
    test('seeds one invitation per sendEmail contact, skipping opt-outs', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('client-1', [
        _contact('a', sendEmail: true),
        _contact('b', sendEmail: false),
        _contact('c', sendEmail: true, isPrimary: true),
      ]);

      expect(vm.draft.clientId, 'client-1');
      expect(vm.draft.invitations.map((i) => i.clientContactId), ['a', 'c']);
    });

    test('CC-only contacts still get an invitation (emailed as CC)', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('client-1', [
        _contact('a', sendEmail: true),
        _contact('b', ccOnly: true, sendEmail: false),
        _contact('c'),
      ]);

      expect(
        vm.draft.invitations.map((i) => i.clientContactId),
        ['a', 'b'],
        reason: 'CC-only auto-clears sendEmail but must keep an invitation',
      );
    });

    test('falls back to the primary contact when none opt in', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('client-1', [
        _contact('a'),
        _contact('b', isPrimary: true),
      ]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['b']);
    });

    test('falls back to the first contact when no primary and none opt in', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('client-1', [_contact('a'), _contact('b')]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['a']);
    });

    test('ignores deleted contacts entirely', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('client-1', [
        _contact('a', sendEmail: true, isDeleted: true),
        _contact('b', sendEmail: true),
      ]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['b']);
    });

    test('switching to a different client replaces invitations', () {
      final vm = _Vm(
        _Doc(
          clientId: 'client-1',
          invitations: [const Invitation(clientContactId: 'old')],
        ),
      );
      vm.selectClient('client-2', [_contact('new', sendEmail: true)]);

      expect(vm.draft.clientId, 'client-2');
      expect(vm.draft.invitations.map((i) => i.clientContactId), ['new']);
    });

    test('re-selecting the same client preserves manual invitations', () {
      final vm = _Vm(
        _Doc(
          clientId: 'client-1',
          invitations: [const Invitation(clientContactId: 'manual')],
        ),
      );
      vm.selectClient('client-1', [_contact('other', sendEmail: true)]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['manual']);
    });

    test('clearing the client yields no invitations and does not throw', () {
      final vm = _Vm(
        _Doc(
          clientId: 'client-1',
          invitations: [const Invitation(clientContactId: 'a')],
        ),
      );
      vm.selectClient('', const []);

      expect(vm.draft.clientId, '');
      expect(vm.draft.invitations, isEmpty);
    });
  });

  group('seedClientInvitationsIfEmpty', () {
    test(
      'seeds from contacts when the draft has a client but no invitations',
      () {
        // The bug: "New Invoice" from a Client hands the screen a draft with
        // the client already set and invitations empty, so the dropdown's
        // onChanged (and thus selectClient) never fires.
        final vm = _Vm(const _Doc(clientId: 'client-1'));
        expect(vm.hasInvitations, isFalse);

        vm.seedClientInvitationsIfEmpty([
          _contact('a', sendEmail: true),
          _contact('b', sendEmail: false),
          _contact('c', sendEmail: true),
        ]);

        expect(vm.draft.invitations.map((i) => i.clientContactId), ['a', 'c']);
        expect(vm.hasInvitations, isTrue);
      },
    );

    test('is a no-op when invitations already exist (clone / manual edit)', () {
      final vm = _Vm(
        _Doc(
          clientId: 'client-1',
          invitations: [const Invitation(clientContactId: 'manual')],
        ),
      );
      vm.seedClientInvitationsIfEmpty([_contact('other', sendEmail: true)]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['manual']);
    });

    test('falls back to the primary contact when none opt in', () {
      final vm = _Vm(const _Doc(clientId: 'client-1'));
      vm.seedClientInvitationsIfEmpty([
        _contact('a'),
        _contact('b', isPrimary: true),
      ]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['b']);
    });

    test('clientId getter reflects the draft', () {
      expect(_Vm(const _Doc()).clientId, '');
      expect(_Vm(const _Doc(clientId: 'client-9')).clientId, 'client-9');
    });
  });

  // Contact ids are minted by the server, so a client that hasn't synced yet
  // (created inline from a billing-doc picker, or a contact added offline to
  // an existing client) carries `id: ''` with `sendEmail: true`. Shipping an
  // invitation for one fails the server's `required` rule on
  // `invitations.*.client_contact_id` and 422s the whole document save.
  //
  // Seeding nothing is equivalent, not degraded: the server runs
  // `createInvitations()` for any saved doc with zero invitations, producing
  // one per `send_email && !cc_only` contact.
  group('unsynced contacts (blank id)', () {
    test('selectClient seeds no invitation for a blank-id contact', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('tmp_abc', [
        _contact('', sendEmail: true, isPrimary: true),
      ]);

      expect(vm.draft.clientId, 'tmp_abc');
      expect(vm.draft.invitations, isEmpty);
    });

    test('keeps only real-id contacts in a mixed list', () {
      final vm = _Vm(const _Doc());
      vm.selectClient('client-1', [
        _contact('a', sendEmail: true),
        _contact('', sendEmail: true, isPrimary: true),
      ]);

      expect(vm.draft.invitations.map((i) => i.clientContactId), ['a']);
    });

    test(
      'primary fallback skips a blank-id primary and picks a real contact',
      () {
        final vm = _Vm(const _Doc());
        vm.selectClient('client-1', [
          _contact('a'),
          _contact('', isPrimary: true),
        ]);

        expect(vm.draft.invitations.map((i) => i.clientContactId), ['a']);
      },
    );

    test('seedClientInvitationsIfEmpty also skips blank ids', () {
      final vm = _Vm(const _Doc(clientId: 'tmp_abc'));
      vm.seedClientInvitationsIfEmpty([
        _contact('', sendEmail: true, isPrimary: true),
      ]);

      expect(vm.draft.invitations, isEmpty);
    });

    test('setContactInvitation ignores a blank contact id', () {
      final vm = _Vm(const _Doc(clientId: 'tmp_abc'));
      vm.setContactInvitation('', true);

      expect(vm.draft.invitations, isEmpty);
    });

    test('setVendorContactInvitation ignores a blank contact id', () {
      final vm = _Vm(const _Doc(clientId: 'tmp_abc'));
      vm.setVendorContactInvitation('', true);

      expect(vm.draft.invitations, isEmpty);
    });

    test('real contact ids still toggle normally', () {
      final vm = _Vm(const _Doc(clientId: 'client-1'));
      vm.setContactInvitation('a', true);
      expect(vm.draft.invitations.map((i) => i.clientContactId), ['a']);

      vm.setContactInvitation('a', false);
      expect(vm.draft.invitations, isEmpty);
    });
  });
}
