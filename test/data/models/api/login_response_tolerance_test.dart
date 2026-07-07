import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/login_response_api_model.dart';

/// L7 — the login/refresh envelope parses with per-row tolerance, matching
/// the *ListApi envelopes: one malformed row degrades that row (with a
/// diagnostics WARNING), never the whole login.
void main() {
  Map<String, dynamic> company(String id) => {
    'company': <String, dynamic>{'id': 'co_$id', 'name': 'Company $id'},
    'token': <String, dynamic>{'token': 'tok_$id', 'name': 't'},
    'account': <String, dynamic>{'id': 'acc_$id'},
  };

  test('one malformed company row is skipped; the rest parse', () {
    final parsed = LoginResponseApi.fromJson({
      'data': [
        company('a'),
        // `company` present but with a shape that throws inside the nested
        // fromJson (String field fed a Map).
        {
          'company': {
            'id': {'nested': 'garbage'},
          },
          'token': {'token': 'tok_bad'},
          'account': {'id': 'acc_bad'},
        },
        company('b'),
      ],
    });

    expect(parsed.data, hasLength(2));
    expect(parsed.data.map((c) => c.company.id), ['co_a', 'co_b']);
  });

  test('a malformed bundled sub-list row is skipped; its company still '
      'parses', () {
    final json = company('a');
    (json['company'] as Map<String, dynamic>)['tax_rates'] = [
      {'id': 'tr_ok', 'name': 'VAT'},
      {
        'id': {'not': 'a string'},
      },
    ];
    final parsed = LoginResponseApi.fromJson({
      'data': [json],
    });

    expect(parsed.data, hasLength(1));
    expect(parsed.data.single.company.taxRates, hasLength(1));
    expect(parsed.data.single.company.taxRates.single.id, 'tr_ok');
  });

  test('an all-garbage data list parses to empty (the repository layer then '
      'fails loudly on the empty company list)', () {
    final parsed = LoginResponseApi.fromJson({
      'data': ['garbage', 42, null],
    });
    expect(parsed.data, isEmpty);
  });
}
