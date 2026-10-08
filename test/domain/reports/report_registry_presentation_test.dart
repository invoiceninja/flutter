import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/domain/reports/report_registry.dart';

/// The server's default column set for each report, as it answered a plain
/// run on the demo server (2026-10-08). The registry names columns by id in
/// three places — the default visible set, the headline figures and the
/// starter views — and an id the server does not return is silently ignored,
/// so a typo there would not fail anything; it would just quietly not be on
/// screen. This is what a typo fails against.
const Map<String, Set<String>> _kServerColumns = {
  'invoice': {
    'client.name',
    'client.currency_id',
    'invoice.number',
    'invoice.subtotal',
    'invoice.amount',
    'invoice.balance',
    'invoice.paid_to_date',
    'invoice.po_number',
    'invoice.date',
    'invoice.due_date',
    'invoice.terms',
    'invoice.footer',
    'invoice.status',
    'invoice.public_notes',
    'invoice.private_notes',
    'invoice.uses_inclusive_taxes',
    'invoice.is_amount_discount',
    'invoice.discount',
    'invoice.partial',
    'invoice.partial_due_date',
    'invoice.custom_surcharge1',
    'invoice.custom_surcharge2',
    'invoice.custom_surcharge3',
    'invoice.custom_surcharge4',
    'invoice.exchange_rate',
    'invoice.total_taxes',
    'invoice.assigned_user_id',
    'invoice.user_id',
    'invoice.custom_value1',
    'invoice.custom_value2',
    'invoice.custom_value3',
    'invoice.custom_value4',
    'invoice.tax_name1',
    'invoice.tax_name2',
    'invoice.tax_name3',
    'invoice.tax_rate1',
    'invoice.tax_rate2',
    'invoice.tax_rate3',
    'invoice.recurring_id',
    'invoice.auto_bill_enabled',
    'invoice.project',
    'invoice.tags',
  },
  'client': {
    'client.name',
    'client.number',
    'client.user',
    'client.assigned_user',
    'client.balance',
    'client.paid_to_date',
    'client.currency_id',
    'client.website',
    'client.private_notes',
    'client.industry_id',
    'client.size_id',
    'client.phone',
    'client.address1',
    'client.address2',
    'client.city',
    'client.state',
    'client.postal_code',
    'client.country_id',
    'client.shipping_address1',
    'client.shipping_address2',
    'client.shipping_city',
    'client.shipping_state',
    'client.shipping_postal_code',
    'client.shipping_country_id',
    'client.payment_terms',
    'client.vat_number',
    'client.id_number',
    'client.public_notes',
    'contact.phone',
    'contact.first_name',
    'contact.last_name',
    'contact.email',
    'client.custom_value1',
    'client.custom_value2',
    'client.custom_value3',
    'client.custom_value4',
    'contact.custom_value1',
    'contact.custom_value2',
    'contact.custom_value3',
    'contact.custom_value4',
    'client.payment_balance',
    'client.credit_balance',
    'client.classification',
    'client.tags',
  },
  'invoice_item': {
    'client.name',
    'client.currency_id',
    'invoice.number',
    'invoice.subtotal',
    'invoice.amount',
    'invoice.balance',
    'invoice.paid_to_date',
    'invoice.po_number',
    'invoice.date',
    'invoice.due_date',
    'invoice.terms',
    'invoice.footer',
    'invoice.status',
    'invoice.public_notes',
    'invoice.private_notes',
    'invoice.uses_inclusive_taxes',
    'invoice.is_amount_discount',
    'invoice.discount',
    'invoice.partial',
    'invoice.partial_due_date',
    'invoice.custom_surcharge1',
    'invoice.custom_surcharge2',
    'invoice.custom_surcharge3',
    'invoice.custom_surcharge4',
    'invoice.exchange_rate',
    'invoice.total_taxes',
    'invoice.assigned_user_id',
    'invoice.user_id',
    'invoice.custom_value1',
    'invoice.custom_value2',
    'invoice.custom_value3',
    'invoice.custom_value4',
    'invoice.tax_name1',
    'invoice.tax_name2',
    'invoice.tax_name3',
    'invoice.tax_rate1',
    'invoice.tax_rate2',
    'invoice.tax_rate3',
    'invoice.recurring_id',
    'invoice.auto_bill_enabled',
    'invoice.project',
    'invoice.tags',
    'item.quantity',
    'item.cost',
    'item.product_key',
    'item.notes',
    'item.tax_name1',
    'item.tax_rate1',
    'item.tax_name2',
    'item.tax_rate2',
    'item.tax_name3',
    'item.tax_rate3',
    'item.custom_value1',
    'item.custom_value2',
    'item.custom_value3',
    'item.custom_value4',
    'item.discount',
    'item.type_id',
    'item.tax_id',
    'item.is_amount_discount',
    'item.line_total',
    'item.gross_line_total',
    'item.tax_amount',
    'item.product_cost',
  },
  'quote': {
    'client.name',
    'client.currency_id',
    'quote.custom_value1',
    'quote.custom_value2',
    'quote.custom_value3',
    'quote.custom_value4',
    'quote.number',
    'quote.amount',
    'quote.balance',
    'quote.paid_to_date',
    'quote.po_number',
    'quote.date',
    'quote.due_date',
    'quote.terms',
    'quote.footer',
    'quote.status',
    'quote.public_notes',
    'quote.private_notes',
    'quote.uses_inclusive_taxes',
    'quote.is_amount_discount',
    'quote.discount',
    'quote.partial',
    'quote.partial_due_date',
    'quote.custom_surcharge1',
    'quote.custom_surcharge2',
    'quote.custom_surcharge3',
    'quote.custom_surcharge4',
    'quote.exchange_rate',
    'quote.total_taxes',
    'quote.assigned_user_id',
    'quote.user_id',
    'quote.tax_name1',
    'quote.tax_name2',
    'quote.tax_name3',
    'quote.tax_rate1',
    'quote.tax_rate2',
    'quote.tax_rate3',
    'quote.subtotal',
    'quote.tags',
  },
  'credit': {
    'client.name',
    'client.currency_id',
    'credit.number',
    'credit.amount',
    'credit.balance',
    'credit.paid_to_date',
    'credit.po_number',
    'credit.date',
    'credit.due_date',
    'credit.terms',
    'credit.discount',
    'credit.footer',
    'credit.status',
    'credit.public_notes',
    'credit.private_notes',
    'credit.uses_inclusive_taxes',
    'credit.is_amount_discount',
    'credit.partial',
    'credit.partial_due_date',
    'credit.custom_surcharge1',
    'credit.custom_surcharge2',
    'credit.custom_surcharge3',
    'credit.custom_surcharge4',
    'credit.custom_value1',
    'credit.custom_value2',
    'credit.custom_value3',
    'credit.custom_value4',
    'credit.exchange_rate',
    'credit.total_taxes',
    'credit.assigned_user_id',
    'credit.user_id',
    'credit.subtotal',
    'credit.tags',
  },
  'payment': {
    'client.name',
    'payment.date',
    'payment.amount',
    'payment.refunded',
    'payment.applied',
    'payment.applied_date',
    'payment.applied_amount',
    'payment.applied_refunded',
    'payment.transaction_reference',
    'payment.currency',
    'payment.exchange_rate',
    'payment.number',
    'payment.method',
    'payment.status',
    'payment.private_notes',
    'payment.custom_value1',
    'payment.custom_value2',
    'payment.custom_value3',
    'payment.custom_value4',
    'payment.user_id',
    'payment.assigned_user_id',
    'payment.tags',
  },
  'expense': {
    'expense.amount',
    'expense.tax_amount',
    'expense.net_amount',
    'expense.category_id',
    'expense.custom_value1',
    'expense.custom_value2',
    'expense.custom_value3',
    'expense.custom_value4',
    'expense.currency_id',
    'expense.date',
    'expense.exchange_rate',
    'expense.foreign_amount',
    'expense.invoice_currency_id',
    'expense.payment_date',
    'expense.number',
    'expense.payment_type_id',
    'expense.private_notes',
    'expense.project_id',
    'expense.public_notes',
    'expense.tax_amount1',
    'expense.tax_amount2',
    'expense.tax_amount3',
    'expense.tax_name1',
    'expense.tax_name2',
    'expense.tax_name3',
    'expense.tax_rate1',
    'expense.tax_rate2',
    'expense.tax_rate3',
    'expense.transaction_reference',
    'expense.vendor_id',
    'expense.invoice_id',
    'expense.user',
    'expense.assigned_user',
    'expense.tags',
  },
  'task': {
    'task.start_date',
    'task.start_time',
    'task.end_date',
    'task.end_time',
    'task.duration',
    'task.duration_words',
    'task.due_date',
    'task.estimated_duration',
    'task.rate',
    'task.number',
    'task.description',
    'task.custom_value1',
    'task.custom_value2',
    'task.custom_value3',
    'task.custom_value4',
    'task.status_id',
    'task.project_id',
    'task.billable',
    'task.item_notes',
    'task.time_log',
    'task.time_log_duration_words',
    'task.user_id',
    'task.assigned_user_id',
    'task.tags',
    'client.name',
  },
  'product': {
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
    'product_key',
    'notes',
    'cost',
    'price',
    'quantity',
    'tax_rate1',
    'tax_rate2',
    'tax_rate3',
    'tax_name1',
    'tax_name2',
    'tax_name3',
    'product_image',
    'tax_id',
    'max_quantity',
    'in_stock_quantity',
    'product.tags',
  },
  'contact': {
    'client.name',
    'client.number',
    'client.user',
    'client.assigned_user',
    'client.balance',
    'client.paid_to_date',
    'client.currency_id',
    'client.website',
    'client.private_notes',
    'client.industry_id',
    'client.size_id',
    'client.phone',
    'client.address1',
    'client.address2',
    'client.city',
    'client.state',
    'client.postal_code',
    'client.country_id',
    'client.shipping_address1',
    'client.shipping_address2',
    'client.shipping_city',
    'client.shipping_state',
    'client.shipping_postal_code',
    'client.shipping_country_id',
    'client.payment_terms',
    'client.vat_number',
    'client.id_number',
    'client.public_notes',
    'contact.phone',
    'contact.first_name',
    'contact.last_name',
    'contact.email',
    'client.custom_value1',
    'client.custom_value2',
    'client.custom_value3',
    'client.custom_value4',
    'contact.custom_value1',
    'contact.custom_value2',
    'contact.custom_value3',
    'contact.custom_value4',
    'client.payment_balance',
    'client.credit_balance',
    'client.classification',
    'client.tags',
  },
  'purchase_order': {
    'purchase_order.amount',
    'purchase_order.balance',
    'purchase_order.vendor_id',
    'purchase_order.custom_value1',
    'purchase_order.custom_value2',
    'purchase_order.custom_value3',
    'purchase_order.custom_value4',
    'purchase_order.date',
    'purchase_order.discount',
    'purchase_order.due_date',
    'purchase_order.exchange_rate',
    'purchase_order.footer',
    'purchase_order.number',
    'purchase_order.paid_to_date',
    'purchase_order.partial',
    'purchase_order.partial_due_date',
    'purchase_order.po_number',
    'purchase_order.private_notes',
    'purchase_order.public_notes',
    'purchase_order.status',
    'purchase_order.tax_name1',
    'purchase_order.tax_name2',
    'purchase_order.tax_name3',
    'purchase_order.tax_rate1',
    'purchase_order.tax_rate2',
    'purchase_order.tax_rate3',
    'purchase_order.terms',
    'purchase_order.total_taxes',
    'purchase_order.currency_id',
    'purchase_order.subtotal',
    'purchase_order.tags',
    'vendor.name',
  },
  'recurring_invoice_item': {
    'client.name',
    'client.currency_id',
    'recurring_invoice.number',
    'recurring_invoice.amount',
    'recurring_invoice.balance',
    'recurring_invoice.paid_to_date',
    'recurring_invoice.po_number',
    'recurring_invoice.date',
    'recurring_invoice.due_date',
    'recurring_invoice.terms',
    'recurring_invoice.footer',
    'recurring_invoice.status',
    'recurring_invoice.public_notes',
    'recurring_invoice.private_notes',
    'recurring_invoice.uses_inclusive_taxes',
    'recurring_invoice.is_amount_discount',
    'recurring_invoice.discount',
    'recurring_invoice.partial',
    'recurring_invoice.partial_due_date',
    'recurring_invoice.custom_surcharge1',
    'recurring_invoice.custom_surcharge2',
    'recurring_invoice.custom_surcharge3',
    'recurring_invoice.custom_surcharge4',
    'recurring_invoice.exchange_rate',
    'recurring_invoice.total_taxes',
    'recurring_invoice.assigned_user_id',
    'recurring_invoice.user_id',
    'recurring_invoice.frequency_id',
    'recurring_invoice.remaining_cycles',
    'recurring_invoice.next_send_date',
    'recurring_invoice.custom_value1',
    'recurring_invoice.custom_value2',
    'recurring_invoice.custom_value3',
    'recurring_invoice.custom_value4',
    'recurring_invoice.tax_name1',
    'recurring_invoice.tax_name2',
    'recurring_invoice.tax_name3',
    'recurring_invoice.tax_rate1',
    'recurring_invoice.tax_rate2',
    'recurring_invoice.tax_rate3',
    'recurring_invoice.auto_bill',
    'recurring_invoice.auto_bill_enabled',
    'recurring_invoice.tags',
    'item.quantity',
    'item.cost',
    'item.product_key',
    'item.notes',
    'item.tax_name1',
    'item.tax_rate1',
    'item.tax_name2',
    'item.tax_rate2',
    'item.tax_name3',
    'item.tax_rate3',
    'item.custom_value1',
    'item.custom_value2',
    'item.custom_value3',
    'item.custom_value4',
    'item.discount',
    'item.type_id',
    'item.tax_id',
    'item.is_amount_discount',
    'item.line_total',
    'item.gross_line_total',
    'item.tax_amount',
    'item.product_cost',
  },
};

