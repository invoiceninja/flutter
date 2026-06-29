import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';

void main() {
  group('DashboardPanelPref', () {
    test('toJson round-trips through tryParse (visible + hidden)', () {
      const visible = DashboardPanelPref(
        kind: DashboardKind.recentPayments,
        visible: true,
      );
      expect(visible.toJson(), 'recent_payments|1');
      expect(DashboardPanelPref.tryParse(visible.toJson()), visible);

      const hidden = DashboardPanelPref(
        kind: DashboardKind.expiredQuotes,
        visible: false,
      );
      expect(hidden.toJson(), 'expired_quotes|0');
      expect(DashboardPanelPref.tryParse(hidden.toJson()), hidden);
    });

    test('malformed inputs return null (strict 0/1 visible token)', () {
      expect(DashboardPanelPref.tryParse(null), isNull);
      expect(DashboardPanelPref.tryParse(42), isNull);
      expect(DashboardPanelPref.tryParse('past_due'), isNull); // no separator
      expect(DashboardPanelPref.tryParse('past_due|'), isNull); // empty token
      expect(DashboardPanelPref.tryParse('|1'), isNull); // empty kind
      expect(DashboardPanelPref.tryParse('past_due|2'), isNull); // not 0/1
      expect(DashboardPanelPref.tryParse('past_due|true'), isNull);
      expect(DashboardPanelPref.tryParse('a|1|b'), isNull); // wrong arity
    });

    test('copyWith flips visibility, keeps kind; no-arg keeps value', () {
      const p = DashboardPanelPref(kind: DashboardKind.pastDue, visible: true);
      final hidden = p.copyWith(visible: false);
      expect(hidden.kind, DashboardKind.pastDue);
      expect(hidden.visible, isFalse);
      expect(p.copyWith().visible, isTrue);
    });

    test('value equality + hashCode over (kind, visible)', () {
      const a = DashboardPanelPref(kind: DashboardKind.pastDue, visible: true);
      const b = DashboardPanelPref(kind: DashboardKind.pastDue, visible: true);
      const c = DashboardPanelPref(kind: DashboardKind.pastDue, visible: false);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('panelTitleKey maps each kind to its card header key', () {
      expect(panelTitleKey(DashboardKind.pastDue), 'needs_your_attention');
      expect(
        panelTitleKey(DashboardKind.upcomingInvoices),
        'upcoming_invoices',
      );
      expect(panelTitleKey(DashboardKind.recentPayments), 'recent_payments');
      expect(panelTitleKey(DashboardKind.upcomingQuotes), 'upcoming_quotes');
      expect(panelTitleKey(DashboardKind.expiredQuotes), 'expired_quotes');
      expect(
        panelTitleKey(DashboardKind.upcomingRecurring),
        'upcoming_recurring_invoices',
      );
      expect(panelTitleKey('unknown'), 'unknown'); // fallthrough
    });

    test('panelKinds is the six list panels in default render order', () {
      expect(DashboardKind.panelKinds, const [
        'past_due',
        'upcoming_invoices',
        'recent_payments',
        'upcoming_quotes',
        'expired_quotes',
        'upcoming_recurring',
      ]);
    });
  });
}
