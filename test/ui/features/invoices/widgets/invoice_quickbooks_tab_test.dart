import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_record_page.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_quickbooks_tab.dart';

import '../../../../_localization_helper.dart';

/// Without a check result the tab reads nothing from `Services`.
class _ThrowingServices implements Services {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('the QuickBooks tab lays out inside the record page', (
    tester,
  ) async {
    // A detail tab body is laid out at its intrinsic height inside the
    // record page's scroll view. This tab's body was a `ListView`, which has
    // no height to fill there: "Vertical viewport was given unbounded
    // height", so the tab rendered nothing at all.
    final invoice = Invoice.fromApi(
      const InvoiceApi(id: 'inv1', number: '0001', clientId: 'c1'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: EntityDetailTabs(
            tabs: [
              EntityDetailTab(
                id: 'quickbooks',
                label: 'QuickBooks',
                icon: Icons.sync_alt_outlined,
                bodyBuilder: (_) => InvoiceQuickbooksTab(
                  invoice: invoice,
                  services: _ThrowingServices(),
                  companyId: 'co1',
                  quickbooks: null,
                ),
              ),
            ],
            layoutBuilder: (context, strip, body) => EntityRecordPage(
              tabStrip: strip,
              tabBody: body,
              top: const SizedBox(height: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final row = find.byType(DetailInfoRow).first;
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThan(0));
  });
}
