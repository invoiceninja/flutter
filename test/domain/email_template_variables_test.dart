import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/email_template_variables.dart';

import '../_localization_helper.dart';

void main() {
  group('findTemplateVariables', () {
    test('finds flat and dotted tokens and stops before a final dot', () {
      const text = r'New invoice $number from $company.name.';
      final matches = findTemplateVariables(text);
      expect(matches.map((m) => m.token), [r'$number', r'$company.name']);
      expect(
        text.substring(matches[1].start, matches[1].end),
        r'$company.name',
      );
    });

    test('money and a bare dollar sign are not variables', () {
      expect(findTemplateVariables(r'Pay $5 or US$ 10 today'), isEmpty);
    });

    test('the longest run wins and an apostrophe ends a token', () {
      expect(
        findTemplateVariables(
          r"$number_short and $client.name's",
        ).map((m) => m.token),
        [r'$number_short', r'$client.name'],
      );
    });
  });

  group('scopes', () {
    test('a template id maps to the engine that renders it when sent', () {
      const expected = {
        'invoice': TemplateVariableScope.invoice,
        'reminder1': TemplateVariableScope.invoice,
        'reminder_endless': TemplateVariableScope.invoice,
        'quote': TemplateVariableScope.quote,
        'quote_reminder1': TemplateVariableScope.quote,
        'credit': TemplateVariableScope.credit,
        'purchase_order': TemplateVariableScope.purchaseOrder,
        'payment': TemplateVariableScope.payment,
        'payment_partial': TemplateVariableScope.payment,
        // ClientPaymentFailureObject renders through HtmlEngine.
        'payment_failed': TemplateVariableScope.paymentFailed,
        'statement': TemplateVariableScope.statement,
        'custom1': TemplateVariableScope.any,
        'custom3': TemplateVariableScope.any,
      };
      for (final entry in expected.entries) {
        expect(
          templateVariableScopeForTemplate(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
      expect(
        TemplateVariableScope.paymentFailed.engine,
        TemplateVariableEngine.html,
      );
    });

    test('a document type maps to its scope', () {
      expect(
        templateVariableScopeForEntity('recurring_invoice'),
        TemplateVariableScope.invoice,
      );
      expect(
        templateVariableScopeForEntity('purchase_order'),
        TemplateVariableScope.purchaseOrder,
      );
      expect(
        templateVariableScopeForEntity('quote'),
        TemplateVariableScope.quote,
      );
    });

    test('the statics key for partial payments is the server spelling', () {
      expect(staticTemplateKeyFor('payment_partial'), 'partial_payment');
      expect(staticTemplateKeyFor('reminder1'), 'reminder1');
    });
  });

  group('catalog', () {
    Iterable<TemplateVariable> listed(TemplateVariableScope scope) sync* {
      for (final group in templateVariableGroups(scope)) {
        yield* group.variables;
      }
    }

    test('every label, qualifier and group key renders without a '
        'placeholder', () {
      final en = enStrings();
      final pending = pendingStrings();
      String? resolve(String key) {
        final value = en[key];
        if (value != null && value.trim().isNotEmpty) return value;
        return pending[key];
      }

      final keys = <String>{};
      for (final scope in TemplateVariableScope.values) {
        for (final group in templateVariableGroups(scope)) {
          keys.add(group.labelKey);
          for (final v in group.variables) {
            keys.add(v.labelKey);
            if (v.qualifierKey != null) keys.add(v.qualifierKey!);
          }
        }
        for (final alias in [r'$view_link', r'$client_name', r'$account']) {
          keys.add(lookupTemplateVariable(alias, scope)!.variable.labelKey);
        }
      }
      keys.add(
        lookupTemplateVariable(
          r'$total',
          TemplateVariableScope.invoice,
        )!.variable.labelKey,
      );

      for (final key in keys) {
        final value = resolve(key);
        expect(value, isNotNull, reason: '"$key" is in no bundle');
        expect(value!.trim(), isNotEmpty, reason: '"$key" is blank');
        expect(
          kLocalePlaceholderPattern.hasMatch(value),
          isFalse,
          reason: '"$key" renders "$value", which carries a placeholder',
        );
      }
    });

    test('no scope lists a token twice', () {
      for (final scope in TemplateVariableScope.values) {
        final tokens = listed(scope).map((v) => v.token).toList();
        expect(tokens.toSet().length, tokens.length, reason: '$scope');
      }
    });

    test(r'the bogus $client_address1 is gone', () {
      for (final scope in TemplateVariableScope.values) {
        expect(
          listed(scope).map((v) => v.token),
          isNot(contains(r'$client_address1')),
        );
      }
      expect(
        lookupTemplateVariable(r'$client_address1', TemplateVariableScope.any),
        isNull,
      );
    });

    test('every listed token has engine data or is a statement extra', () {
      for (final scope in TemplateVariableScope.values) {
        for (final v in listed(scope)) {
          expect(
            templateVariableEngines.containsKey(v.token) ||
                v.token == r'$start_date' ||
                v.token == r'$end_date',
            isTrue,
            reason: '${v.token} ($scope)',
          );
        }
      }
    });

    test('every token in each server default template is in scope', () {
      // Expanded from `EmailTemplateDefaults.php` — its bodies reach the
      // tokens through `transformText()` / `ctrans()`, so the PHP file alone
      // doesn't show them.
      const defaults = <String, List<String>>{
        'invoice': [
          r'$number',
          r'$company.name',
          r'$client',
          r'$amount',
          r'$view_button',
        ],
        'quote': [
          r'$number',
          r'$company.name',
          r'$client',
          r'$amount',
          r'$view_button',
        ],
        'credit': [
          r'$number',
          r'$company.name',
          r'$client',
          r'$amount',
          r'$view_button',
        ],
        'quote_reminder1': [
          r'$number',
          r'$company.name',
          r'$client',
          r'$amount',
          r'$view_button',
        ],
        'reminder1': [
          r'$number',
          r'$company.name',
          r'$client',
          r'$balance',
          r'$view_button',
        ],
        'reminder_endless': [
          r'$number',
          r'$company.name',
          r'$client',
          r'$balance',
          r'$view_button',
        ],
        'payment': [r'$client', r'$amount', r'$invoices', r'$view_button'],
        'payment_partial': [
          r'$client',
          r'$amount',
          r'$invoices',
          r'$view_button',
        ],
        'payment_failed': [
          r'$number',
          r'$client',
          r'$amount',
          r'$payment_error',
          r'$view_button',
        ],
        'purchase_order': [
          r'$number',
          r'$account',
          r'$vendor',
          r'$amount',
          r'$view_button',
        ],
        'statement': [r'$client', r'$start_date', r'$end_date'],
      };
      for (final entry in defaults.entries) {
        final scope = templateVariableScopeForTemplate(entry.key);
        for (final token in entry.value) {
          final found = lookupTemplateVariable(token, scope);
          expect(found, isNotNull, reason: '$token in ${entry.key}');
          expect(found!.inScope, isTrue, reason: '$token in ${entry.key}');
        }
      }
    });

    test('validity follows the engine, not the picker group', () {
      bool inScope(String token, TemplateVariableScope scope) =>
          isTemplateVariableInScope(token, scope);
      // HtmlEngine defines $vendor.name although no invoice group lists it.
      expect(inScope(r'$vendor.name', TemplateVariableScope.invoice), isTrue);
      expect(inScope(r'$vendor.email', TemplateVariableScope.invoice), isFalse);
      expect(
        inScope(r'$payment_button', TemplateVariableScope.payment),
        isFalse,
      );
      expect(inScope(r'$invoices', TemplateVariableScope.invoice), isFalse);
      expect(inScope(r'$invoices', TemplateVariableScope.payment), isTrue);
      expect(
        inScope(r'$po_number', TemplateVariableScope.purchaseOrder),
        isFalse,
      );
      expect(inScope(r'$start_date', TemplateVariableScope.invoice), isFalse);
      expect(inScope(r'$start_date', TemplateVariableScope.statement), isTrue);
      expect(
        inScope(r'$payment_error', TemplateVariableScope.paymentFailed),
        isTrue,
      );
      expect(inScope(r'$made_up', TemplateVariableScope.invoice), isFalse);
    });

    test('custom templates never flag a catalogued token', () {
      for (final token in templateVariableEngines.keys) {
        expect(
          isTemplateVariableInScope(token, TemplateVariableScope.any),
          isTrue,
          reason: token,
        );
      }
      expect(
        isTemplateVariableInScope(r'$start_date', TemplateVariableScope.any),
        isTrue,
      );
      expect(
        isTemplateVariableInScope(r'$made_up', TemplateVariableScope.any),
        isFalse,
      );
    });

    test('labels follow the scope', () {
      String labelOf(String token, TemplateVariableScope scope) =>
          lookupTemplateVariable(token, scope)!.variable.labelKey;
      expect(labelOf(r'$number', TemplateVariableScope.quote), 'quote_number');
      expect(
        labelOf(r'$number', TemplateVariableScope.payment),
        'payment_number',
      );
      expect(
        labelOf(r'$due_date', TemplateVariableScope.quote),
        'quote_due_date',
      );
      expect(
        labelOf(r'$view_link', TemplateVariableScope.credit),
        'view_credit',
      );
      expect(
        labelOf(r'$account', TemplateVariableScope.purchaseOrder),
        'company_name',
      );
    });

    test('an out-of-scope token still gets its label', () {
      final found = lookupTemplateVariable(
        r'$payment_button',
        TemplateVariableScope.payment,
      )!;
      expect(found.variable.labelKey, 'pay_now');
      expect(found.inScope, isFalse);
    });

    test('aliases resolve but are not offered twice', () {
      final tokens = listed(
        TemplateVariableScope.purchaseOrder,
      ).map((v) => v.token);
      expect(tokens, isNot(contains(r'$account')));
      expect(
        lookupTemplateVariable(
          r'$account',
          TemplateVariableScope.purchaseOrder,
        )!.inScope,
        isTrue,
      );
    });

    test('HTML-valued variables are not subject-safe', () {
      bool safe(String token) => lookupTemplateVariable(
        token,
        TemplateVariableScope.any,
      )!.variable.subjectSafe;
      expect(safe(r'$view_button'), isFalse);
      expect(safe(r'$payment_button'), isFalse);
      expect(safe(r'$invoices'), isFalse);
      expect(safe(r'$payments'), isFalse);
      expect(safe(r'$company.name'), isTrue);
      expect(safe(r'$number'), isTrue);
    });
  });

  group('closestTemplateVariable', () {
    test('suggests the listed token a typo was aiming at', () {
      expect(
        closestTemplateVariable(
          r'$compnay.name',
          TemplateVariableScope.invoice,
        )?.token,
        r'$company.name',
      );
      expect(
        closestTemplateVariable(
          r'$Client.Nmae',
          TemplateVariableScope.invoice,
        )?.token,
        r'$client.name',
      );
    });

    test('suggests nothing when nothing is close or the token is exact', () {
      expect(
        closestTemplateVariable(r'$xyzzyplugh', TemplateVariableScope.invoice),
        isNull,
      );
      expect(
        closestTemplateVariable(r'$number', TemplateVariableScope.invoice),
        isNull,
      );
    });
  });

  group('probe helpers', () {
    test('round-trips adjacent tokens', () {
      final tokens = [r'$number', r'$company.name'];
      final probe = buildTemplateVariableProbe(tokens, 'abc123');
      expect(
        probe,
        r'[[inabc123:0]]$number[[inabc123:1]]$company.name[[inabc123:2]]',
      );
      final rendered = probe
          .replaceAll(r'$number', '0012')
          .replaceAll(r'$company.name', 'Acme Ltd');
      expect(parseTemplateVariableProbe(rendered, tokens, 'abc123'), {
        r'$number': '0012',
        r'$company.name': 'Acme Ltd',
      });
    });

    test('an empty and an echoed segment come back verbatim', () {
      final tokens = [r'$po_number', r'$nope'];
      final probe = buildTemplateVariableProbe(tokens, 'n0nce1');
      final rendered = probe.replaceAll(r'$po_number', '');
      expect(parseTemplateVariableProbe(rendered, tokens, 'n0nce1'), {
        r'$po_number': '',
        r'$nope': r'$nope',
      });
    });

    test('a missing marker yields null rather than a misattributed value', () {
      final tokens = [r'$number', r'$amount'];
      final probe = buildTemplateVariableProbe(tokens, 'abc123');
      expect(
        parseTemplateVariableProbe(
          probe.replaceAll('[[inabc123:1]]', ''),
          tokens,
          'abc123',
        ),
        isNull,
      );
      expect(parseTemplateVariableProbe('', tokens, 'abc123'), isNull);
    });

    test('markers hold no dollar sign, so strtr can never match one', () {
      final probe = buildTemplateVariableProbe(const [], 'abc123');
      expect(probe, isNot(contains(r'$')));
    });
  });

  group('engine oracle', () {
    // Reported as SKIPPED, never as passed, when the server checkout is
    // absent (CI) — the same contract as `totals_parity_test.dart`.
    final root =
        Platform.environment['INVOICENINJA_SERVER'] ?? '../invoiceninja';
    const files = {
      TemplateVariableEngine.html: 'app/Utils/HtmlEngine.php',
      TemplateVariableEngine.vendor: 'app/Utils/VendorHtmlEngine.php',
      TemplateVariableEngine.payment: 'app/Mail/Engine/PaymentEmailEngine.php',
    };

    test('each token\'s engine set matches the PHP source', () {
      final missing = [
        for (final path in files.values)
          if (!File('$root/$path').existsSync()) path,
      ];
      if (missing.isNotEmpty) {
        markTestSkipped('engine oracle: no server source at $root');
        return;
      }
      final assignment = RegExp(r"\$data\['(\$[A-Za-z0-9_.]+)'\]\s*=");
      final defined = {
        for (final entry in files.entries)
          entry.key: {
            for (final m in assignment.allMatches(
              File('$root/${entry.value}').readAsStringSync(),
            ))
              m.group(1)!,
          },
      };
      for (final entry in templateVariableEngines.entries) {
        final actual = {
          for (final engine in defined.entries)
            if (engine.value.contains(entry.key)) engine.key,
        };
        expect(actual, entry.value, reason: entry.key);
      }
    });
  });
}
