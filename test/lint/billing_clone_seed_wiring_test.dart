import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A cloned billing document copies its source's tax rates; a new one takes
/// the Default Tax Rates (invoiceninja/flutter#178) — even one built with
/// lines from a product, task, expense or project. Both reach the create
/// screen through the one staged-draft slot on `Services`, so the difference
/// rides on a single flag, and both ends of it are pinned here:
///
///  * every clone action (Clone, Clone to …, Rectify, Convert to purchase
///    order) stages with `isClone: true`, and
///  * all five edit screens read it back through `takeCreateSeed` and hand it
///    to `seedBillingCreateDefaults`.
///
/// Dropping either end compiles, runs and looks right on screen — the clone of
/// an untaxed invoice just quietly picks up the company's tax. The seeding has
/// its own tests (`seed_billing_create_defaults_test.dart`); what is left is
/// wiring, which a source scan sees and a widget test would need `Services`,
/// Drift and a router to reach. Twin of `expense_clone_seed_wiring_test.dart`.
void main() {
  /// Source with every `//` tail stripped, so prose naming a token can't
  /// satisfy a rule.
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  String dense(String s) => s.replaceAll(RegExp(r'\s+'), '');

  /// Every `goEntityCreateFullWidth(...)` call in [code], parens balanced.
  List<String> createCalls(String code) {
    const marker = 'goEntityCreateFullWidth(';
    final calls = <String>[];
    var from = 0;
    while (true) {
      final start = code.indexOf(marker, from);
      if (start == -1) break;
      var depth = 0;
      var end = start + marker.length - 1;
      for (; end < code.length; end++) {
        final ch = code[end];
        if (ch == '(') depth++;
        if (ch == ')' && --depth == 0) break;
      }
      calls.add(code.substring(start, end + 1));
      from = end + 1;
    }
    return calls;
  }

  const billingRoutes = [
    "'/invoices'",
    "'/quotes'",
    "'/credits'",
    "'/purchase_orders'",
    "'/recurring_invoices'",
  ];
  bool targetsABillingCreate(String call) => billingRoutes.any(call.contains);

  // A billing document's own action menu reaches a billing create route only
  // to copy that document. Starting a fresh one is the list's "New", which
  // stages nothing, or another entity's "New Invoice", which is not a clone.
  for (final (path, count) in const [
    ('lib/ui/features/invoices/widgets/invoice_actions.dart', 6),
    ('lib/ui/features/quotes/widgets/quote_actions.dart', 5),
    ('lib/ui/features/credits/widgets/credit_actions.dart', 4),
    (
      'lib/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart',
      5,
    ),
    ('lib/ui/features/purchase_orders/widgets/purchase_order_actions.dart', 4),
    ('lib/ui/features/billing_shared/convert_to_purchase_order_action.dart', 1),
  ]) {
    test('every billing create reached from ${path.split('/').last} is '
        'staged as a clone', () {
      final calls = createCalls(
        codeOf(path),
      ).where(targetsABillingCreate).toList();
      expect(
        calls,
        hasLength(count),
        reason:
            '$path should stage exactly its $count clone actions — the call '
            'shape changed and this scan went blind, or a non-clone create '
            'was added (it then needs its own rule here)',
      );
      for (final call in calls) {
        expect(
          dense(call).contains('isClone:true'),
          isTrue,
          reason:
              'this clone is staged without `isClone: true`, so the create '
              'screen would put the Default Tax Rates on the copy:\n$call',
        );
      }
    });
  }

  for (final path in const [
    'lib/ui/features/invoices/views/invoice_edit_screen.dart',
    'lib/ui/features/quotes/views/quote_edit_screen.dart',
    'lib/ui/features/credits/views/credit_edit_screen.dart',
    'lib/ui/features/purchase_orders/views/purchase_order_edit_screen.dart',
    'lib/ui/features/recurring_invoices/views/recurring_invoice_edit_screen.dart',
  ]) {
    test('${path.split('/').last} reads the clone flag and hands it to the '
        'create defaults', () {
      final code = dense(codeOf(path));
      expect(
        code.contains('takeCreateSeed<'),
        isTrue,
        reason: '$path must read its seed through `takeCreateSeed`',
      );
      expect(
        code.contains('takeCreateDraft<'),
        isFalse,
        reason:
            '$path reads a seed through `takeCreateDraft`, which drops the '
            'clone flag',
      );
      expect(
        code.contains('isClone:seed?.isClone??false'),
        isTrue,
        reason:
            '$path must pass `isClone: seed?.isClone ?? false` to '
            '`seedBillingCreateDefaults`',
      );
      expect(
        code.contains('taxFacts:BillingTaxFacts.of('),
        isTrue,
        reason: '$path no longer seeds the Default Tax Rates',
      );
    });
  }
}
