import 'package:admin/data/repositories/dashboard_repository.dart';

/// User preference for one Dashboard list panel — its display order (the list
/// position) and whether it's shown. The panel set is fixed (the six
/// [DashboardKind.panelKinds] list-card kinds), so unlike [DashboardCardConfig]
/// there's nothing to compose: a panel is just a [kind] + a [visible] flag.
///
/// Persisted device-locally in the `dashboard` nav_state envelope as an ordered
/// array of `"<kind>|<1|0>"` strings (array order = render order). Hand-written
/// to match the rest of `models/domain/dashboard/`.
class DashboardPanelPref {
  const DashboardPanelPref({required this.kind, required this.visible});

  /// One of [DashboardKind.panelKinds].
  final String kind;
  final bool visible;

  DashboardPanelPref copyWith({bool? visible}) =>
      DashboardPanelPref(kind: kind, visible: visible ?? this.visible);

  /// Persisted form: `"<kind>|<1|0>"` (mirrors [DashboardCardConfig.toJson]).
  String toJson() => '$kind|${visible ? 1 : 0}';

  /// Parse a `"<kind>|<1|0>"` entry. Strict: returns null unless there are
  /// exactly two parts and the visible token is exactly `0` or `1` — so a
  /// corrupt `"past_due|"` is dropped (and re-defaulted by the hydrator), not
  /// silently treated as hidden. The caller validates [kind] against
  /// [DashboardKind.panelKinds] and skips nulls.
  static DashboardPanelPref? tryParse(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final kind = parts[0];
    if (kind.isEmpty) return null;
    final v = parts[1];
    if (v != '0' && v != '1') return null;
    return DashboardPanelPref(kind: kind, visible: v == '1');
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardPanelPref &&
      other.kind == kind &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(kind, visible);
}

/// Localization key for a panel's title — reuses each list card's own header
/// key so the manage list reads identically to the dashboard.
String panelTitleKey(String kind) => switch (kind) {
  DashboardKind.pastDue => 'needs_your_attention',
  DashboardKind.upcomingInvoices => 'upcoming_invoices',
  DashboardKind.recentPayments => 'recent_payments',
  DashboardKind.upcomingQuotes => 'upcoming_quotes',
  DashboardKind.expiredQuotes => 'expired_quotes',
  DashboardKind.upcomingRecurring => 'upcoming_recurring_invoices',
  _ => kind,
};
