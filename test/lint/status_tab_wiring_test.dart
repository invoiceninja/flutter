import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';

/// Source-level guards for the status-tab wiring (invoiceninja/flutter#98).
///
/// Scanned rather than exercised because every failure here is **silent at
/// runtime**: the strip still renders, the tabs still highlight, the counts are
/// still right — the list just doesn't narrow. Nothing throws, and it looks
/// entirely plausible on a small account where most rows match the tab anyway.
/// Reaching these paths for real needs the whole app graph, the same reason
/// `list_pagination_wiring_test.dart` is written this way.
/// `EntityType.recurringInvoice` → `recurring_invoice`, matching the file
/// naming convention for list ViewModels.
String _fileStem(EntityType type) => type.name.replaceAllMapped(
  RegExp(r'[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

void main() {
  /// Every list ViewModel that renders a strip. The three settings-hosted lists
  /// (expense categories, gateways, payment links) declare no status counters,
  /// so `kListStatusTabs` has no entry for them and they get no strip.
  const settingsHosted = {
    'expense_category',
    'company_gateway',
    'payment_link',
  };

  final vmFiles = Directory('lib/ui/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_list_view_model.dart'))
      .where(
        (f) => !settingsHosted.any(
          (s) => f.path.endsWith('${s}_list_view_model.dart'),
        ),
      )
      .toList();

  test('the scan finds every list ViewModel whose entity declares tabs', () {
    // Derived from the registry, not a magic number: hard-coding the count
    // breaks the day someone adds a list for an entity with no status
    // counters, which is a false alarm rather than a regression. Comparing
    // against `kListStatusTabs` also keeps the scan from going vacuously green
    // if these files are ever renamed or moved.
    final scanned = {
      for (final f in vmFiles)
        f.uri.pathSegments.last.replaceAll('_list_view_model.dart', ''),
    };
    final expected = {for (final type in kListStatusTabs.keys) _fileStem(type)};
    expect(scanned, expected);
  });

  for (final file in vmFiles) {
    final name = file.uri.pathSegments.last;
    test('$name forwards the selected tab into its Drift watch', () {
      final src = file.readAsStringSync();
      // Match the override's signature, not a bare mention — Products talks
      // about `watchPage()` in a comment well above its own override.
      final start =
          RegExp(r'Stream<List<\w+>> watchPage\(\)').firstMatch(src)?.start ??
          -1;
      expect(start, isNot(-1), reason: '$name has no watchPage() override');
      // Slice to the next member rather than a fixed budget, matching the
      // idiom in list_pagination_wiring_test.
      final end = src.indexOf('@override', start);
      final body = src.substring(start, end == -1 ? src.length : end);
      expect(
        body.contains('badgeModeId: activeBadgeModeId'),
        isTrue,
        reason:
            '$name drops the status tab on the floor: the strip switches and '
            'the count is right, but the rows underneath never narrow.',
      );
    });
  }

  test('the DAO helper and the count share one predicate', () {
    // The whole feature rests on this: if badgeModeListFilter ever stops
    // delegating to badgeModePredicate, the tab and its badge can disagree.
    final dao = File('lib/data/db/dao/base_entity_dao.dart').readAsStringSync();
    final start = dao.indexOf('Expression<bool>? badgeModeListFilter(');
    expect(start, isNot(-1), reason: 'badgeModeListFilter not found');
    // Slice to the next doc comment — the method's own `}) {` would match a
    // naive close-brace search.
    final end = dao.indexOf('\n  /// ', start);
    final body = dao.substring(start, end == -1 ? dao.length : end);
    expect(body.contains('badgeModePredicate('), isTrue);
  });

  test('the clients screen still feeds the Overdue tab its invoices', () {
    // #119. `ClientListViewModel.invoices` is nullable so tests needn't build
    // an InvoiceRepository, which means deleting this one wiring line is
    // completely silent: the strip renders, the tab highlights, the count is
    // "right" — it is just computed against whatever slice of the invoices
    // table happens to be cached, which after a fresh login is the 50 newest.
    // Exactly the class of failure this file exists for.
    final screen = File(
      'lib/ui/features/clients/views/client_list_screen.dart',
    ).readAsStringSync();
    expect(
      screen.contains('invoices: services.invoices'),
      isTrue,
      reason:
          'ClientListViewModel needs the invoice repo to hydrate the rows its '
          'overdue predicate subqueries',
    );
  });

  test('badge_mode never reaches the wire', () {
    // The strip's key is a SidebarBadgeMode id, not a query param. Sending it
    // would also flip isNarrowedFetch and disable the delta cursor for a filter
    // the server silently ignores.
    final vm = File(
      'lib/ui/core/list/generic_list_view_model.dart',
    ).readAsStringSync();
    final start = vm.indexOf('Map<String, Set<String>> _serverExtraFilters()');
    expect(start, isNot(-1), reason: '_serverExtraFilters not found');
    final end = vm.indexOf('\n  /// ', start);
    final body = vm.substring(start, end == -1 ? vm.length : end);
    expect(
      body.contains('merged.remove(kBadgeModeFilterKey)'),
      isTrue,
      reason: 'the app-private tab key must be stripped before every fetch',
    );
  });
}
