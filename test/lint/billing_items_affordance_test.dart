import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the Items tab's add affordances on the five
/// billing-doc edit layouts (invoiceninja/flutter#141 + #142).
///
/// Scanned rather than exercised because pumping one of these layouts for real
/// needs a live `Services`, a Drift-backed repository per picker and a
/// `TabBarView` whose first page opens client / project / design streams — and
/// because every failure here is silent. Re-add a `Positioned` FAB to the
/// narrow tab and the app compiles, the tab still works, it just carries the
/// duplicate #142 asked to remove; drop the shared body from one of the five
/// and that entity alone goes back to a top-left empty state. Same reasoning as
/// `tasks_view_wiring_test.dart` and `billing_edit_tab_strip_wiring_test.dart`.
///
/// The behaviour itself is covered where it can be pumped:
/// `billing_doc_edit_items_body_test.dart` (the host),
/// `line_item_card_list_mobile_test.dart` (the two buttons and the modal), and
/// `line_item_editor_wide_gate_test.dart` (the shared width gate).
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

  const layouts = {
    'invoices':
        'lib/ui/features/invoices/widgets/edit/invoice_edit_layout.dart',
    'quotes': 'lib/ui/features/quotes/widgets/edit/quote_edit_layout.dart',
    'credits': 'lib/ui/features/credits/widgets/edit/credit_edit_layout.dart',
    'purchase orders':
        'lib/ui/features/purchase_orders/widgets/edit/purchase_order_edit_layout.dart',
    'recurring invoices':
        'lib/ui/features/recurring_invoices/widgets/edit/recurring_invoice_edit_layout.dart',
  };

  /// The `_ItemsTab` class body, which is what these rules are about — the
  /// layouts use `Stack` / `SingleChildScrollView` freely in their other tabs.
  /// The one edit layout the five documents share — where their Items tab,
  /// FAB and picker shortcut now live, written once.
  const shared =
      'lib/ui/features/billing_shared/edit/billing_doc_edit_layout.dart';

  String itemsTabOf(String path) {
    final code = codeOf(path);
    final start = code.indexOf('class _ItemsTab<');
    expect(start, isNonNegative, reason: '_ItemsTab has been renamed in $path');
    final end = code.indexOf('\nclass ', start + 1);
    return code.substring(start, end < 0 ? code.length : end);
  }

  group('the shared layout', () {
    test('renders its narrow Items tab through the shared body', () {
      final tab = itemsTabOf(shared);
      expect(
        tab,
        contains('BillingDocEditItemsBody('),
        reason:
            'the scroll host, the min-height and the FAB gate all live in '
            'one widget — a local copy opts out of all three at once',
      );
      for (final local in const [
        'Stack(',
        'SingleChildScrollView(',
        'Positioned(',
      ]) {
        expect(
          tab,
          isNot(contains(local)),
          reason: '_ItemsTab is re-rolling the shared body\'s $local',
        );
      }
    });

    test('keeps exactly one FAB, on the desktop page', () {
      expect(
        'BillingDocEditFab('.allMatches(codeOf(shared)),
        hasLength(1),
        reason:
            'the >= 1024 page keeps its FAB; a second one here is the narrow '
            'tab mounting its own again',
      );
    });

    test('still wraps the desktop page in the picker shortcut scope', () {
      expect(codeOf(shared), contains('BillingDocEditPickerShortcuts('));
    });
  });

  layouts.forEach((name, path) {
    test('$name adds no Items tab or FAB of its own', () {
      final code = codeOf(path);
      expect(code, isNot(contains('BillingDocEditFab(')));
      expect(code, isNot(contains('BillingDocEditItemsBody(')));
    });
  });

  test('the shared body gates its FAB on the shared width predicate', () {
    final code = codeOf(
      'lib/ui/features/billing_shared/edit/billing_doc_edit_items_body.dart',
    );
    expect(code, contains('lineItemEditorShowsWideTable('));
    expect(
      code,
      contains('fit: StackFit.expand'),
      reason: 'the default loose fit is what caused #141',
    );
    expect(
      code,
      contains('minHeight: wideTable ? 0 : available'),
      reason:
          'a min-height on the wide branch stretches the desktop table\'s '
          'bordered container to the full viewport',
    );
  });

  test('the phone Add button opens the editor before appending', () {
    // Reverting to a blank-row append compiles, passes every other test, and
    // silently undoes the ask: the user is left to find an "Untitled" card.
    final code = codeOf(
      'lib/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart',
    );
    final add = code.substring(code.indexOf('Future<void> _add('));
    expect(add, contains('showLineItemEditDialog('));
    expect(
      add.substring(0, add.indexOf('onChanged(')),
      contains('if (result == null) return;'),
    );
  });
}
