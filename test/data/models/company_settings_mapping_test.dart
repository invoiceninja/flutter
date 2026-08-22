import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/company_settings_api_model.dart';

void main() {
  group('CompanySettingsApi mapping', () {
    test('fromJson + toJson round-trips a representative payload', () {
      // A subset modeled on a real /auth/me response — covers each field
      // type the model declares (String, int, double, bool, Map<List<...>>).
      const payload = '''
{
  "id": "Wpmbk5ezJn",
  "name": "Acme Inc",
  "company_logo": "https://cdn.invoiceninja.com/logo.png",
  "address1": "1 Main",
  "city": "Berlin",
  "country_id": "276",
  "vat_number": "DE123",
  "id_number": "REG-9",
  "classification": "company",
  "currency_id": "1",
  "language_id": "1",
  "timezone_id": "1",
  "tax_rate1": 19.0,
  "tax_name1": "VAT",
  "invoice_number_counter": 42,
  "counter_padding": 4,
  "auto_archive_invoice": false,
  "send_reminders": true,
  "invoice_terms": "Net 30",
  "purchase_order_terms": "POs settle in 14 days",
  "default_task_rate": 75.5,
  "pdf_variables": {
    "invoice_columns": ["item", "quantity", "cost"]
  }
}
''';
      final parsed = CompanySettingsApi.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );

      expect(parsed.name, 'Acme Inc');
      expect(parsed.taxRate1, 19.0);
      expect(parsed.invoiceNumberCounter, 42);
      expect(parsed.autoArchiveInvoice, false);
      expect(parsed.sendReminders, true);
      // NOTE: use_comma_as_decimal_place is intentionally NOT asserted here —
      // it's a top-level company field, not a cascade setting (see CompanyApi /
      // company_repository_test.dart's round-trip). The server never returns it
      // inside `settings`.
      expect(parsed.invoiceTerms, 'Net 30');
      expect(parsed.purchaseOrderTerms, 'POs settle in 14 days');
      expect(parsed.defaultTaskRate, 75.5);
      expect(parsed.pdfVariables?['invoice_columns'], [
        'item',
        'quantity',
        'cost',
      ]);

      // toJson strips nulls (`includeIfNull: false`) — the round-trip
      // therefore has only the keys we set, but every key we did set must
      // come back equal.
      final encoded = parsed.toJson();
      final reparsed = CompanySettingsApi.fromJson(encoded);
      expect(reparsed, parsed);
    });

    test('toJson omits null fields so cascade overrides are wire-honest', () {
      const partial = CompanySettingsApi(name: 'Acme', vatNumber: null);
      final encoded = partial.toJson();
      expect(encoded.containsKey('name'), isTrue);
      expect(encoded.containsKey('vat_number'), isFalse);
    });

    test('round-trips france e-reporting fields', () {
      final parsed = CompanySettingsApi.fromJson({
        'france_reporting_enabled': true,
        'france_reporting_schedule': 'monthly',
      });
      expect(parsed.franceReportingEnabled, true);
      expect(parsed.franceReportingSchedule, 'monthly');

      final reparsed = CompanySettingsApi.fromJson(parsed.toJson());
      expect(reparsed.franceReportingEnabled, true);
      expect(reparsed.franceReportingSchedule, 'monthly');
    });

    test('round-trips global_tag_inheritance', () {
      final parsed = CompanySettingsApi.fromJson({
        'global_tag_inheritance': true,
      });
      expect(parsed.globalTagInheritance, true);

      final reparsed = CompanySettingsApi.fromJson(parsed.toJson());
      expect(reparsed.globalTagInheritance, true);
    });

    test('coerces endless_reminder_frequency_id shipped as an int', () {
      // The server casts this to `integer` in CompanySettings::$casts and
      // emits the `settings` blob raw, so it arrives as a number even though
      // the field is a wire-string. The strict fromJson path (company.dart)
      // must not throw, and `0` must map to "0" so the reminder UI (which
      // compares against '0') keeps treating it as "no endless reminder".
      expect(
        CompanySettingsApi.fromJson({
          'endless_reminder_frequency_id': 0,
        }).endlessReminderFrequencyId,
        '0',
      );
      expect(
        CompanySettingsApi.fromJson({
          'endless_reminder_frequency_id': 1,
        }).endlessReminderFrequencyId,
        '1',
      );
    });
  });

  group('CompanySettingsApi.fromJsonLenient', () {
    test('coerces numeric fields shipped as strings', () {
      // Real failure mode from a production tenant: the server sends
      // `reset_counter_frequency_id` as the String "1", and the strict
      // `as num?` cast on the generated parser blows up.
      final parsed = CompanySettingsApi.fromJsonLenient({
        'reset_counter_frequency_id': '1',
        'tax_rate1': '19.5',
        'counter_padding': '4',
        'default_task_rate': '75.50',
      });
      expect(parsed.resetCounterFrequencyId, 1);
      expect(parsed.taxRate1, 19.5);
      expect(parsed.counterPadding, 4);
      expect(parsed.defaultTaskRate, 75.5);
    });

    test('coerces bool fields shipped as ints and strings', () {
      final parsed = CompanySettingsApi.fromJsonLenient({
        'military_time': 1,
        'enable_reminder1': 0,
        'show_currency_code': 'true',
        'send_reminders': 'false',
        'inclusive_taxes': '1',
        'auto_archive_invoice': '0',
        'france_reporting_enabled': 1,
        'global_tag_inheritance': 1,
        'documents_public_by_default': 0,
      });
      expect(parsed.militaryTime, true);
      expect(parsed.enableReminder1, false);
      expect(parsed.showCurrencyCode, true);
      expect(parsed.sendReminders, false);
      expect(parsed.inclusiveTaxes, true);
      expect(parsed.autoArchiveInvoice, false);
      expect(parsed.franceReportingEnabled, true);
      expect(parsed.globalTagInheritance, true);
      expect(parsed.documentsPublicByDefault, false);
    });

    test('drops unparseable numeric strings instead of crashing', () {
      // The strict parser would throw on this. The lenient one should
      // skip the bad value and continue.
      final parsed = CompanySettingsApi.fromJsonLenient({
        'counter_padding': 'not-a-number',
        'name': 'Acme',
      });
      expect(parsed.counterPadding, isNull);
      expect(parsed.name, 'Acme');
    });

    test('passes through normal typed values unchanged', () {
      final parsed = CompanySettingsApi.fromJsonLenient({
        'name': 'Acme',
        'tax_rate1': 19.0,
        'military_time': true,
        'invoice_number_counter': 42,
      });
      expect(parsed.name, 'Acme');
      expect(parsed.taxRate1, 19.0);
      expect(parsed.militaryTime, true);
      expect(parsed.invoiceNumberCounter, 42);
    });

    test(
      'translations parses as a Map (server ships {} for unset accounts)',
      () {
        // Regression: the field was previously typed as `List<dynamic>?`, so
        // the strict parser blew up on every company refresh and fell back to
        // empty typed settings — wiping the typed view until the company was
        // re-fetched.
        final empty = CompanySettingsApi.fromJson({
          'translations': const <String, dynamic>{},
        });
        expect(empty.translations, isEmpty);

        final populated = CompanySettingsApi.fromJson({
          'translations': const {'invoice_total': 'Sum', 'due_date': 'Pay by'},
        });
        expect(populated.translations?['invoice_total'], 'Sum');
        expect(populated.translations?['due_date'], 'Pay by');
      },
    );
  });
}
