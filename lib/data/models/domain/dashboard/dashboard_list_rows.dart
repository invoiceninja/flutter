import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';

/// Lean view DTOs the dashboard list cards render. We don't reach for full
/// domain `Invoice`/`Payment`/`Quote`/`RecurringInvoice` models because M1
/// doesn't have them yet; if/when those land, the rows can be swapped to use
/// the canonical types.

class DashboardInvoiceRow {
  const DashboardInvoiceRow({
    required this.id,
    required this.number,
    required this.clientId,
    required this.clientName,
    required this.dueDate,
    required this.balance,
    required this.amount,
    required this.statusId,
    required this.currencyId,
  });

  final String id;
  final String number;
  final String clientId;
  final String clientName;
  final Date? dueDate;
  final Decimal balance;
  final Decimal amount;
  final int statusId;
  final String currencyId;

  static DashboardInvoiceRow fromJson(Map<String, dynamic> json) {
    final client = _client(json['client']);
    final statusRaw = json['status_id'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse('$statusRaw') ?? 0;
    return DashboardInvoiceRow(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      clientId: (json['client_id'] ?? client['id'] ?? '').toString(),
      clientName: (client['display_name'] ?? client['name'] ?? '').toString(),
      dueDate: Date.tryParse(json['due_date']?.toString()),
      balance: parseMoney(json['balance']),
      amount: parseMoney(json['amount']),
      statusId: status,
      currencyId: _clientCurrencyId(client),
    );
  }

  static List<DashboardInvoiceRow> listFromJson(Object? raw) =>
      _list(raw, DashboardInvoiceRow.fromJson);
}

class DashboardPaymentRow {
  const DashboardPaymentRow({
    required this.id,
    required this.number,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.amount,
    required this.statusId,
    required this.currencyId,
  });

  final String id;
  final String number;
  final String clientId;
  final String clientName;
  final Date? date;
  final Decimal amount;
  final int statusId;
  final String currencyId;

  static DashboardPaymentRow fromJson(Map<String, dynamic> json) {
    final client = _client(json['client']);
    final statusRaw = json['status_id'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse('$statusRaw') ?? 0;
    return DashboardPaymentRow(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      clientId: (json['client_id'] ?? client['id'] ?? '').toString(),
      clientName: (client['display_name'] ?? client['name'] ?? '').toString(),
      date: Date.tryParse(json['date']?.toString()),
      amount: parseMoney(json['amount']),
      statusId: status,
      currencyId: (json['currency_id'] ?? client['currency_id'] ?? '')
          .toString(),
    );
  }

  static List<DashboardPaymentRow> listFromJson(Object? raw) =>
      _list(raw, DashboardPaymentRow.fromJson);
}

class DashboardQuoteRow {
  const DashboardQuoteRow({
    required this.id,
    required this.number,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.validUntil,
    required this.amount,
    required this.statusId,
    required this.currencyId,
  });

  final String id;
  final String number;
  final String clientId;
  final String clientName;
  final Date? date;
  final Date? validUntil;
  final Decimal amount;
  final int statusId;
  final String currencyId;

  static DashboardQuoteRow fromJson(Map<String, dynamic> json) {
    final client = _client(json['client']);
    final statusRaw = json['status_id'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse('$statusRaw') ?? 0;
    return DashboardQuoteRow(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      clientId: (json['client_id'] ?? client['id'] ?? '').toString(),
      clientName: (client['display_name'] ?? client['name'] ?? '').toString(),
      date: Date.tryParse(json['date']?.toString()),
      validUntil: Date.tryParse(json['valid_until']?.toString()),
      amount: parseMoney(json['amount']),
      statusId: status,
      currencyId: _clientCurrencyId(client),
    );
  }

  static List<DashboardQuoteRow> listFromJson(Object? raw) =>
      _list(raw, DashboardQuoteRow.fromJson);
}

class DashboardRecurringInvoiceRow {
  const DashboardRecurringInvoiceRow({
    required this.id,
    required this.number,
    required this.clientId,
    required this.clientName,
    required this.nextSendDate,
    required this.amount,
    required this.statusId,
    required this.currencyId,
    required this.frequencyId,
  });

  final String id;
  final String number;
  final String clientId;
  final String clientName;
  final Date? nextSendDate;
  final Decimal amount;
  final int statusId;
  final String currencyId;
  final int frequencyId;

  static DashboardRecurringInvoiceRow fromJson(Map<String, dynamic> json) {
    final client = _client(json['client']);
    final statusRaw = json['status_id'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse('$statusRaw') ?? 0;
    final freqRaw = json['frequency_id'];
    final freq = freqRaw is int ? freqRaw : int.tryParse('$freqRaw') ?? 0;
    return DashboardRecurringInvoiceRow(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      clientId: (json['client_id'] ?? client['id'] ?? '').toString(),
      clientName: (client['display_name'] ?? client['name'] ?? '').toString(),
      nextSendDate: Date.tryParse(json['next_send_date']?.toString()),
      amount: parseMoney(json['amount']),
      statusId: status,
      currencyId: _clientCurrencyId(client),
      frequencyId: freq,
    );
  }

  static List<DashboardRecurringInvoiceRow> listFromJson(Object? raw) =>
      _list(raw, DashboardRecurringInvoiceRow.fromJson);
}

// ---------------------------------------------------------------------------
// Internals

Map<String, dynamic> _client(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

/// A client's currency id lives in `client.settings.currency_id` (the cascade
/// override), NOT top-level — ClientTransformer never emits a top-level
/// `currency_id`. Reading top-level always yielded '' so every cross-currency
/// client's dashboard amounts rendered in the company currency. Empty when the
/// client has no override (correct — the render then falls back to company).
String _clientCurrencyId(Map<String, dynamic> client) {
  final settings = client['settings'];
  final fromSettings = settings is Map ? settings['currency_id'] : null;
  return (fromSettings ?? client['currency_id'] ?? '').toString();
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) build) {
  if (raw is! List) return const [];
  return raw
      .whereType<Object>()
      .map((e) {
        if (e is Map<String, dynamic>) return build(e);
        if (e is Map) return build(e.map((k, v) => MapEntry(k.toString(), v)));
        return null;
      })
      .whereType<T>()
      .toList(growable: false);
}
