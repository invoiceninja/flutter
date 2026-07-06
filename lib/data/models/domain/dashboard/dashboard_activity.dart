/// One activity row, parsed from either server shape:
///  * `GET /api/v1/activities?reactv2` (dashboard) — nested `{label, hashed_id}`
///    objects keyed by token (`user`, `client`, `invoice`, …), no flat ids.
///  * `GET /api/v1/activities?user_id=` (user-activity feed, via
///    `ActivityTransformer`) — flat `<token>_id`, no labels.
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
  final String notes;

  /// Display labels keyed by template token (`user`, `client`, `invoice`, …),
  /// populated from the `?reactv2` nested `{label, hashed_id}` objects. Empty
  /// for the flat `ActivityTransformer` shape (user-activity feed), where the
  /// formatter falls back to the localized noun.
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
