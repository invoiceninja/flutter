import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/dashboard/helpers/card_deep_link.dart';

DashboardCardConfig _cfg(String field) => DashboardCardConfig(
  field: field,
  period: CardPeriod.current,
  calculate: CardCalc.sum,
  format: CardFormat.money,
);

void main() {
  group('cardListTarget', () {
    final expected =
        <String, ({EntityType e, String route, Map<String, Set<String>> f})>{
          'active_invoices': (
            e: EntityType.invoice,
            route: '/invoices',
            f: {
              'status_id': {'2', '3', '4'},
            },
          ),
          'outstanding_invoices': (
            e: EntityType.invoice,
            route: '/invoices',
            f: {
              'client_status': {'unpaid'},
            },
          ),
          'completed_payments': (
            e: EntityType.payment,
            route: '/payments',
            f: {
              'client_status': {'completed'},
            },
          ),
          'refunded_payments': (
            e: EntityType.payment,
            route: '/payments',
            f: {
              'client_status': {'refunded', 'partially_refunded'},
            },
          ),
          'active_quotes': (
            e: EntityType.quote,
            route: '/quotes',
            f: {
              'client_status': {'sent', 'approved'},
            },
          ),
          'unapproved_quotes': (
            e: EntityType.quote,
            route: '/quotes',
            f: {
              'client_status': {'sent'},
            },
          ),
          'logged_tasks': (e: EntityType.task, route: '/tasks', f: {}),
          'invoiced_tasks': (e: EntityType.task, route: '/tasks', f: {}),
          'paid_tasks': (e: EntityType.task, route: '/tasks', f: {}),
          'task_estimated_duration': (
            e: EntityType.task,
            route: '/tasks',
            f: {},
          ),
          'task_remaining_estimated_duration': (
            e: EntityType.task,
            route: '/tasks',
            f: {},
          ),
          'unestimated_tasks': (e: EntityType.task, route: '/tasks', f: {}),
          'tasks_over_estimate': (e: EntityType.task, route: '/tasks', f: {}),
          'overdue_tasks': (e: EntityType.task, route: '/tasks', f: {}),
          'tasks_due': (e: EntityType.task, route: '/tasks', f: {}),
          'logged_expenses': (e: EntityType.expense, route: '/expenses', f: {}),
          'pending_expenses': (
            e: EntityType.expense,
            route: '/expenses',
            f: {},
          ),
          'invoiced_expenses': (
            e: EntityType.expense,
            route: '/expenses',
            f: {},
          ),
          'invoice_paid_expenses': (
            e: EntityType.expense,
            route: '/expenses',
            f: {},
          ),
        };

    test('every kDashboardCardFields entry has an expectation', () {
      expect(expected.keys.toSet(), kDashboardCardFields.toSet());
    });

    for (final field in kDashboardCardFields) {
      test('$field → correct route + filter', () {
        final t = cardListTarget(_cfg(field));
        final exp = expected[field]!;
        expect(t.entity, exp.e);
        expect(t.route, exp.route);
        expect(t.extraFilters, exp.f);
      });
    }

    test('task/expense metrics open a bare list (documented gap)', () {
      for (final f in [
        'invoiced_tasks',
        'paid_tasks',
        'pending_expenses',
        'invoiced_expenses',
        'invoice_paid_expenses',
      ]) {
        expect(cardListTarget(_cfg(f)).extraFilters, isEmpty);
      }
    });
  });
}
