/// One activity row, parsed from either server shape:
///  * `GET /api/v1/activities?reactv2` — nested `{label, hashed_id}` objects
///    keyed by token (`user`, `client`, `invoice`, …), no flat ids. Both live
///    callers (the dashboard card and the per-user activity log) use this.
///  * `GET /api/v1/activities` without `reactv2` (via `ActivityTransformer`) —
///    flat `<token>_id`, no labels. Still parsed so a server predating the
///    `reactv2` branch degrades to unlabelled rows rather than empty ones.
///
/// Note `id` differs between them: the flat shape sends the hashed activity id,
/// `reactv2` sends the raw numeric one plus a separate `hashed_id`. Neither
/// screen renders or routes on it, so it's left as-is.
///
/// The dashboard renders these via `ActivityFormatter`, which interpolates the
/// `activity_<N>` localization key with `:user`, `:contact`, `:client`,
/// `:invoice`, etc. The raw payload is preserved so unknown activity types
/// still have a chance of rendering (fallback shows the activity id).
class DashboardActivity {
  const DashboardActivity({
    required this.id,
    required this.activityTypeId,
    required this.createdAt,
    required this.userId,
    required this.clientId,
    required this.contactId,
    required this.invoiceId,
    required this.quoteId,
    required this.paymentId,
    required this.expenseId,
    required this.recurringInvoiceId,
    this.taskId,
    this.creditId,
    this.vendorId,
    this.purchaseOrderId,
    this.recurringExpenseId,
    this.subscriptionId,
    required this.notes,
    this.labels = const <String, String>{},
    required this.raw,
  });

  final String id;
  final int activityTypeId;
  final int createdAt;
  final String? userId;
  final String? clientId;
  final String? contactId;
  final String? invoiceId;
  final String? quoteId;
  final String? paymentId;
  final String? expenseId;
  final String? recurringInvoiceId;
  final String? taskId;
  final String? creditId;
  final String? vendorId;
  final String? purchaseOrderId;
  final String? recurringExpenseId;
  final String? subscriptionId;
  final String notes;

  /// Display labels keyed by template token (`user`, `client`, `invoice`, …),
  /// populated from the `?reactv2` nested `{label, hashed_id}` objects. Empty
  /// for the flat `ActivityTransformer` shape, where the formatter falls back
  /// to the localized noun. Note the server emits an entry only for tokens the
  /// `activity_<N>` template actually contains, so a missing key means "this
  /// activity doesn't name that thing", not "the server didn't know it".
  final Map<String, String> labels;

  /// The full server JSON so a richer renderer can grab fields we don't
  /// destructure explicitly.
  final Map<String, dynamic> raw;

  static DashboardActivity fromJson(Map<String, dynamic> json) {
    int parseInt(Object? raw) {
      if (raw is int) return raw;
      return int.tryParse('$raw') ?? 0;
    }

    // Resolve a token's id from either shape: prefer the nested
    // `{label, hashed_id}` object (`?reactv2`), else the flat `<token>_id`
    // (`ActivityTransformer`). Gives navigation a target from both feeds.
    String? refId(String token) {
      final nested = json[token];
      if (nested is Map) {
        final hid = (nested['hashed_id'] ?? '').toString();
        return hid.isEmpty ? null : hid;
      }
      final flat = json['${token}_id'];
      final s = flat?.toString() ?? '';
      return s.isEmpty ? null : s;
    }

    // Capture every nested label object the server sent, keyed by token, so
    // any `:token` in the activity template resolves to a real name/number.
    // Absent for the flat `ActivityTransformer` shape (no nested objects).
    final labels = <String, String>{};
    json.forEach((key, value) {
      if (value is Map) {
        final label = (value['label'] ?? '').toString();
        if (label.isNotEmpty) labels[key] = label;
      }
    });

    return DashboardActivity(
      id: (json['id'] ?? '').toString(),
      activityTypeId: parseInt(json['activity_type_id']),
      createdAt: parseInt(json['created_at']),
      userId: refId('user'),
      clientId: refId('client'),
      contactId: refId('contact'),
      invoiceId: refId('invoice'),
      quoteId: refId('quote'),
      paymentId: refId('payment'),
      expenseId: refId('expense'),
      recurringInvoiceId: refId('recurring_invoice'),
      // Both feeds carry these too (ActivityTransformer flat ids; reactv2
      // nested objects via Activity::matchVar) — without them task / credit /
      // vendor / purchase-order activity rows were dead taps.
      taskId: refId('task'),
      creditId: refId('credit'),
      vendorId: refId('vendor'),
      purchaseOrderId: refId('purchase_order'),
      recurringExpenseId: refId('recurring_expense'),
      subscriptionId: refId('subscription'),
      notes: (json['notes'] ?? '').toString(),
      labels: labels,
      raw: json,
    );
  }

  static List<DashboardActivity> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Object>()
        .map((e) {
          if (e is Map<String, dynamic>) return DashboardActivity.fromJson(e);
          if (e is Map) {
            return DashboardActivity.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
          return null;
        })
        .whereType<DashboardActivity>()
        .toList(growable: false);
  }
}
