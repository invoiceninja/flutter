import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the fields the SERVER freezes once a record exists
/// (invoiceninja/flutter#158).
///
/// The Laravel UPDATE requests pin these to their current value —
/// `$rules['client_id'] = ['bail','sometimes','integer', Rule::in([$this->invoice->client_id])]`
/// in `UpdateInvoiceRequest`, the same shape in Quote / Credit /
/// RecurringInvoice, `vendor_id` in `UpdatePurchaseOrderRequest`, `client_id`
/// in `UpdatePaymentRequest` — and `UpdateProjectRequest` silently overwrites
/// its own. So the UI must not offer the edit.
///
/// Scanned rather than exercised, for the same reason
/// `billing_edit_tab_strip_wiring_test.dart` and
/// `assigned_user_picker_wiring_test.dart` are: pumping one of these layouts
/// for real needs a live `Services` plus a Drift-backed repository per picker.
/// The five billing layouts now have that harness
/// (`test/ui/features/billing_shared/edit/_billing_edit_harness.dart`, used by
/// `billing_doc_edit_layout_characterization_test.dart`), but only in create
/// mode — the frozen row appears in EDIT mode, so it is still scanned here. The
/// shared row's own mechanism is covered by
/// `test/ui/core/widgets/locked_entity_field_row_test.dart`; what is left to
/// protect is the wiring, and every failure here is silent — delete a branch
/// and the app compiles, runs, and only 422s against a real server.
///
/// The negative half matters at least as much. Three sibling party pickers are
/// **not** frozen and a well-meaning sweep would break them:
///   * the Vendor on invoice / quote / credit / recurring (their Settings tab)
///     — `vendor_id` is `$fillable` on those four with no update rule at all;
///   * the client on an expense and on a recurring expense — both editable
///     (`UpdateExpenseRequest`, `UpdateRecurringExpenseRequest`);
///   * the purchase order's own `client_id`, which is `nullable|exists`, not
///     pinned — only its `vendor_id` is.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path has moved');
    return file.readAsStringSync();
  }

  /// [read] with every `//` tail removed, so a rule can't be satisfied — or
  /// broken — by the prose that explains it. The trap
  /// `no_list_tile_name_link_test.dart` already records.
  String codeOf(String path) => read(path)
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');

  /// The hosts whose party field the server pins, with the widget each one
  /// must render and the helper key it must use. Payment is the only one
  /// without a Clone action, so it is the only one that may NOT promise Clone
  /// as the way out — a copy-paste in either direction is invisible on screen.
  const frozen = <String, (String, String)>{
    'lib/ui/features/billing_shared/edit/billing_doc_client_picker.dart': (
      'LockedClientFieldRow',
      'locked_after_save_clone',
    ),
    'lib/ui/features/billing_shared/edit/billing_doc_vendor_picker.dart': (
      'LockedVendorFieldRow',
      'locked_after_save_clone',
    ),
    'lib/ui/features/payments/widgets/edit/payment_edit_layout.dart': (
      'LockedClientFieldRow',
      'locked_after_save',
    ),
    'lib/ui/features/projects/widgets/edit/project_edit_details_section.dart': (
      'LockedClientFieldRow',
      'locked_after_save_clone',
    ),
  };

  /// A negative rule is only worth its liveness guard: `isNot(contains(…))`
  /// passes forever once the needle is renamed, which is the exact trap
  /// `billing_edit_tab_strip_wiring_test.dart` documents ("an empty match set
  /// is indistinguishable from a clean scan"). So assert first that the names
  /// the negative half hunts for still EXIST.
  test('the widget names the negative rules hunt for still exist', () {
    final widget = codeOf('lib/ui/core/widgets/locked_entity_field_row.dart');
    expect(widget, contains('class LockedClientFieldRow'));
    expect(widget, contains('class LockedVendorFieldRow'));
  });

  group('a server-frozen party field is locked once the record exists', () {
    frozen.forEach((path, spec) {
      final (widget, helperKey) = spec;
      test(path, () {
        final code = codeOf(path);
        expect(
          code,
          contains(widget),
          reason:
              '$path must render $widget once the record exists — a changed '
              'client/vendor is rejected by the server and surfaces as a '
              'save-failed banner the user can only discard',
        );
        expect(
          code,
          contains('if (!vm.isCreate) {'),
          reason:
              '$path must gate the lock on `!vm.isCreate` and nothing else. '
              'An `&& id.isNotEmpty` fall-through to the live picker was tried '
              'and removed: on a saved record the server pins the party, so '
              'the picker could only 422 (billing / PO) or be silently '
              'discarded (project, whose `validate()` returns {} on an edit).',
        );
        expect(
          code,
          contains("tr('$helperKey')"),
          reason:
              '$path must use $helperKey — only payment lacks a Clone action, '
              'so only payment may omit the "use Clone" exit',
        );
      });
    });
  });

  group('a field the server does NOT freeze stays editable', () {
    // The Vendor these four carry on their Settings tab. `Invoice`, `Quote`,
    // `Credit` and `RecurringInvoice` all list `vendor_id` in `$fillable` and
    // none of their update requests mentions it.
    test('the billing-doc Settings tab vendor is never locked', () {
      final code = codeOf(
        'lib/ui/features/billing_shared/edit/billing_doc_settings_tab.dart',
      );
      expect(code, contains('SearchableDropdownField<Vendor>'));
      expect(
        code,
        isNot(contains('LockedVendorFieldRow')),
        reason:
            'vendor_id is fillable and unpinned on invoice / quote / credit / '
            'recurring — locking it would break a working field',
      );
    });

    for (final path in const [
      'lib/ui/features/expenses/widgets/edit/expense_edit_identity_section.dart',
      'lib/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_identity_section.dart',
    ]) {
      test('$path keeps its client and vendor pickers', () {
        final code = codeOf(path);
        expect(
          code,
          isNot(contains('LockedClientFieldRow')),
          reason: 'the server allows changing an expense client',
        );
        expect(
          code,
          isNot(contains('LockedVendorFieldRow')),
          reason: 'the server allows changing an expense vendor',
        );
      });
    }

    // The task form DOES render a locked client row, but for an unrelated
    // reason — the selected project derives it — so its gate must stay
    // `projectId`, never `isCreate`.
    test('the task client lock stays gated on the project, not on isCreate', () {
      final code = codeOf(
        'lib/ui/features/tasks/widgets/edit/task_edit_layout.dart',
      );
      expect(code, contains('LockedClientFieldRow'));
      expect(code, contains('lockedByProject'));
      expect(
        code,
        isNot(contains('!vm.isCreate')),
        reason:
            'UpdateTaskRequest allows changing client_id — a saved task keeps '
            'its live picker whenever no project drives it',
      );
    });
  });

  // The one non-picker path that can still seed a client onto a billing doc.
  // It is gated on the draft having none, which a saved document never has —
  // but on one that somehow does, seeding here would 422 on a field the user
  // can no longer see.
  group('the line-item picker only carries a client over on a create', () {
    test('the callee gates on it', () {
      final code = codeOf(
        'lib/ui/features/billing_shared/line_item_picker/line_item_picker_invoke.dart',
      );
      expect(code, contains('currentClientId.isEmpty && isCreate'));
    });

    // Pinning only the callee leaves the door open: `isCreate: true` hardcoded
    // at a call site restores the back door with a green suite.
    // The five billing documents open it from their one shared layout.
    test('the shared billing-doc layout passes the real flag', () {
      final code = codeOf(
        'lib/ui/features/billing_shared/edit/billing_doc_edit_layout.dart',
      );
      expect(
        code,
        contains('openLineItemPicker('),
        reason: 'the shared layout no longer opens the picker — update this',
      );
      expect(code, contains('isCreate: vm.isCreate,'));
    });
  });
}
