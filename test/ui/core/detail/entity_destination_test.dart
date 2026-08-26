import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/detail/entity_destination.dart';

class _NoopDispatcher implements SyncDispatcher {
  @override
  Future<void> dispatch({
    required dynamic row,
    required MutationKind kind,
  }) async {}
  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}
}

EntityHandlers _handlers(EntityType type, String routePath) => EntityHandlers(
  type: type,
  wireName: type.name,
  apiPath: '/api/v1/${type.name}',
  routePath: routePath,
  icon: Icons.circle,
  dispatcher: _NoopDispatcher(),
);

/// A sync failure's "View" action used to build `'<routePath>/<id>/edit'`
/// unconditionally. For `company` (`/settings/company_details`, whose only
/// children are tab slugs) and `user` (`/settings/account`, not a route at
/// all) that matches nothing, and go_router's top-level errorBuilder then
/// replaces the whole app with the route-error screen — outside the shell.
void main() {
  test('an ordinary entity keeps the record route', () {
    expect(
      entityDestination(
        handlers: _handlers(EntityType.invoice, '/invoices'),
        entityId: 'inv1',
      ),
      '/invoices/inv1',
    );
    expect(
      entityDestination(
        handlers: _handlers(EntityType.invoice, '/invoices'),
        entityId: 'inv1',
        edit: true,
      ),
      '/invoices/inv1/edit',
    );
  });

  test('company goes to Company Details, never <path>/<id>', () {
    final dest = entityDestination(
      handlers: _handlers(EntityType.company, '/settings/company_details'),
      entityId: 'co1',
      edit: true,
    );
    expect(dest, '/settings/company_details');
    expect(dest.contains('co1'), isFalse);
    expect(dest.endsWith('/edit'), isFalse);
  });

  test('user goes to User Details, never the unrouted /settings/account', () {
    final dest = entityDestination(
      handlers: _handlers(EntityType.user, '/settings/account'),
      entityId: 'u1',
      edit: true,
    );
    expect(dest, '/settings/user_details');
    expect(dest.contains('/settings/account'), isFalse);
  });

  test('design goes to the Custom Designs tab', () {
    expect(
      entityDestination(
        handlers: _handlers(EntityType.design, '/settings/custom_designs'),
        entityId: 'd1',
      ),
      '/settings/invoice_design/custom_designs',
    );
  });
}
