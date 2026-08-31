import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/domain/columns/payment_link_columns.dart';
import 'package:admin/domain/columns/project_columns.dart';
import 'package:admin/domain/columns/quote_columns.dart';
import 'package:admin/domain/columns/recurring_expense_columns.dart';

/// The company-aware half of invoiceninja/flutter#106.
///
/// A list column for a custom-field slot has to answer three questions the
/// registry alone can't: what the company calls it, how the value renders, and
/// whether the slot exists at all. `decorateCustomFieldColumns` is where all
/// three are answered, so this pins its contract.
Company _company(Map<String, String> fields) => Company(customFields: fields);

Project _project({String customValue2 = ''}) => Project.fromApi(
  ProjectApi(id: 'p1', name: 'P', customValue2: customValue2),
);

List<String> _ids<T>(List<ColumnDefinition<T>> columns) => [
  for (final c in columns) c.id,
];

void main() {
  group('customFieldColumns', () {
    test('builds four slots carrying the company key, not the entity name', () {
      final columns = kAllProjectColumns
          .where((c) => c.customField != null)
          .toList();
      expect(columns, hasLength(4));
      expect(
        [for (final c in columns) c.customField!.companyKey],
        ['project1', 'project2', 'project3', 'project4'],
      );
      // Wire ids stay `custom1..4` — legacy `ProjectFields` and this app's own
      // `custom1:` search-filter tokens both use them, and a stored
      // `table_columns` list is shared with the old admin-portal.
      expect(_ids(columns), ['custom1', 'custom2', 'custom3', 'custom4']);
      expect(columns.every((c) => c.label == null), isTrue);
      expect(columns.every((c) => c.width == 140), isTrue);
    });

    test('quotes read the invoice slots, not a `quote` prefix', () {
      final keys = [
        for (final c in kAllQuoteColumns)
          if (c.customField != null) c.customField!.companyKey,
      ];
      expect(keys, ['invoice1', 'invoice2', 'invoice3', 'invoice4']);
    });

    test('recurring expenses read the expense slots', () {
      final keys = [
        for (final c in kAllRecurringExpenseColumns)
          if (c.customField != null) c.customField!.companyKey,
      ];
      expect(keys, ['expense1', 'expense2', 'expense3', 'expense4']);
    });
  });

  group('decorateCustomFieldColumns', () {
    test('a registry with no slots is returned by identity', () {
      // The 7 slot-free entities must not pay an allocation per resolve.
      final decorated = decorateCustomFieldColumns(
        kAllPaymentLinkColumns,
        _company(const {'client1': 'Region'}),
      );
      expect(identical(decorated, kAllPaymentLinkColumns), isTrue);
    });

    test('a null company hides every slot and keeps everything else', () {
      final decorated = decorateCustomFieldColumns(kAllProjectColumns, null);
      expect(decorated.any((c) => c.customField != null), isFalse);
      expect(
        decorated.length,
        kAllProjectColumns.length - 4,
        reason: 'only the four slots are dropped',
      );
      expect(_ids(decorated), contains(ProjectFieldIds.name));
    });

    test('only configured slots survive, and they keep registry order', () {
      final decorated = decorateCustomFieldColumns(
        kAllProjectColumns,
        _company(const {'project1': 'Region', 'project3': 'Phase|date'}),
      );
      final ids = _ids(decorated);
      expect(ids, contains('custom1'));
      expect(ids, contains('custom3'));
      expect(ids, isNot(contains('custom2')));
      expect(ids, isNot(contains('custom4')));
      // Position is preserved: still after `color`, still before the metadata
      // block that ends the registry.
      expect(ids.indexOf('custom1'), lessThan(ids.indexOf('custom3')));
      expect(
        ids.indexOf('custom3'),
        lessThan(ids.indexOf(ProjectFieldIds.entityState)),
      );
    });

    test("the header carries the company's label, not the wire key", () {
      final decorated = decorateCustomFieldColumns(
        kAllProjectColumns,
        _company(const {'project1': 'Region|North,South'}),
      );
      final column = decorated.firstWhere((c) => c.id == 'custom1');
      expect(column.label, 'Region');
      // `labelKey` is untouched, so an undecorated render still works.
      expect(column.labelKey, 'custom1');
    });

    test('sortability and the copy value survive decoration', () {
      final decorated = decorateCustomFieldColumns(
        kAllProjectColumns,
        _company(const {'project1': 'Region', 'project2': 'Signed|switch'}),
      );
      // Real Drift columns — the DAO has cases for all four.
      expect(decorated.firstWhere((c) => c.id == 'custom1').sortable, isTrue);
      expect(decorated.firstWhere((c) => c.id == 'custom2').sortable, isTrue);
      // The hover-copy value stays canonical even for a switch slot: it is
      // what round-trips back into the field, like a money cell copying
      // `1234.50` while showing `$1,234.50`.
      final project = _project(customValue2: 'yes');
      expect(
        decorated.firstWhere((c) => c.id == 'custom2').valueBuilder!(project),
        'yes',
      );
    });
  });

  group('customFieldColumnSignature', () {
    test('is stable for the same configuration', () {
      final company = _company(const {'project1': 'Region'});
      expect(
        customFieldColumnSignature(kAllProjectColumns, company),
        customFieldColumnSignature(kAllProjectColumns, company),
      );
    });

    test('changes when a label is renamed', () {
      expect(
        customFieldColumnSignature(
          kAllProjectColumns,
          _company(const {'project1': 'Region'}),
        ),
        isNot(
          customFieldColumnSignature(
            kAllProjectColumns,
            _company(const {'project1': 'Area'}),
          ),
        ),
      );
    });

    test('changes when only the TYPE changes', () {
      // The load-bearing case. A label-only signature (all the Products
      // grouping needs) would never repaint here, leaving a switch column
      // rendering raw `yes` after the admin flipped the slot to a date.
      expect(
        customFieldColumnSignature(
          kAllProjectColumns,
          _company(const {'project1': 'Region|switch'}),
        ),
        isNot(
          customFieldColumnSignature(
            kAllProjectColumns,
            _company(const {'project1': 'Region|date'}),
          ),
        ),
      );
    });

    test('changes when the company arrives', () {
      expect(
        customFieldColumnSignature(kAllProjectColumns, null),
        isNot(
          customFieldColumnSignature(
            kAllProjectColumns,
            _company(const {'project1': 'Region'}),
          ),
        ),
      );
    });
  });
}
