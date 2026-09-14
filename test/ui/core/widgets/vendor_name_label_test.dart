import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';

import '../../../_localization_helper.dart';

/// `VendorNameLabel` used to fall back to the raw `vendorId` — its older
/// sibling `ClientNameLabel` was fixed long ago and this one never was. That
/// was survivable in a table cell and not under a `Vendor` label on a form:
/// `LockedVendorFieldRow` paints a saved purchase order's Vendor field, where
/// an uncached vendor showed `Wpmbk5ezJn` with nothing to act on.
///
/// Three branches, and the middle one is the distinction that makes the fix
/// honest: **resolved-but-nameless is not unresolved.**
class _FakeVendorRepo implements VendorRepository {
  _FakeVendorRepo({this.vendor});

  final Vendor? vendor;
  final ensureLoadedCalls = <String>[];

  @override
  Stream<Vendor?> watch({required String companyId, required String id}) =>
      Stream<Vendor?>.value(vendor);

  @override
  Vendor? peek({required String companyId, required String id}) => null;

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async => ensureLoadedCalls.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  @override
  ValueListenable<AuthSession?> get session => ValueNotifier<AuthSession?>(
    const AuthSession(
      baseUrl: '',
      isHosted: false,
      accountId: '',
      currentCompanyId: 'co',
      companies: [
        AuthCompany(
          id: 'co',
          name: 'Co',
          displayName: 'Co',
          permissions: '',
          isAdmin: true,
          isOwner: false,
        ),
      ],
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.vendors);
  @override
  final VendorRepository vendors;
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Vendor _vendor(String id, {String name = 'Northwind Supply'}) => Vendor(
  id: id,
  name: name,
  number: '',
  idNumber: '',
  vatNumber: '',
  website: '',
  phone: '',
  address1: '',
  address2: '',
  city: '',
  state: '',
  postalCode: '',
  countryId: '',
  currencyId: '',
  privateNotes: '',
  publicNotes: '',
  userId: '',
  assignedUserId: '',
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  contacts: const [],
);

Future<void> _pump(WidgetTester tester, _FakeVendorRepo repo, String id) async {
  await tester.pumpWidget(
    Provider<Services>.value(
      value: _FakeServices(repo),
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(body: VendorNameLabel(vendorId: id)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the resolved name', (tester) async {
    await _pump(tester, _FakeVendorRepo(vendor: _vendor('v1')), 'v1');
    expect(find.text('Northwind Supply'), findsOneWidget);
  });

  testWidgets('resolved but nameless is not unresolved', (tester) async {
    await _pump(tester, _FakeVendorRepo(vendor: _vendor('v1', name: '')), 'v1');
    expect(find.text('(no name)'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('unresolved renders an em dash and never the raw id', (
    tester,
  ) async {
    final repo = _FakeVendorRepo(); // watch resolves to null
    await _pump(tester, repo, 'Wpmbk5ezJn');

    expect(find.text('Wpmbk5ezJn'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    // The id stays available to screen readers and `debugDumpApp`.
    expect(tester.getSemantics(find.text('—')).label, contains('Wpmbk5ezJn'));
    // …and it asked for the missing row rather than giving up on it.
    expect(repo.ensureLoadedCalls, ['Wpmbk5ezJn']);
  });

  testWidgets('an empty id renders an em dash without asking for anything', (
    tester,
  ) async {
    final repo = _FakeVendorRepo();
    await _pump(tester, repo, '');

    expect(find.text('—'), findsOneWidget);
    expect(repo.ensureLoadedCalls, isEmpty);
  });
}
