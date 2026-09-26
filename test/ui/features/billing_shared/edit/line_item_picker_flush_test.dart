// Opening the line-item picker commits a line edit still inside the table's
// 250 ms debounce. It used to read the draft as it was before the keystroke
// and write the picked rows over that — so type into a line, hit ⌘N or the
// `+` straight away, pick a product, and the typed line was gone.
//
// The commit is a FLUSH hook, not a before-save one: stripping the table's
// blank rows is save-only, or opening the picker and cancelling would delete a
// blank row the user had just inserted.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';

import '../../shell/_shell_test_helpers.dart';
import '_billing_edit_harness.dart';

void main() {
  Future<(ShellFixture, MountedLayout)> mount(WidgetTester tester) async {
    setWindow(tester, 1440);
    final fixture = await buildFixture(
      closeStreamsSynchronously: true,
      companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await fixture.db.productDao.upsertAll([
      ProductsCompanion.insert(
        id: 'p1',
        companyId: kHarnessCompanyId,
        productKey: 'Widget',
        notes: '',
        price: '10',
        cost: '0',
        quantity: '1',
        updatedAt: 1,
        payload: jsonEncode({'id': 'p1', 'product_key': 'Widget'}),
        customValue1: const Value(''),
      ),
    ]);
    final mounted = buildLayout(
      BillingDoc.invoice,
      fixture.services,
      showPdfTab: true,
    );
    addTearDown(mounted.vm.dispose);
    await tester.pumpWidget(wrapWithShell(fixture.services, mounted.layout));
    await settle(tester);
    return (fixture, mounted);
  }

  List<LineItem> lines(MountedLayout m) =>
      (m.vm.draft as dynamic).lineItems as List<LineItem>;

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byType(BillingDocEditFab));
    await settle(tester);
  }

  testWidgets('a line typed just before opening the picker is kept', (
    tester,
  ) async {
    final (fixture, m) = await mount(tester);
    final description = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText == 'Description' ||
              w.decoration?.labelText == 'Description'),
    );
    await tester.enterText(description.first, 'Consulting');
    expect(lines(m), isEmpty, reason: 'still inside the debounce');

    await tester.tap(find.byType(BillingDocEditFab));
    expect(lines(m).map((l) => l.notes), ['Consulting']);
    await settle(tester);

    await tester.tap(find.text('Widget').last);
    await settle(tester);
    await tester.tap(find.text('Add').last);
    await settle(tester);

    expect(lines(m).map((l) => l.notes.isEmpty ? l.productKey : l.notes), [
      'Consulting',
      'Widget',
    ]);
    await unmount(tester, fixture);
  });

  testWidgets('a blank row survives a cancelled picker; a save strips it', (
    tester,
  ) async {
    final (fixture, m) = await mount(tester);
    m.vm.addLineItem(emptyLineItem());
    await settle(tester);

    await openPicker(tester);
    await tester.tap(find.text('Cancel').last);
    await settle(tester);
    expect(lines(m), hasLength(1));

    await m.vm.save();
    await settle(tester);
    expect(lines(m), isEmpty);
    await unmount(tester, fixture);
  });
}
