// Settings → Payment Types (invoiceninja/flutter#191, docs/payment-types.md):
// hiding writes the comma list, Show all writes '' (never null), and a
// rename writes — and a Reset removes — the type's `translations` key.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/ui/features/settings/view_models/payment_types_settings_view_model.dart';
import 'package:admin/ui/features/settings/views/basic/payment_types_screen.dart';

import '../../../../../_localization_helper.dart';

class _StubCompanyRepo extends CompanyRepository {
  _StubCompanyRepo({required super.db, required this.company})
    : super(api: _FakeCompaniesApi());

  final Company company;
  final _controller = StreamController<Company?>.broadcast();

  @override
  Stream<Company?> watchCompany(String companyId) {
    Future.microtask(() {
      if (!_controller.isClosed) _controller.add(company);
    });
    return _controller.stream;
  }

  @override
  Future<void> refresh(String companyId) async {}
}

class _FakeCompaniesApi implements CompaniesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeStatics implements StaticsRepository {
  @override
  Map<String, PaymentType> get paymentTypes => const {
    '1': PaymentType(id: '1', name: 'Bank Transfer'),
    '15': PaymentType(id: '15', name: 'Check'),
    '25': PaymentType(id: '25', name: 'Venmo'),
    '45': PaymentType(id: '45', name: 'Instant Bank Pay'),
    '46': PaymentType(id: '46', name: 'FPX'),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.company);

  @override
  final CompanyRepository company;

  @override
  final StaticsRepository statics = _FakeStatics();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<PaymentTypesSettingsViewModel> pump(
    WidgetTester tester, {
    String hidden = '',
    Map<String, dynamic>? translations,
  }) async {
    final repo = _StubCompanyRepo(
      db: db,
      company: Company(
        id: 'co1',
        settings: CompanySettingsApi(
          paymentTypeId: '15',
          hiddenPaymentTypes: hidden,
          translations: translations,
        ),
      ),
    );
    final vm = PaymentTypesSettingsViewModel(repo: repo, companyId: 'co1');
    addTearDown(vm.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(repo),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: PaymentTypesEditor(vm: vm)),
          ),
        ),
      ),
    );
    await tester.runAsync(vm.load);
    await tester.pumpAndSettle();
    return vm;
  }

  Finder rowSwitch(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    matching: find.byType(Switch),
  );

  testWidgets('switching a type off adds it to the hidden list', (
    tester,
  ) async {
    final vm = await pump(tester, hidden: '25');
    expect(find.text('4 of 5 shown'), findsOneWidget);
    await tester.tap(rowSwitch('Bank Transfer'));
    await tester.pumpAndSettle();
    expect(vm.settings.hiddenPaymentTypes, '1,25');
    expect(vm.isDirty, isTrue);
  });

  testWidgets('Hide all, then Show all, clears the list to ""', (tester) async {
    final vm = await pump(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide all'));
    await tester.pumpAndSettle();
    expect(vm.settings.hiddenPaymentTypes, '1,15,25,45,46');

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(vm.settings.hiddenPaymentTypes, '');
  });

  testWidgets('the hidden default says it still applies', (tester) async {
    await pump(tester, hidden: '15');
    expect(
      find.text('Hidden, but still the default for new payments'),
      findsOneWidget,
    );
  });

  testWidgets('renaming writes the type\'s translations key', (tester) async {
    final vm = await pump(tester);
    await tester.tap(find.text('Instant Bank Pay'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Echtzeitüberweisung',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      vm.settings.translations?['payment_type_Instant Bank Pay'],
      'Echtzeitüberweisung',
    );
    expect(find.text('Echtzeitüberweisung'), findsOneWidget);
    expect(find.text('Renamed from Instant Bank Pay'), findsOneWidget);
  });

  testWidgets('Reset removes the name', (tester) async {
    final vm = await pump(
      tester,
      translations: {
        'payment_type_Instant Bank Pay': 'Echtzeitüberweisung',
        'invoice': 'Rechnung',
      },
    );
    await tester.tap(find.text('Echtzeitüberweisung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to "Instant Bank Pay"'));
    await tester.pumpAndSettle();
    expect(vm.settings.translations, {'invoice': 'Rechnung'});
  });

  testWidgets('FPX and Stripe Bank Transfer can\'t be renamed', (tester) async {
    await pump(tester);
    final fpxRow = find.ancestor(
      of: find.text('FPX'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: fpxRow, matching: find.byIcon(Icons.edit_outlined)),
      findsNothing,
    );
  });

  testWidgets('the Hidden filter lists only hidden types', (tester) async {
    await pump(tester, hidden: '25');
    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    expect(find.text('Venmo'), findsOneWidget);
    expect(find.text('Check'), findsNothing);
  });
}
