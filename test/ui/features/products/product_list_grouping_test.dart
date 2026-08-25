// Products list grouping (issue #56) — the ViewModel half.
//
// Custom-field grouping is a SQL ORDER BY prefix (covered in
// `product_dao_grouping_test.dart`); this file covers what only the VM can
// do: regrouping by tag over the loaded window, the group labels/counts the
// section headers read, and degrading a grouping choice that has gone stale.

import 'dart:async';
import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/products_api.dart';
import 'package:admin/ui/features/products/view_models/product_list_view_model.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProductsApi implements ProductsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

Tag _tag(String id, String name) => Tag(
  id: id,
  entityType: 'product',
  name: name,
  color: '',
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
);

void main() {
  late AppDatabase db;
  late ProductRepository repo;
  const co = 'co_1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepository(db: db, api: _FakeProductsApi());
  });
  tearDown(() async => db.close());

  Future<void> product(
    String id, {
    String custom1 = '',
    List<String> tagIds = const [],
  }) => db.productDao.upsertAll([
    ProductsCompanion.insert(
      id: id,
      companyId: co,
      productKey: id,
      notes: '',
      price: '0',
      cost: '0',
      quantity: '1',
      updatedAt: 1,
      // The repo decodes the domain model from `payload`; the columns only
      // drive SQL filtering/ordering. Both have to agree, exactly as a real
      // upsert from the API writes them.
      payload: jsonEncode({
        'id': id,
        'product_key': id,
        'custom_value1': custom1,
        'tags': tagIds,
      }),
      customValue1: Value(custom1),
    ),
  ]);

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // Broadcast so a test can push a second company (e.g. one that has
  // un-configured the custom-field slot) after the VM is built.
  late StreamController<Company?> companies;

  /// Lets a test hold the tag names back until after the products stream has
  /// emitted — the cold-start ordering that used to render one big
  /// "Uncategorized" group.
  late StreamController<List<Tag>> tagEvents;

  ProductListViewModel build({
    Company? company,
    List<Tag> tags = const [],
    bool withTagStream = true,
    bool deferTags = false,
  }) {
    companies = StreamController<Company?>.broadcast();
    tagEvents = StreamController<List<Tag>>.broadcast();
    final vm = ProductListViewModel(
      repo: repo,
      companyId: co,
      companyStream: companies.stream,
      // A factory: the VM folds this into its page stream and rebuilds it on
      // every re-subscribe, so it must hand back a fresh stream each call.
      tagStream: withTagStream
          ? (deferTags
                ? () => tagEvents.stream
                : () => Stream<List<Tag>>.value(tags))
          : null,
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      persistDebounce: const Duration(milliseconds: 1),
    );
    companies.add(company);
    return vm;
  }

  Company companyWithCategory({String label = 'Category'}) => Company(
    customFields: label.isEmpty
        ? const {}
        : {'product1': '$label|Hardware,Software'},
  );

  test(
    'groups by a custom field, blanks labelled empty and sorted last',
    () async {
      await product('z', custom1: 'Software');
      await product('a', custom1: 'Hardware');
      await product('n');
      final vm = build(company: companyWithCategory());
      await settle();
      await vm.setGroupField(ProductFieldIds.custom1);
      await settle();

      expect(vm.items.map((p) => p.productKey), ['a', 'z', 'n']);
      expect(vm.groupLabelAt(0), 'Hardware');
      expect(vm.groupLabelAt(1), 'Software');
      // `''` is the stored key; the screen renders it as "Uncategorized" so a
      // folded group survives a language change.
      expect(vm.groupLabelAt(2), '');
      expect(vm.isGroupStart(0), isTrue);
      expect(vm.isGroupStart(1), isTrue);
      vm.dispose();
    },
  );

  test('isGroupStart is false for a row continuing its group', () async {
    await product('a1', custom1: 'Hardware');
    await product('a2', custom1: 'Hardware');
    final vm = build(company: companyWithCategory());
    await settle();
    await vm.setGroupField(ProductFieldIds.custom1);
    await settle();

    expect(vm.isGroupStart(0), isTrue);
    expect(vm.isGroupStart(1), isFalse);
    expect(vm.groupCount('Hardware'), 2);
    vm.dispose();
  });

  test('tag grouping is stable and puts untagged rows last', () async {
    // Insert so the default product_key sort gives b1, b2, n, z1.
    await product('b1', tagIds: ['t_b']);
    await product('b2', tagIds: ['t_b']);
    await product('n');
    await product('z1', tagIds: ['t_a']);
    final vm = build(
      company: companyWithCategory(),
      tags: [_tag('t_a', 'Alpha'), _tag('t_b', 'Beta')],
    );
    await settle();
    await vm.setGroupField(kProductGroupTags);
    await settle();

    // Alpha before Beta, untagged last — and `b1` still precedes `b2`, which
    // an unstable sort would be free to swap.
    expect(vm.items.map((p) => p.productKey), ['z1', 'b1', 'b2', 'n']);
    expect(vm.groupLabelAt(0), 'Alpha');
    expect(vm.groupLabelAt(1), 'Beta');
    expect(vm.groupLabelAt(3), '');
    vm.dispose();
  });

  test(
    'a multi-tagged row is filed under its first tag alphabetically',
    () async {
      await product('m', tagIds: ['t_b', 't_a']);
      final vm = build(
        company: companyWithCategory(),
        tags: [_tag('t_a', 'Alpha'), _tag('t_b', 'Beta')],
      );
      await settle();
      await vm.setGroupField(kProductGroupTags);
      await settle();

      expect(vm.items.length, 1);
      expect(vm.groupLabelAt(0), 'Alpha');
      vm.dispose();
    },
  );

  test('collapsing a group hides exactly its rows', () async {
    await product('a', custom1: 'Hardware');
    await product('z', custom1: 'Software');
    final vm = build(company: companyWithCategory());
    await settle();
    await vm.setGroupField(ProductFieldIds.custom1);
    await settle();

    expect(vm.hasHiddenRows, isFalse);
    vm.toggleGroupCollapsed('Hardware');
    expect(vm.hasHiddenRows, isTrue);
    expect(vm.isRowHidden(0), isTrue);
    expect(vm.isRowHidden(1), isFalse);
    vm.dispose();
  });

  test('a slot that is no longer configured stops grouping WITHOUT erasing '
      'the choice', () async {
    await product('a', custom1: 'Hardware');
    final vm = build(company: companyWithCategory());
    await settle();
    await vm.setGroupField(ProductFieldIds.custom1);
    await settle();
    expect(vm.effectiveGroupField, ProductFieldIds.custom1);

    // The company un-configures the slot. Grouping must stop rendering (it
    // would otherwise be one nameless section) — but the preference must
    // survive: an empty `custom_fields` map is also what a company response
    // that merely omits the key writes, so it is not a trustworthy signal to
    // destroy user state on.
    companies.add(companyWithCategory(label: ''));
    await settle();
    expect(vm.effectiveGroupField, isNull);
    expect(vm.groupField, ProductFieldIds.custom1);

    // ...and it comes back by itself once the slot is reconfigured.
    companies.add(companyWithCategory());
    await settle();
    expect(vm.effectiveGroupField, ProductFieldIds.custom1);
    vm.dispose();
  });

  test('an unknown persisted group id renders ungrouped', () async {
    await product('a', custom1: 'Hardware');
    final vm = build(company: companyWithCategory());
    await settle();
    await vm.setGroupField('custom9'); // hand-edited / future-version blob
    await settle();
    expect(vm.effectiveGroupField, isNull);
    vm.dispose();
  });

  test(
    'tag names arriving after the first product emission still group',
    () async {
      // The cold-start race: `nav_state` restores tag grouping, the products
      // stream emits before the tag cache lands. Folding the tag stream into the
      // page stream is what makes this deterministic — `notifyListeners()` alone
      // could never re-run the grouping map.
      await product('b1', tagIds: ['t_b']);
      await product('z1', tagIds: ['t_a']);
      final vm = build(company: companyWithCategory(), deferTags: true);
      await settle();
      await vm.setGroupField(kProductGroupTags);
      await settle();

      // Nothing painted yet — the combine waits for both sources.
      tagEvents.add([_tag('t_a', 'Alpha'), _tag('t_b', 'Beta')]);
      await settle();
      expect(vm.items.map((p) => p.productKey), ['z1', 'b1']);
      expect(vm.groupLabelAt(0), 'Alpha');
      expect(vm.groupLabelAt(1), 'Beta');
      vm.dispose();
    },
  );

  test('renaming a tag re-labels its group', () async {
    await product('b1', tagIds: ['t_b']);
    final vm = build(company: companyWithCategory(), deferTags: true);
    await settle();
    await vm.setGroupField(kProductGroupTags);
    tagEvents.add([_tag('t_b', 'Beta')]);
    await settle();
    expect(vm.groupLabelAt(0), 'Beta');

    tagEvents.add([_tag('t_b', 'Aardvark')]);
    await settle();
    expect(vm.groupLabelAt(0), 'Aardvark');
    vm.dispose();
  });

  test('tag names differing only in case stay contiguous', () async {
    // The comparator used to be inconsistent here (cmp(A,a)==0, cmp(a,A)==0,
    // but cmp(A,A')==-1), which voids `List.sort`'s contract entirely.
    await product('p1', tagIds: ['t_up']);
    await product('p2', tagIds: ['t_lo']);
    await product('p3', tagIds: ['t_up']);
    final vm = build(
      company: companyWithCategory(),
      tags: [_tag('t_up', 'Retail'), _tag('t_lo', 'retail')],
    );
    await settle();
    await vm.setGroupField(kProductGroupTags);
    await settle();

    final labels = [
      for (var i = 0; i < vm.items.length; i++) vm.groupLabelAt(i),
    ];
    // Each spelling forms ONE run — interleaving would render a header per row
    // and make collapsing one hide non-adjacent rows.
    expect(labels, ['Retail', 'Retail', 'retail']);
    vm.dispose();
  });

  test(
    'the active dimension stays offered once its data leaves the window',
    () async {
      // No tagged row loaded (a filter narrowed them away, or they page in
      // later), so the "has data" rule alone would drop `tags` from the menu —
      // and with an empty list BOTH surfaces hide themselves, leaving the list
      // grouped with no control left to switch it off.
      final vm = build(
        company: Company(), // no custom fields configured either
        tags: [_tag('t_a', 'Alpha')],
      );
      await settle();
      expect(vm.availableGroupFieldIds, isEmpty);

      await vm.setGroupField(kProductGroupTags);
      await settle();
      expect(vm.items, isEmpty);
      expect(vm.availableGroupFieldIds, [kProductGroupTags]);
      vm.dispose();
    },
  );

  test('collapsing a group drops its rows from the selection', () async {
    await product('a', custom1: 'Hardware');
    await product('z', custom1: 'Software');
    final vm = build(company: companyWithCategory());
    await settle();
    await vm.setGroupField(ProductFieldIds.custom1);
    await settle();

    vm.enterSelectionMode();
    vm.selectAllVisible();
    expect(vm.selectedItems.length, 2);

    // Otherwise a bulk delete sweeps records the user can no longer see.
    vm.toggleGroupCollapsed('Hardware');
    expect(vm.selectedItems.map((p) => p.productKey), ['z']);
    vm.dispose();
  });

  test('only populated + configured dimensions are offered', () async {
    await product('a', custom1: 'Hardware');
    await product('t', tagIds: ['t_a']);
    final vm = build(
      company: companyWithCategory(),
      tags: [_tag('t_a', 'Alpha')],
    );
    await settle();
    expect(vm.availableGroupFieldIds, [
      ProductFieldIds.custom1,
      kProductGroupTags,
    ]);
    expect(vm.groupFieldLabel(ProductFieldIds.custom1), 'Category');
    vm.dispose();
  });

  test('an unconfigured or unpopulated custom slot is not offered', () async {
    // Configured, but no product carries a value.
    await product('a');
    final vm = build(company: companyWithCategory());
    await settle();
    expect(vm.availableGroupFieldIds, isEmpty);
    vm.dispose();
  });

  test('tags are not offered without a tag source', () async {
    await product('t', tagIds: ['t_a']);
    final vm = build(company: companyWithCategory(), withTagStream: false);
    await settle();
    expect(vm.availableGroupFieldIds.contains(kProductGroupTags), isFalse);
    vm.dispose();
  });

  test('a grouping restored from nav_state re-points the QUERY, not just the '
      'labels', () async {
    // The company's custom-field label is what makes a `custom*` grouping
    // *effective*, and it arrives on the company stream — after the base VM's
    // constructor has already run `_init()` → `watchPage()`. That call bakes
    // the DAO's grouping ORDER BY prefix in at subscribe time, while
    // `_recomputeGroups` re-reads `effectiveGroupField` every emission. Before
    // the fix the restored grouping produced labels over an UNGROUPED query,
    // so one category rendered as a header per contiguous run.
    //
    // Ordered by `product_key` the categories interleave (a=H, b=S, c=H);
    // grouped they don't (a, c, then b). That is the discriminator.
    await product('a', custom1: 'Hardware');
    await product('b', custom1: 'Software');
    await product('c', custom1: 'Hardware');
    await db.navStateDao.saveFilters(
      filtersJson: jsonEncode({
        co: {
          'product': {'groupField': ProductFieldIds.custom1},
        },
      }),
      now: 1,
    );

    // No company yet — exactly what `_subscribe()` sees in production, where
    // `_hydrate`'s nav_state read is queued on the Drift executor ahead of the
    // company watch.
    final vm = build(company: null);
    await settle();
    expect(vm.groupField, ProductFieldIds.custom1, reason: 'hydrated');
    expect(vm.effectiveGroupField, isNull, reason: 'no company label yet');

    companies.add(companyWithCategory());
    await settle();

    expect(vm.effectiveGroupField, ProductFieldIds.custom1);
    expect(vm.items.map((p) => p.productKey), ['a', 'c', 'b']);
    expect(
      [for (var i = 0; i < 3; i++) vm.isGroupStart(i)],
      [true, false, true],
    );
    vm.dispose();
  });

  test('renaming a tag repaints the header even though no row moved', () async {
    // Drift streams are table-scoped, so a write to `tags` re-emits only the
    // tag half of the combine — carrying the SAME product list. The base VM
    // skips its `notifyListeners()` on a value-identical emission, so the
    // label moved and the header didn't.
    await product('p1', tagIds: ['t_a']);
    await product('p2', tagIds: ['t_b']);
    final vm = build(company: companyWithCategory(), deferTags: true);
    await settle();
    await vm.setGroupField(kProductGroupTags);
    await settle();
    tagEvents.add([_tag('t_a', 'Alpha'), _tag('t_b', 'Beta')]);
    await settle();
    expect(vm.groupLabelAt(1), 'Beta', reason: 'precondition');

    var notified = 0;
    vm.addListener(() => notified++);
    // Beta -> Bravo keeps the alphabetical order, so the row list is
    // byte-identical and the base VM has nothing to announce.
    tagEvents.add([_tag('t_a', 'Alpha'), _tag('t_b', 'Bravo')]);
    await settle();

    expect(vm.items.map((p) => p.productKey), ['p1', 'p2'], reason: 'no move');
    expect(vm.groupLabelAt(1), 'Bravo');
    expect(notified, greaterThan(0), reason: 'the header has to repaint');
    vm.dispose();
  });
}
