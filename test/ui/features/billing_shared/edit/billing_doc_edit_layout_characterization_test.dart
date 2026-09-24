// Characterization of the five billing-document edit layouts — invoice,
// quote, credit, purchase order, recurring invoice — which are 76–92%
// identical copies of one another. Before this file nothing built any of
// them in a test; only source-scan lints pinned the copies, so a fix that
// reached four of the five (and several did) went unnoticed.
//
// What is pinned: the tab strip and the field labels on every tab at phone
// (390) and tablet (900) widths, every field on the desktop (1440) layout,
// the e-invoice variant, and three invariants that have drifted between the
// copies. Known bugs are recorded as the CURRENT behaviour under `// BUG:`,
// so fixing one flips exactly that line — and consolidating the layouts must
// leave everything else unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';

import '../../shell/_shell_test_helpers.dart';
import '_billing_edit_harness.dart';

const _customFields = {
  'invoice1': 'CF1',
  'invoice2': 'CF2',
  'invoice3': 'CF3',
  'invoice4': 'CF4',
};

const _cf = ['CF1', 'CF2', 'CF3', 'CF4'];
const _settingsTab = [
  'Design',
  'Project',
  'Exchange Rate',
  'User',
  'Vendor',
  'Add tag',
];
const _wideItemsTable = [
  'Add an item…',
  'Description',
  '<unlabelled>',
  '<unlabelled>',
];

/// Phone layout (390 px): tab label → field labels on that tab. No PDF tab —
/// below `Breakpoints.wide` the PDF is the header's preview button.
const _phone = <BillingDoc, Map<String, List<String>>>{
  BillingDoc.invoice: {
    'Details': [
      'Client',
      'Invoice Number',
      'PO Number',
      'Invoice Date',
      'Due Date',
      // Invoice alone shows the partial row unconditionally, both fields;
      // quote puts it after Discount and credit has no partial due date.
      'Partial/Deposit',
      'Partial Due Date',
      'Discount',
      // Design lives on the Settings tab only; the Details tab used to carry
      // a second copy of it on phones and tablets.
      ..._cf,
    ],
    'Contacts': [],
    'Items': [],
    'Notes': [],
    'Settings': _settingsTab,
  },
  BillingDoc.quote: {
    'Details': [
      'Client',
      'Quote Number',
      'PO Number',
      'Quote Date',
      'Valid Until',
      'Discount',
      'Partial/Deposit',
      ..._cf,
    ],
    'Contacts': [],
    'Items': [],
    'Notes': [],
    'Settings': _settingsTab,
  },
  BillingDoc.credit: {
    'Details': [
      'Client',
      'Credit Number',
      'PO Number',
      'Credit Date',
      'Due Date',
      'Partial/Deposit',
      'Discount',
      ..._cf,
    ],
    'Contacts': [],
    'Items': [],
    'Notes': [],
    'Settings': _settingsTab,
  },
  BillingDoc.purchaseOrder: {
    'Details': [
      'Vendor',
      'PO Number',
      'Purchase Order Date',
      'Due Date',
      'Discount',
      ..._cf,
    ],
    'Contacts': [],
    'Items': [],
    'Notes': [],
    'Settings': ['Design', 'Project', 'Exchange Rate', 'User', 'Add tag'],
  },
  BillingDoc.recurringInvoice: {
    'Details': [
      'Client',
      'Recurring Number',
      'PO Number',
      'Discount',
      'Auto Bill',
      ..._cf,
    ],
    'Schedule': ['Frequency', 'Next Send Date', 'Remaining Cycles', 'Due Date'],
    'Contacts': [],
    'Items': [],
    'Notes': [],
    'Settings': _settingsTab,
  },
};

/// Tablet (900 px): the same tabbed layout plus a PDF tab (the header's
/// preview button is phone-only), and the Items tab switches to the wide
/// line-item table.
Map<String, List<String>> _tablet(BillingDoc doc) => {
  for (final MapEntry(key: tab, value: fields) in _phone[doc]!.entries)
    tab: tab == 'Items' ? _wideItemsTable : fields,
  'PDF': [],
};

