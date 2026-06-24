import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/models/domain/company.dart';

void main() {
  group('Company top-level field mapping', () {
    test('round-trips Workflow Settings top-level booleans through '
        'fromApi → toApiJson', () {
      const api = CompanyApi(
        id: 'co',
        name: 'Acme',
        stopOnUnpaidRecurring: true,
        useQuoteTermsOnConversion: true,
      );

      final domain = Company.fromApi(api);
      expect(domain.stopOnUnpaidRecurring, isTrue);
      expect(domain.useQuoteTermsOnConversion, isTrue);

      final json = domain.toApiJson();
      expect(json['stop_on_unpaid_recurring'], isTrue);
      expect(json['use_quote_terms_on_conversion'], isTrue);
    });

    test('Workflow Settings top-level booleans default to false when missing '
        'from the wire', () {
      final api = CompanyApi.fromJson(<String, dynamic>{'id': 'co'});
      final domain = Company.fromApi(api);
      expect(domain.stopOnUnpaidRecurring, isFalse);
      expect(domain.useQuoteTermsOnConversion, isFalse);
    });

    test('round-trips Task Settings top-level booleans through '
        'fromApi → toApiJson', () {
      const api = CompanyApi(
        id: 'co',
        name: 'Acme',
        autoStartTasks: true,
        showTaskEndDate: true,
        showTasksTable: true,
        invoiceTaskDatelog: true,
        invoiceTaskTimelog: true,
        invoiceTaskHours: true,
        invoiceTaskItemDescription: true,
        invoiceTaskProject: true,
        invoiceTaskProjectHeader: true,
        invoiceTaskLock: true,
        invoiceTaskDocuments: true,
      );

      final domain = Company.fromApi(api);
      expect(domain.autoStartTasks, isTrue);
      expect(domain.showTaskEndDate, isTrue);
      expect(domain.showTasksTable, isTrue);
      expect(domain.invoiceTaskDatelog, isTrue);
      expect(domain.invoiceTaskTimelog, isTrue);
      expect(domain.invoiceTaskHours, isTrue);
      expect(domain.invoiceTaskItemDescription, isTrue);
      expect(domain.invoiceTaskProject, isTrue);
      expect(domain.invoiceTaskProjectHeader, isTrue);
      expect(domain.invoiceTaskLock, isTrue);
      expect(domain.invoiceTaskDocuments, isTrue);

      final json = domain.toApiJson();
      expect(json['auto_start_tasks'], isTrue);
      expect(json['show_task_end_date'], isTrue);
      expect(json['show_tasks_table'], isTrue);
      expect(json['invoice_task_datelog'], isTrue);
      expect(json['invoice_task_timelog'], isTrue);
      expect(json['invoice_task_hours'], isTrue);
      expect(json['invoice_task_item_description'], isTrue);
      expect(json['invoice_task_project'], isTrue);
      expect(json['invoice_task_project_header'], isTrue);
      expect(json['invoice_task_lock'], isTrue);
      expect(json['invoice_task_documents'], isTrue);
    });

    test('round-trips Expense Settings top-level fields through '
        'fromApi → toApiJson', () {
      const api = CompanyApi(
        id: 'co',
        name: 'Acme',
        markExpensesInvoiceable: true,
        markExpensesPaid: true,
        convertExpenseCurrency: true,
        invoiceExpenseDocuments: true,
        notifyVendorWhenPaid: true,
        calculateExpenseTaxByAmount: true,
        expenseInclusiveTaxes: true,
        expenseMailboxActive: true,
        expenseMailbox: 'expenses@acme.com',
        inboundMailboxAllowCompanyUsers: true,
        inboundMailboxAllowVendors: true,
        inboundMailboxAllowClients: true,
        inboundMailboxWhitelist: 'trusted@vendor.com',
        inboundMailboxBlacklist: 'spam@vendor.com',
        inboundMailboxAllowUnknown: true,
      );

      final domain = Company.fromApi(api);
      expect(domain.markExpensesInvoiceable, isTrue);
      expect(domain.markExpensesPaid, isTrue);
      expect(domain.convertExpenseCurrency, isTrue);
      expect(domain.invoiceExpenseDocuments, isTrue);
      expect(domain.notifyVendorWhenPaid, isTrue);
      expect(domain.calculateExpenseTaxByAmount, isTrue);
      expect(domain.expenseInclusiveTaxes, isTrue);
      expect(domain.expenseMailboxActive, isTrue);
      expect(domain.expenseMailbox, 'expenses@acme.com');
      expect(domain.inboundMailboxAllowCompanyUsers, isTrue);
      expect(domain.inboundMailboxAllowVendors, isTrue);
      expect(domain.inboundMailboxAllowClients, isTrue);
      expect(domain.inboundMailboxWhitelist, 'trusted@vendor.com');
      expect(domain.inboundMailboxBlacklist, 'spam@vendor.com');
      expect(domain.inboundMailboxAllowUnknown, isTrue);

      final json = domain.toApiJson();
      expect(json['mark_expenses_invoiceable'], isTrue);
      expect(json['mark_expenses_paid'], isTrue);
      expect(json['convert_expense_currency'], isTrue);
      expect(json['invoice_expense_documents'], isTrue);
      expect(json['notify_vendor_when_paid'], isTrue);
      expect(json['calculate_expense_tax_by_amount'], isTrue);
      expect(json['expense_inclusive_taxes'], isTrue);
      expect(json['expense_mailbox_active'], isTrue);
      expect(json['expense_mailbox'], 'expenses@acme.com');
      expect(json['inbound_mailbox_allow_company_users'], isTrue);
      expect(json['inbound_mailbox_allow_vendors'], isTrue);
      expect(json['inbound_mailbox_allow_clients'], isTrue);
      expect(json['inbound_mailbox_whitelist'], 'trusted@vendor.com');
      expect(json['inbound_mailbox_blacklist'], 'spam@vendor.com');
      expect(json['inbound_mailbox_allow_unknown'], isTrue);
    });

    test('round-trips Integration top-level fields through '
        'fromApi → toApiJson', () {
      const api = CompanyApi(
        id: 'co',
        name: 'Acme',
        googleAnalyticsKey: 'UA-12345-1',
        matomoId: '42',
        matomoUrl: 'https://matomo.acme.com',
      );

      final domain = Company.fromApi(api);
      expect(domain.googleAnalyticsKey, 'UA-12345-1');
      expect(domain.matomoId, '42');
      expect(domain.matomoUrl, 'https://matomo.acme.com');

      final json = domain.toApiJson();
      expect(json['google_analytics_key'], 'UA-12345-1');
      expect(json['matomo_id'], '42');
      expect(json['matomo_url'], 'https://matomo.acme.com');
    });

    test('Task + Expense top-level fields default to false / empty when '
        'missing from the wire', () {
      final api = CompanyApi.fromJson(<String, dynamic>{'id': 'co'});
      final domain = Company.fromApi(api);
      // Spot-check one of each kind; the freezed factory's defaults handle
      // the rest uniformly.
      expect(domain.autoStartTasks, isFalse);
      expect(domain.invoiceTaskDocuments, isFalse);
      expect(domain.markExpensesPaid, isFalse);
      expect(domain.expenseMailboxActive, isFalse);
      expect(domain.expenseMailbox, '');
      expect(domain.inboundMailboxWhitelist, '');
    });
  });

  group('Company e_invoice blob mapping', () {
    final eInvoiceBlob = <String, dynamic>{
      'Invoice': {
        'PaymentMeans': [
          {
            'PaymentMeansCode': {'value': '58'},
            'PayeeFinancialAccount': {
              'ID': {'value': 'DE89370400440532013000'},
              'Name': 'Acme GmbH',
            },
          },
        ],
      },
    };

    test('fromJson + fromApi carry the e_invoice blob untouched', () {
      final api = CompanyApi.fromJson(<String, dynamic>{
        'id': 'co',
        'e_invoice': eInvoiceBlob,
      });
      expect(api.eInvoice, eInvoiceBlob);
      expect(Company.fromApi(api).eInvoice, eInvoiceBlob);
    });

    test('toApiJson omits e_invoice so a company PUT never clears the '
        'server-derived config', () {
      final domain = Company(id: 'co', name: 'Acme', eInvoice: eInvoiceBlob);
      expect(domain.toApiJson().containsKey('e_invoice'), isFalse);
    });

    test('e_invoice is null when missing from the wire', () {
      final api = CompanyApi.fromJson(<String, dynamic>{'id': 'co'});
      expect(api.eInvoice, isNull);
      expect(Company.fromApi(api).eInvoice, isNull);
    });
  });

  group('Company settings parse resilience', () {
    test('company-load tolerates mixed-type settings via lenient parse', () {
      // The server ships some settings as number-or-string / 0|1 bools, and
      // casts endless_reminder_frequency_id to int. Company.fromApi must use
      // the lenient parser (not strict fromJson, which threw on these wire
      // types) so a real company with legacy/mixed-type settings still loads.
      final api = CompanyApi.fromJson(<String, dynamic>{
        'id': 'co',
        'settings': <String, dynamic>{
          'endless_reminder_frequency_id': 1, // int → field is a wire-string
          'counter_padding': '4', // numeric shipped as a string
          'military_time': 1, // bool shipped as an int
        },
      });

      final company = Company.fromApi(api);
      expect(company.settings.endlessReminderFrequencyId, '1');
      expect(company.settings.counterPadding, 4);
      expect(company.settings.militaryTime, isTrue);
    });
  });
}
