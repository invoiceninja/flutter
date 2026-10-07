import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/login_response_api_model.dart';

/// A full snapshot — `/login`, an OAuth or token sign-in, a signup, a
/// `/refresh` sent with `updated_at=0` — carries every browsable record of
/// every company, and the delta appliers skip it (`_deltaOnly`). Since
/// invoiceninja/flutter#170 typed those fourteen arrays, a cold start built an
/// object for every client, invoice and payment in the account on the UI
/// isolate and threw them all away. `LoginResponseApi.fromFullSnapshot` parses
/// the envelope without them; these tests pin that, and that the list of keys
/// it drops cannot fall behind the model.
///
/// See `docs/startup-responsiveness.md`.

/// Every list-valued field on the envelope that is NOT a browsable delta: the
/// reference bundles a full snapshot must keep.
const _referenceBundleKeys = <String>{
  'documents',
  'client_registration_fields',
  'users',
  'task_statuses',
  'company_gateways',
  'payment_terms',
  'tax_rates',
  'expense_categories',
  'groups',
  'bank_transaction_rules',
  'bank_integrations',
  'webhooks',
  'tokens_hashed',
  'task_schedulers',
  'subscriptions',
  'designs',
};

Map<String, dynamic> _userCompany(
  String id,
  Map<String, dynamic> companyPatch,
) => {
  'company': <String, dynamic>{
    'id': 'co_$id',
    'name': 'Company $id',
    ...companyPatch,
  },
  'token': <String, dynamic>{'token': 'tok_$id', 'name': 't'},
  'account': <String, dynamic>{'id': 'acc_$id'},
};

/// One row per browsable key carrying every field its DTO has: a minimal row,
/// parsed and re-encoded. A two-field row would make the timing below
/// meaningless — the cost being measured is per field.
Map<String, Map<String, dynamic>> _fullRows() {
  final parsed = LoginResponseApi.fromJson({
    'data': [
      _userCompany('t', {
        for (final key in kBrowsableDeltaJsonKeys)
          key: [
            <String, dynamic>{'id': 'row', 'updated_at': 1},
          ],
      }),
    ],
  });
  final encoded = jsonDecode(jsonEncode(parsed.toJson())) as Map;
  final company = ((encoded['data'] as List).single as Map)['company'] as Map;
  return {
    for (final key in kBrowsableDeltaJsonKeys)
      key: Map<String, dynamic>.from((company[key] as List).single as Map),
  };
}

Map<String, dynamic> _envelope({required int rowsPerKey}) {
  final rows = _fullRows();
  return {
    'data': [
      for (final id in ['a', 'b'])
        _userCompany(id, {
          'task_statuses': [
            <String, dynamic>{'id': 'ts_$id', 'name': 'Backlog'},
          ],
          for (final key in kBrowsableDeltaJsonKeys)
            key: [
              for (var i = 0; i < rowsPerKey; i++)
                <String, dynamic>{...rows[key]!, 'id': '${key}_${id}_$i'},
            ],
        }),
    ],
    'static': <String, dynamic>{
      'currencies': [
        <String, dynamic>{'id': '1'},
      ],
    },
  };
}

List<int> _browsableLengths(CompanyEnvelopeApi co) => [
  co.clients.length,
  co.products.length,
  co.invoices.length,
  co.recurringInvoices.length,
  co.quotes.length,
  co.credits.length,
  co.payments.length,
  co.tasks.length,
  co.projects.length,
  co.expenses.length,
  co.recurringExpenses.length,
  co.vendors.length,
  co.purchaseOrders.length,
  co.bankTransactions.length,
];