/// Desktop (1440 px): every field on the card layout, in paint order.
const _desktop = <BillingDoc, List<String>>{
  BillingDoc.invoice: [
    'Client',
    'Invoice Date',
    'Due Date',
    'Partial/Deposit',
    'CF1',
    'CF3',
    'Invoice Number',
    'PO Number',
    'Discount',
    'CF2',
    'CF4',
    ..._wideItemsTable,
  ],
  BillingDoc.quote: [
    'Client',
    'Quote Date',
    'Valid Until',
    'Partial/Deposit',
    'CF1',
    'CF3',
    'Quote Number',
    'PO Number',
    'Discount',
    'CF2',
    'CF4',
    ..._wideItemsTable,
  ],
  BillingDoc.credit: [
    'Client',
    'Credit Date',
    'Due Date',
    'Partial/Deposit',
    'CF1',
    'CF3',
    'Credit Number',
    'PO Number',
    'Discount',
    'CF2',
    'CF4',
    ..._wideItemsTable,
  ],
  BillingDoc.purchaseOrder: [
    'Vendor',
    'Purchase Order Date',
    'Due Date',
    'CF1',
    'CF3',
    'PO Number',
    'Discount',
    'CF2',
    'CF4',
    ..._wideItemsTable,
  ],
  BillingDoc.recurringInvoice: [
    'Client',
    'Frequency',
    'Next Send Date',
    'Remaining Cycles',
    'Due Date',
    'CF1',
    'CF3',
    // NOTE: "Invoice Number" here but "Recurring Number" on mobile.
    'Invoice Number',
    'PO Number',
    'Discount',
    'Auto Bill',
    'CF2',
    'CF4',
    ..._wideItemsTable,
  ],
};

const _notesSubtabs = [
  'Terms',
  'Footer',
  'Public Notes',
  'Private Notes',
  'Settings',
];

/// The documents that grow an E-Invoice tab when the company enables it.
const _hasEInvoice = {
  BillingDoc.invoice,
  BillingDoc.credit,
  BillingDoc.recurringInvoice,
};

String _wire(BillingDoc doc) => switch (doc) {
  BillingDoc.invoice => 'invoice',
  BillingDoc.quote => 'quote',
  BillingDoc.credit => 'credit',
  BillingDoc.purchaseOrder => 'purchase_order',
  BillingDoc.recurringInvoice => 'recurring_invoice',
};

