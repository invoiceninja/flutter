import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/models/value/gateway.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_edit_view_model.dart';
import 'package:admin/ui/features/gateways/widgets/edit/gateway_config_form.dart';

import '../../../_localization_helper.dart';

/// A Custom gateway's `text` is the blurb shown on the portal's payment page,
/// and it is HTML there — React edits it with its rich editor. So the field
/// shows the words and writes markup back. Getting the pair wrong is how the
/// Send Email body silently turned `<strong>` into `**asterisks**`
/// (invoiceninja/flutter#159), and this field has exactly that shape.

class _FakeGatewayRepo implements CompanyGatewayRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _storedText =
    '<p>Pay by <strong>bank transfer</strong></p>'
    '<p>See <a href="https://x.test">our terms</a></p>';

Gateway _gateway() => Gateway(
  id: 'g1',
  name: 'Custom',
  fields: jsonEncode({'text': '', 'appleDomainVerification': ''}),
  options: const {},
  defaultGatewayTypeId: '1',
  sortOrder: 0,
  isOffsite: true,
  isVisible: true,
  siteUrl: '',
);

Future<CompanyGatewayEditViewModel> _pump(WidgetTester tester) async {
  final vm = CompanyGatewayEditViewModel(
    repo: _FakeGatewayRepo(),
    companyId: 'co',
    existing: CompanyGateway(
      id: 'cg1',
      gatewayKey: 'g1',
      config: jsonEncode({
        'text': _storedText,
        'appleDomainVerification': 'abc<123',
      }),
    ),
  );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: GatewayConfigForm(vm: vm, gateway: _gateway()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

Finder _fieldFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

void main() {
  testWidgets('the stored blurb is shown as words, not tags', (tester) async {
    await _pump(tester);

    final field = tester.widget<TextFormField>(_fieldFor('Text'));
    expect(field.initialValue, isNot(contains('<p>')));
    expect(field.initialValue, contains('bank transfer'));
  });

  testWidgets('an edit writes markup back, keeping bold and the link', (
    tester,
  ) async {
    final vm = await _pump(tester);

    await tester.enterText(
      _fieldFor('Text'),
      'Pay by **bank transfer**\n\nSee [our terms](https://x.test)',
    );
    await tester.pump();

    expect(vm.draft.parsedConfig['text'], _storedText);
    expect(vm.draft.parsedConfig['text'], isNot(contains('\n')));
  });

  testWidgets('the Apple verification token is never rewritten', (
    tester,
  ) async {
    // It shares the multiline branch with `text` but is a verification token
    // that has to go on the wire byte for byte.
    final vm = await _pump(tester);

    await tester.enterText(_fieldFor('Apple Domain Verification'), 'tok<en');
    await tester.pump();

    expect(vm.draft.parsedConfig['appleDomainVerification'], 'tok<en');
  });
}