void main() {
  test('a full snapshot is parsed without its browsable entity arrays', () {
    const rowsPerKey = 500;
    // Warm both paths on a one-row envelope, so the comparison below is not
    // just the first parse paying for the JIT.
    LoginResponseApi.fromJson(_envelope(rowsPerKey: 1));
    LoginResponseApi.fromFullSnapshot(_envelope(rowsPerKey: 1));

    final typedSource = _envelope(rowsPerKey: rowsPerKey);
    final snapshotSource = _envelope(rowsPerKey: rowsPerKey);

    final typedWatch = Stopwatch()..start();
    final typed = LoginResponseApi.fromJson(typedSource);
    typedWatch.stop();
    final snapshotWatch = Stopwatch()..start();
    final snapshot = LoginResponseApi.fromFullSnapshot(snapshotSource);
    snapshotWatch.stop();

    // `fromJson` is unchanged: a delta refresh still gets every array.
    for (final uc in typed.data) {
      expect(_browsableLengths(uc.company), everyElement(rowsPerKey));
    }

    // The full snapshot drops all fourteen, for every company…
    expect(snapshot.data.map((uc) => uc.company.id), ['co_a', 'co_b']);
    for (final uc in snapshot.data) {
      expect(_browsableLengths(uc.company), everyElement(0));
    }
    // …and nothing else: the session, the reference bundles, the statics.
    expect(snapshot.data.first.token.token, 'tok_a');
    expect(snapshot.data.first.company.name, 'Company a');
    expect(snapshot.data.first.company.taskStatuses.single.id, 'ts_a');
    expect(snapshot.data.last.company.taskStatuses.single.id, 'ts_b');
    expect(snapshot.staticData['currencies'], isNotEmpty);

    // The caller's map is left as it was — a copy is edited, not the source.
    final sourceCompany =
        ((snapshotSource['data'] as List).first as Map)['company'] as Map;
    expect(sourceCompany['clients'], hasLength(rowsPerKey));

    final rows = rowsPerKey * kBrowsableDeltaJsonKeys.length * 2;
    // The measurement this change rests on, printed rather than asserted: a
    // time bound would only flake on a loaded CI runner.
    // ignore: avoid_print
    print(
      'full-snapshot parse of $rows browsable rows: '
      'fromJson ${typedWatch.elapsedMilliseconds}ms, '
      'fromFullSnapshot ${snapshotWatch.elapsedMilliseconds}ms',
    );
  });

  test('an unmodifiable envelope parses, and an odd one is passed through', () {
    const frozen = <String, dynamic>{
      'data': [
        <String, dynamic>{
          'company': <String, dynamic>{
            'id': 'co_a',
            'clients': [
              <String, dynamic>{'id': 'cl_1'},
            ],
          },
          'token': <String, dynamic>{'token': 'tok_a', 'name': 't'},
          'account': <String, dynamic>{'id': 'acc_a'},
        },
      ],
    };
    final parsed = LoginResponseApi.fromFullSnapshot(frozen);
    expect(parsed.data.single.company.id, 'co_a');
    expect(parsed.data.single.company.clients, isEmpty);

    // No `data` list at all, and an entry with no company map: neither is this
    // function's to judge. It hands them on unchanged, and the tolerant
    // parsers drop what they cannot read.
    const noData = <String, dynamic>{'static': <String, dynamic>{}};
    expect(withoutBrowsableEntityArrays(noData), same(noData));
    expect(
      LoginResponseApi.fromFullSnapshot(const {
        'data': ['not a map'],
      }).data,
      isEmpty,
    );
  });

  test('every list on the envelope is a browsable delta or a reference '
      'bundle', () {
    final listKeys = {
      for (final entry in const CompanyEnvelopeApi(id: 'c1').toJson().entries)
        if (entry.value is List) entry.key,
    };
    expect(
      listKeys.difference(_referenceBundleKeys),
      kBrowsableDeltaJsonKeys,
      reason:
          'a list field on CompanyEnvelopeApi is in neither set. If it is a '
          'browsable entity delta, add its JSON key to kBrowsableDeltaJsonKeys '
          '— otherwise every cold start types a full dataset of it for '
          'nothing. If it is a reference bundle, add it to this test.',
    );
    expect(
      _referenceBundleKeys.difference(listKeys),
      isEmpty,
      reason: 'a reference bundle listed here is no longer on the envelope',
    );
  });
}
