import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/dashboard/helpers/enabled_panel_kinds.dart';

/// The gate the wide body, the mobile body and the manage sheet all read.
///
/// It is a shared function precisely because those three used to hold a copy
/// each, and three copies are where a new panel half-ships — rendered on
/// desktop, missing on mobile, inert in the manage sheet, each failure looking
/// correct on its own screen.

Set<String> _for(
  Set<EntityType> modules, {
  Set<String> permissions = const {},
}) => enabledPanelKinds(moduleOn: modules.contains, can: permissions.contains);

const _allModules = {
  EntityType.invoice,
  EntityType.payment,
  EntityType.quote,
  EntityType.recurringInvoice,
  EntityType.task,
};

const _allPermissions = {'view_task'};

void main() {
  test('everything enabled → every orderable panel', () {
    expect(
      _for(_allModules, permissions: _allPermissions),
      DashboardKind.panelKinds.toSet(),
    );
  });

  test('nothing enabled → nothing', () {
    expect(_for(const {}), isEmpty);
  });

  test('every panel kind is answerable', () {
    // A kind added to `panelKinds` without a line here would silently never
    // render — the gate would simply not contain it, on every surface at once.
    expect(
      DashboardKind.panelKinds.toSet().difference(
        _for(_allModules, permissions: _allPermissions),
      ),
      isEmpty,
    );
  });

  group('module gating', () {
    test('invoices carry both invoice panels', () {
      expect(_for(const {EntityType.invoice}), {
        DashboardKind.pastDue,
        DashboardKind.upcomingInvoices,
      });
    });

    test('quotes carry both quote panels', () {
      expect(_for(const {EntityType.quote}), {
        DashboardKind.upcomingQuotes,
        DashboardKind.expiredQuotes,
      });
    });

    test('payments and recurring invoices carry one each', () {
      expect(_for(const {EntityType.payment}), {DashboardKind.recentPayments});
      expect(_for(const {EntityType.recurringInvoice}), {
        DashboardKind.upcomingRecurring,
      });
    });
  });

  group('the task calendar is permission-gated, unlike its siblings', () {
    test('module on but no view_task → hidden', () {
      // Its six siblings render server-fed data the API has already
      // permission-scoped, so an empty card there honestly means "nothing to
      // show". This one reads the LOCAL tasks table: a user who cannot view
      // tasks has none in Drift, so an ungated grid would paint every day
      // unbooked — a positive claim of availability, not an absence of data.
      expect(_for(const {EntityType.task}), isEmpty);
    });

    test('view_task but module off → hidden', () {
      expect(_for(const {}, permissions: _allPermissions), isEmpty);
    });

    test('both → shown', () {
      expect(_for(const {EntityType.task}, permissions: _allPermissions), {
        DashboardKind.taskCalendar,
      });
    });

    test('no other panel is permission-gated', () {
      // Dropping every permission must leave exactly one kind behind.
      final withPerms = _for(_allModules, permissions: _allPermissions);
      final without = _for(_allModules);
      expect(withPerms.difference(without), {DashboardKind.taskCalendar});
    });
  });
}
