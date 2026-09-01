import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

import '../../../_localization_helper.dart';

/// Minimal [CompanyRepository] that only answers `watchCompany`; everything
/// else throws so the test fails loudly if the card reaches for more.
class _FakeCompanyRepo implements CompanyRepository {
  _FakeCompanyRepo(this._company);
  final Company? _company;

  @override
  Stream<Company?> watchCompany(String companyId) => Stream.value(_company);

  // Cold seed cache: keeps these tests on the async watch path, exactly as
  // before `BaseEntityRepository.peek` existed. The `company is still loading
  // (null)` case below depends on it staying cold.
  @override
  Company? peek({required String companyId, required String id}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.company);
  @override
  final CompanyRepository company;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  required Company? company,
  required List<String> values,
  String prefix = 'product',
}) async {
  await tester.pumpWidget(
    Provider<Services>.value(
      value: _FakeServices(_FakeCompanyRepo(company)),
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CustomFieldsDetailCard(
              companyId: 'co-A',
              prefix: prefix,
              values: values,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a titled card with configured + filled rows', (
    tester,
  ) async {
    await _pump(
      tester,
      company: const Company(
        customFields: {
          'product1': 'Material|single_line_text',
          'product2': 'In Stock|switch',
        },
      ),
      values: const ['Oak', 'yes', '', ''],
    );
    expect(find.byType(DashboardCardShell), findsOneWidget);
    expect(find.text('Material'), findsOneWidget);
    expect(find.text('Oak'), findsOneWidget);
    expect(find.text('In Stock'), findsOneWidget);
    // switch 'yes' renders the localized affirmative, not the raw 'yes'.
    expect(find.text('Yes'), findsOneWidget);
  });

  testWidgets('collapses when no slot is configured', (tester) async {
    await _pump(
      tester,
      company: const Company(customFields: {}),
      values: const ['Oak', '', '', ''],
    );
    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('collapses when configured but all values empty', (tester) async {
    await _pump(
      tester,
      company: const Company(
        customFields: {'product1': 'Material|single_line_text'},
      ),
      values: const ['', '', '', ''],
    );
    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('skips slots without a configured label', (tester) async {
    await _pump(
      tester,
      company: const Company(
        customFields: {'product1': 'Material|single_line_text'},
      ),
      // slot 2 has a value but no configured label → not shown.
      values: const ['Oak', 'orphaned', '', ''],
    );
    expect(find.text('Material'), findsOneWidget);
    expect(find.text('Oak'), findsOneWidget);
    expect(find.text('orphaned'), findsNothing);
  });

  testWidgets('collapses while the company is still loading (null)', (
    tester,
  ) async {
    await _pump(tester, company: null, values: const ['Oak', '', '', '']);
    expect(find.byType(DashboardCardShell), findsNothing);
  });
}
