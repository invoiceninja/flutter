import 'dart:collection';

import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';

/// Lean view DTOs the dashboard list cards render. We don't reach for full
/// domain `Invoice`/`Payment`/`Quote`/`RecurringInvoice` models because M1
/// doesn't have them yet; if/when those land, the rows can be swapped to use
/// the canonical types.

/// The rows of one dashboard list, plus how many records the server says match
/// in all.
///
/// A dashboard list fetches one page of 50, so `length` answers "how many did
/// we download", not "how many are there" — and a panel that prints the first
/// as the second says "50 past due" for an account with 80. [total] is the
/// paginator's own figure for the query (`meta.pagination.total`).
///
/// It **is** a `List`, so every surface that takes the rows — the section
/// state, the cards, the emptiness check — keeps working untouched, and the
/// few that need the total read [DashboardRowsTotal.serverTotal] off the same
/// value.
class DashboardRows<T> extends UnmodifiableListView<T> {
  DashboardRows(super.source, {this.total});

  /// How many records match on the server, or null when the response carried
  /// no such figure (an older cached payload, an unpaginated endpoint). Null
  /// is "not known" — never zero, and never `length`.
  final int? total;

  /// Whether every matching record is in this list. False when the total is
  /// unknown: a sum or a count taken from an incomplete page is a guess.
  bool get isComplete => total != null && total == length;
}

extension DashboardRowsTotal<T> on List<T> {
  /// The server's total for this list — see [DashboardRows.total]. Null for a
  /// plain list.
  int? get serverTotal {
    final self = this;
    return self is DashboardRows<T> ? self.total : null;
  }

  /// See [DashboardRows.isComplete]. False for a plain list.
  bool get isCompleteList {
    final self = this;
    return self is DashboardRows<T> && self.isComplete;
  }
}

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
    this.partial,
    this.partialDueDate,
    this.userId = '',
    this.assignedUserId = '',
    this.lastReminderDate,
    this.remindersSent = 0,
    this.wasSent = false,
    this.lastViewed,
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

  /// The deposit this invoice asks for ahead of its own due date, and when it
  /// is due. The server's past-due list includes an invoice whose *deposit* is
  /// late while its own due date is still ahead, so "how late" and "how much
  /// is late" cannot be read off [dueDate] and [balance] alone — see
  /// `lateAmount` in `lib/domain/clients/client_past_due.dart`. Null / zero
  /// when no deposit is in play.
  final Decimal? partial;
  final Date? partialDueDate;

  /// Who created the invoice and who it is assigned to. The server lets either
  /// of them act on it without the `edit_invoice` permission
  /// (`AuthSession.canEditRecord`).
  final String userId;
  final String assignedUserId;

  /// When a payment reminder last went out, and how many of the three numbered
  /// reminders have. Decides which reminder a "Remind" action opens on, and
  /// whether another one is due at all.
  final Date? lastReminderDate;
  final int remindersSent;

  /// Whether the invoice was emailed to anyone, and when a recipient last
  /// opened it in the portal (device-local day). "Not opened" and "viewed
  /// Oct 2" call for different follow-ups.
  final bool wasSent;
  final Date? lastViewed;

  static DashboardInvoiceRow fromJson(Map<String, dynamic> json) {
    final client = _client(json['client']);
    final statusRaw = json['status_id'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse('$statusRaw') ?? 0;
    final partial = parseMoney(json['partial']);
    final reminders = [
      Date.tryParse(json['reminder1_sent']?.toString()),
      Date.tryParse(json['reminder2_sent']?.toString()),
      Date.tryParse(json['reminder3_sent']?.toString()),
    ];
    var wasSent = false;
    Date? lastViewed;
    final invitations = json['invitations'];
    if (invitations is List) {
      for (final raw in invitations) {
        if (raw is! Map) continue;
        if ((raw['sent_date'] ?? '').toString().isNotEmpty) wasSent = true;
        final viewed = _localDay(raw['viewed_date']);
        if (viewed != null &&
            (lastViewed == null || viewed.compareTo(lastViewed) > 0)) {
          lastViewed = viewed;
        }
      }
    }
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
      partial: partial > Decimal.zero ? partial : null,
      partialDueDate: Date.tryParse(json['partial_due_date']?.toString()),
      userId: (json['user_id'] ?? '').toString(),
      assignedUserId: (json['assigned_user_id'] ?? '').toString(),
      lastReminderDate:
          Date.tryParse(json['reminder_last_sent']?.toString()) ??
          _latest(reminders),
      remindersSent: reminders.where((d) => d != null).length,
      wasSent: wasSent,
      lastViewed: lastViewed,
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
    this.userId = '',
    this.assignedUserId = '',
  });

  final String id;
  final String number;
  final String clientId;
  final String clientName;
  final Date? date;

  /// The day the quote stops being valid — the wire's `due_date`.
  final Date? validUntil;

  /// See [DashboardInvoiceRow.userId].
  final String userId;
  final String assignedUserId;
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
      // `due_date` is what the server calls a quote's valid-until
      // (`QuoteTransformer`); there is no `valid_until` on the wire. Reading
      // that left this null on every row, so the Expired Quotes panel's
      // "Valid until" column was a column of dashes.
      validUntil: Date.tryParse(
        (json['due_date'] ?? json['valid_until'])?.toString(),
      ),
      userId: (json['user_id'] ?? '').toString(),
      assignedUserId: (json['assigned_user_id'] ?? '').toString(),
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

/// Decodes one cached list payload.
///
/// Two shapes: `{rows: [...], total: N}`, what the repository has written since
/// the lists started keeping the paginator's total, and a bare `[...]`, what
/// every install has cached from before (and what an unpaginated endpoint
/// still returns). The bare list decodes with an unknown total rather than
/// being discarded, so an upgrade shows yesterday's rows until the refresh
/// lands instead of a skeleton.
DashboardRows<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) build) {
  Object? rows = raw;
  int? total;
  if (raw is Map) {
    rows = raw['rows'];
    final t = raw['total'];
    total = t is int ? t : int.tryParse('$t');
    if (total != null && total < 0) total = null;
  }
  if (rows is! List) return DashboardRows<T>(<T>[], total: total);
  return DashboardRows<T>(
    rows
        .whereType<Object>()
        .map((e) {
          if (e is Map<String, dynamic>) return build(e);
          if (e is Map) {
            return build(e.map((k, v) => MapEntry(k.toString(), v)));
          }
          return null;
        })
        .whereType<T>()
        .toList(growable: false),
    total: total,
  );
}

/// The later of [dates], ignoring nulls; null when there are none.
Date? _latest(List<Date?> dates) {
  Date? latest;
  for (final d in dates) {
    if (d != null && (latest == null || d.compareTo(latest) > 0)) latest = d;
  }
  return latest;
}

/// The device-local calendar day of a server timestamp (`Y-m-d H:i:s`, UTC).
///
/// Not `Date.tryParse`, which keeps the UTC calendar date verbatim: a portal
/// view at 23:30 UTC is the next morning for a user east of Greenwich, and
/// "viewed Oct 2" would name a day they did not live it on.
Date? _localDay(Object? raw) {
  final text = (raw ?? '').toString();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse('${text.replaceFirst(' ', 'T')}Z');
  if (parsed == null) return Date.tryParse(text);
  final local = parsed.toLocal();
  return Date(local.year, local.month, local.day);
}