/// Columns the app adds to a report itself.
const Map<String, Set<String>> _kLocalColumns = {
  'product': {'stock_value'},
};

Map<String, dynamic> _bundle(String name) =>
    jsonDecode(File('assets/i18n/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final en = _bundle('en');
  final pending = _bundle('_app_pending');
  bool resolves(String key) {
    final value = en[key] ?? pending[key];
    return value is String && value.trim().isNotEmpty;
  }

  test('every id the registry names is one the server returns', () {
    for (final d in kReportDefinitions) {
      final server = _kServerColumns[d.identifier];
      if (server == null) continue;
      final known = {...server, ...?_kLocalColumns[d.identifier]};
      final named = {
        ...d.defaultColumnIds,
        ...d.headlineMeasureIds,
        for (final v in d.starterViews) v.group,
        for (final v in d.starterViews) ?v.measure,
      };
      expect(
        named.difference(known),
        isEmpty,
        reason: '${d.identifier} names a column the server does not return',
      );
    }
  });

  test('every report whose columns were probed is covered above', () {
    // A report that grows a curated column set needs its server set here.
    for (final d in kReportDefinitions) {
      if (d.defaultColumnIds.isEmpty) continue;
      if (_kUnprobed.contains(d.identifier)) continue;
      expect(
        _kServerColumns.containsKey(d.identifier),
        isTrue,
        reason: '${d.identifier} has default columns but no probed set',
      );
    }
  });

  test('a headline figure is a column the report shows by default', () {
    for (final d in kReportDefinitions) {
      if (d.defaultColumnIds.isEmpty) continue;
      expect(
        d.defaultColumnIds.toSet().containsAll(d.headlineMeasureIds),
        isTrue,
        reason: '${d.identifier}: a figure above a table that does not show it',
      );
    }
  });

  test('every category heading and starter label resolves', () {
    for (final c in ReportCategory.values) {
      expect(resolves(c.labelKey), isTrue, reason: c.labelKey);
    }
    for (final d in kReportDefinitions) {
      for (final v in d.starterViews) {
        expect(
          resolves(v.labelKey),
          isTrue,
          reason: '${d.identifier}: ${v.labelKey}',
        );
      }
    }
  });

  test('a starter view on a date names its granularity', () {
    for (final d in kReportDefinitions) {
      for (final v in d.starterViews) {
        final isDate = v.group.endsWith('.date') || v.group.endsWith('_date');
        expect(
          v.subgroup != null,
          isDate,
          reason: '${d.identifier}: ${v.group}',
        );
      }
    }
  });

  test('a report of things that happen opens on a year', () {
    for (final id in const ['invoice', 'payment', 'expense', 'task', 'quote']) {
      expect(
        reportDefinitionFor(id).defaultRange,
        ReportDatePreset.thisYear,
        reason: id,
      );
    }
    // A report of things that exist opens on all of them.
    for (final id in const ['client', 'product', 'vendor', 'contact']) {
      expect(
        reportDefinitionFor(id).defaultRange,
        ReportDatePreset.allTime,
        reason: id,
      );
    }
  });

  test('a list-first report does not open grouped', () {
    expect(reportDefinitionFor('client').openingView, isNull);
    expect(reportDefinitionFor('invoice').openingView?.group, 'invoice.date');
    expect(reportDefinitionFor('document').openingView, isNull);
  });

  test('every report has a category', () {
    final byCategory = <ReportCategory, int>{};
    for (final d in kReportDefinitions) {
      byCategory[d.category] = (byCategory[d.category] ?? 0) + 1;
    }
    expect(byCategory.keys.toSet(), ReportCategory.values.toSet());
  });
}

/// Reports with a curated column set whose live default set was not captured
/// (the demo queue timed out, or the report had no rows): their ids were
/// read off `BaseExport`'s key maps instead.
const Set<String> _kUnprobed = {
  'vendor',
  'quote_item',
  'purchase_order_item',
  'recurring_invoice',
};
