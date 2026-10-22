// `createVendorInline` — the picker's "Create «name»" for vendors. The rules
// worth pinning: an exact name the server already has is selected, not
// duplicated; an archived one is refused; and neither being offline nor a
// stalled connection blocks the create for long.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_inline_create.dart';

import '../../../_localization_helper.dart';

/// [local] is the device cache; [server] is what a search fetch would land in
/// it. `ensurePageLoaded` throws while [failing], as a failed fetch does, and
/// never completes while [stalled].
class _FakeVendors implements VendorRepository {
  _FakeVendors({this.local = const [], this.server = const []});

  List<Vendor> local;
  final List<Vendor> server;
  bool failing = false;
  bool stalled = false;
  int fetches = 0;

  /// The page [server] lands on, and how many pages the search has in all.
  int serverPage = 1;
  int lastPage = 1;
  final created = <Vendor>[];

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    fetches++;
    if (failing) throw Exception('offline');
    if (stalled) return Completer<bool>().future;
    if (page == serverPage) local = [...local, ...server];
    return page < lastPage;
  }

  @override
  Stream<List<Vendor>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = 'name',
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
    String? badgeModeId,
  }) => Stream.value(
    local
        .where(
          (v) =>
              search == null ||
              v.name.toLowerCase().contains(search.toLowerCase()),
        )
        .toList(),
  );

  @override
  Future<SaveResult<Vendor>> create({
    required String companyId,
    required Vendor draft,
    String? existingTempId,
  }) async {
    final stored = draft.copyWith(id: 'tmp_${created.length}');
    created.add(stored);
    return SaveResult(entity: stored, outboxRowId: created.length);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeCompany implements CompanyRepository {
  @override
  Future<Company?> get(String companyId) async => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.vendors, {bool online = true})
    : connectivity = ConnectivityWatcher.fixed(online: online);

  @override
  final VendorRepository vendors;

  @override
  final ConnectivityWatcher connectivity;

  @override
  final CompanyRepository company = _FakeCompany();

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

Vendor _vendor(String id, String name, {bool archived = false}) =>
    emptyVendor().copyWith(
      id: id,
      name: name,
      archivedAt: archived ? DateTime.utc(2026) : null,
    );

void main() {
  late BuildContext ctx;

  Future<void> host(
    WidgetTester tester,
    _FakeVendors vendors, {
    bool online = true,
  }) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(vendors, online: online),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Future<Vendor?> run(WidgetTester tester, String query) async {
    final result = createVendorInline(ctx, companyId: 'c1', query: query);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('creates a vendor from the typed name', (tester) async {
    final vendors = _FakeVendors();
    await host(tester, vendors);
    final v = await run(tester, '  Acme Supply ');
    expect(vendors.created.map((v) => v.name), ['Acme Supply']);
    expect(v?.id, 'tmp_0');
  });

  testWidgets('an exact match only the server knows is selected, not '
      'duplicated', (tester) async {
    final vendors = _FakeVendors(server: [_vendor('v9', 'ACME Supply')]);
    await host(tester, vendors);
    final v = await run(tester, 'acme supply');
    expect(vendors.created, isEmpty);
    expect(v?.id, 'v9');
  });

  testWidgets('an exact match on a later search page is still found', (
    tester,
  ) async {
    // The server's vendor search is broad, so a short name's exact match can
    // sit past page 1.
    final vendors = _FakeVendors(server: [_vendor('v9', 'Co')])
      ..serverPage = 3
      ..lastPage = 5;
    await host(tester, vendors);
    final v = await run(tester, 'co');
    expect(vendors.fetches, 3);
    expect(vendors.created, isEmpty);
    expect(v?.id, 'v9');
  });

  testWidgets('a partial match is not a duplicate', (tester) async {
    final vendors = _FakeVendors(local: [_vendor('v1', 'Acme Supply Co')]);
    await host(tester, vendors);
    await run(tester, 'Acme Supply');
    expect(vendors.created.map((v) => v.name), ['Acme Supply']);
  });

  testWidgets('a failed search still lets the create happen', (tester) async {
    final vendors = _FakeVendors()..failing = true;
    await host(tester, vendors);
    final v = await run(tester, 'Acme');
    expect(v?.name, 'Acme');
    expect(vendors.created, hasLength(1));
  });

  testWidgets('offline, the server is not asked at all', (tester) async {
    final vendors = _FakeVendors();
    await host(tester, vendors, online: false);
    final v = await run(tester, 'Acme');
    expect(vendors.fetches, 0);
    expect(v?.name, 'Acme');
  });

  testWidgets('a stalled search gives up after the timeout and creates', (
    tester,
  ) async {
    final vendors = _FakeVendors()..stalled = true;
    await host(tester, vendors);
    final result = createVendorInline(ctx, companyId: 'c1', query: 'Acme');
    await tester.pump(const Duration(seconds: 1));
    expect(vendors.created, isEmpty);
    await tester.pump(kVendorDuplicateSearchTimeout);
    await tester.pumpAndSettle();
    expect((await result)?.name, 'Acme');
  });

  testWidgets('an archived vendor with the same name blocks the create', (
    tester,
  ) async {
    final vendors = _FakeVendors(
      local: [_vendor('v1', 'Acme', archived: true)],
    );
    await host(tester, vendors);
    final v = await run(tester, 'acme');
    expect(v, isNull);
    expect(vendors.created, isEmpty);
  });

  testWidgets('an active namesake wins over an archived one', (tester) async {
    final vendors = _FakeVendors(
      local: [_vendor('v1', 'Acme', archived: true), _vendor('v2', 'Acme')],
    );
    await host(tester, vendors);
    final v = await run(tester, 'Acme');
    expect(v?.id, 'v2');
  });

  testWidgets('an empty query asks for the name first', (tester) async {
    final vendors = _FakeVendors();
    await host(tester, vendors);
    final result = createVendorInline(ctx, companyId: 'c1', query: '');
    await tester.pumpAndSettle();
    expect(find.text('New Vendor'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Globex');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await result)?.name, 'Globex');
  });

  testWidgets('cancelling the name dialog creates nothing', (tester) async {
    final vendors = _FakeVendors();
    await host(tester, vendors);
    final result = createVendorInline(ctx, companyId: 'c1', query: '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(vendors.created, isEmpty);
  });
}