void main() {
  /// Mount [doc]'s layout at [width] over a fresh fixture. Tear-down is
  /// registered here; call [unmount] at the end of the test body.
  Future<ShellFixture> mount(
    WidgetTester tester,
    BillingDoc doc,
    double width, {
    bool eInvoice = false,
    void Function(GenericBillingDocEditViewModel<Object?> vm)? seed,
  }) async {
    setWindow(tester, width);
    final fixture = await buildFixture(
      closeStreamsSynchronously: true,
      companies: [
        FakeCompany(
          id: kHarnessCompanyId,
          name: 'Co',
          customFields: _customFields,
          settings: {if (eInvoice) 'enable_e_invoice': true},
        ),
      ],
    );
    addTearDown(fixture.dispose);
    // The edit screens pass `showPdfTab: !narrow`, narrow meaning < 600 px.
    // (This used to pass `width < 600` — the inverse — so the phone and
    // tablet expectations described each other's PDF tab.)
    final mounted = buildLayout(
      doc,
      fixture.services,
      showPdfTab: width >= 600,
    );
    addTearDown(mounted.vm.dispose);
    seed?.call(mounted.vm);
    await tester.pumpWidget(wrapWithShell(fixture.services, mounted.layout));
    await settle(tester);
    return fixture;
  }

  /// Field labels on every tab of the top strip, keyed by tab label.
  Future<Map<String, List<String>>> fieldsPerTab(WidgetTester tester) async {
    final tabs = tabBarLabels(tester).first;
    final result = <String, List<String>>{};
    for (var i = 0; i < tabs.length; i++) {
      await showTab(tester, i);
      result[tabs[i]] = fieldLabels(tester);
    }
    return result;
  }

  const timeout = Timeout(Duration(seconds: 60));

  for (final doc in BillingDoc.values) {
    group(doc.name, () {
      testWidgets('phone: tabs and the fields on each', (tester) async {
        final fixture = await mount(tester, doc, 390);
        expect(await fieldsPerTab(tester), _phone[doc]);
        await unmount(tester, fixture);
      }, timeout: timeout);

      testWidgets('tablet: no PDF tab, the wide items table', (tester) async {
        final fixture = await mount(tester, doc, 900);
        expect(await fieldsPerTab(tester), _tablet(doc));
        await unmount(tester, fixture);
      }, timeout: timeout);

      testWidgets('desktop: every card field and the notes sub-tabs', (
        tester,
      ) async {
        final fixture = await mount(tester, doc, 1440);
        expect(fieldLabels(tester), _desktop[doc]);
        expect(tabBarLabels(tester), [_notesSubtabs]);
        await unmount(tester, fixture);
      }, timeout: timeout);

      testWidgets(
        'e-invoicing adds a tab only where the entity supports it',
        (tester) async {
          final fixture = await mount(tester, doc, 390, eInvoice: true);
          final tabs = tabBarLabels(tester).first;
          expect(tabs, [
            ..._phone[doc]!.keys,
            if (_hasEInvoice.contains(doc)) 'E-Invoice',
          ]);
          await unmount(tester, fixture);
        },
        timeout: timeout,
      );

      testWidgets('e-invoicing adds a desktop notes sub-tab likewise', (
        tester,
      ) async {
        final fixture = await mount(tester, doc, 1440, eInvoice: true);
        expect(tabBarLabels(tester), [
          [..._notesSubtabs, if (_hasEInvoice.contains(doc)) 'E-Invoice'],
        ]);
        await unmount(tester, fixture);
      }, timeout: timeout);

      testWidgets('desktop picker FAB hero tag', (tester) async {
        final fixture = await mount(tester, doc, 1440);
        expect(
          tester
              .widgetList<BillingDocEditFab>(find.byType(BillingDocEditFab))
              .map((f) => f.heroTag),
          ['${_wire(doc)}_picker_fab'],
        );
        await unmount(tester, fixture);
      }, timeout: timeout);

      testWidgets('tablet Items-tab picker FAB hero tag', (tester) async {
        // Over the wide table only — phones add items inline, so there is no
        // FAB there at all (invoiceninja/flutter#142).
        final fixture = await mount(tester, doc, 900);
        await showTab(tester, tabBarLabels(tester).first.indexOf('Items'));
        expect(
          tester
              .widgetList<BillingDocEditFab>(find.byType(BillingDocEditFab))
              .map((f) => f.heroTag),
          ['${_wire(doc)}_picker_fab_mobile'],
        );
        await unmount(tester, fixture);
      }, timeout: timeout);
    });
  }

  group('invariants the copies have drifted on', () {
    for (final doc in BillingDoc.values) {
      testWidgets('${doc.name}: a line-item edit typed just before Save '
          'survives (tablet)', (tester) async {
        // On a tablet the wide line-item table renders inside the tabbed
        // layout, and its cells commit on a debounce. The before-save hooks
        // flush that debounce; a host that never registered them dropped
        // an edit saved within it. The purchase order's narrow Items tab
        // was that host.
        late GenericBillingDocEditViewModel<Object?> vm;
        final fixture = await mount(
          tester,
          doc,
          900,
          seed: (v) {
            vm = v;
            v.addLineItem(emptyLineItem().copyWith(notes: 'before'));
          },
        );
        await showTab(tester, tabBarLabels(tester).first.indexOf('Items'));
        final cell = find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'before',
        );
        expect(cell, findsOneWidget);

        await tester.enterText(cell, 'after');
        await vm.save(); // before the debounce fires — no pump in between

        expect(vm.lineItemsOf(vm.draft).single.notes, 'after');
        await unmount(tester, fixture);
      }, timeout: timeout);

      for (final width in [390.0, 1440.0]) {
        testWidgets('${doc.name}: every notes editor sits in a widget-order '
            'focus group (${width.toInt()} px)', (tester) async {
          // The `hasSize` focus crash (809e27b8): a TabBarView / ListView
          // leaves off-screen notes editors built but unlaid, and reading-order
          // traversal asks their focus nodes for a rect. That fix reached four
          // of the five layouts; the recurring invoice went without it.
          final fixture = await mount(tester, doc, width);
          if (width < 1024) {
            await showTab(tester, tabBarLabels(tester).first.indexOf('Notes'));
          }
          final editors = find.byType(MarkdownNotesField);
          expect(editors, findsWidgets);
          final guarded = [
            for (final editor in editors.evaluate())
              tester
                  .widgetList<FocusTraversalGroup>(
                    find.ancestor(
                      of: find.byWidget(editor.widget),
                      matching: find.byType(FocusTraversalGroup),
                    ),
                  )
                  .any((g) => g.policy is WidgetOrderTraversalPolicy),
          ];
          expect(guarded, everyElement(isTrue));
          await unmount(tester, fixture);
        }, timeout: timeout);
      }
    }
  });
}
