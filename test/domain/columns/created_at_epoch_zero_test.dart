import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';

import 'package:admin/data/db/dao/product_dao.dart' show ProductFieldIds;
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/product_columns.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;

import '../../_localization_helper.dart';

/// Epoch 0 in `created_at` means "not set", not 1 Jan 1970 — the Drift column
/// is `withDefault(const Constant(0))`, so a row written before the column was
/// backfilled, or one whose server genuinely sent 0, must render blank.
///
/// `colCreatedAt` guards exactly this. Clients, Products and Vendors
/// hand-rolled the column instead and called `cellDate` unconditionally, so
/// the same record painted a date on those three lists and an em-dash on the
/// other eleven. Nothing compared the fourteen definitions, which is why it
/// stood; `column_factories_used_test` now stops a fifteenth copy.
Future<String> _render<T>(
  WidgetTester tester,
  ColumnDefinition<T> column,
  T entity,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Builder(builder: (ctx) => column.cellBuilder(entity, ctx)),
      ),
    ),
  );
  return tester.widget<Text>(find.byType(Text)).data ?? '';
}

void main() {
  setUpAll(initializeDateFormatting);

  final epoch0 = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  testWidgets('Client created_at at epoch 0 renders blank', (tester) async {
    expect(
      await _render(
        tester,
        clientColumnsById[ClientFieldIds.createdAt]!,
        emptyClient().copyWith(createdAt: epoch0),
      ),
      '—',
    );
  });

  testWidgets('Product created_at at epoch 0 renders blank', (tester) async {
    expect(
      await _render(
        tester,
        productColumnsById[ProductFieldIds.createdAt]!,
        emptyProductWithKey('k').copyWith(createdAt: epoch0),
      ),
      '—',
    );
  });

  testWidgets('Vendor created_at at epoch 0 renders blank', (tester) async {
    expect(
      await _render(
        tester,
        vendorColumnsById[VendorFieldIds.createdAt]!,
        emptyVendor().copyWith(createdAt: epoch0),
      ),
      '—',
    );
  });
}
