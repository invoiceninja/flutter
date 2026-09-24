import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/sync/unconfirmed_change_actions.dart';

/// Check opens where a change would show. A `user` row went to the signed-in
/// user's own profile even when it was another user's, edited or invited from
/// User Management — where nothing of it shows — and a company document upload
/// went to Company Details' first tab rather than its Documents.
class _FakeAuth implements AuthRepository {
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier<AuthSession?>(
    const AuthSession(
      baseUrl: 'https://example.test',
      isHosted: false,
      accountId: 'acct',
      companies: [],
      currentCompanyId: 'co',
      userId: 'me',
    ),
  );

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopDispatcher implements SyncDispatcher {
  @override
  Future<void> dispatch({
    required OutboxRow row,
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

class _FakeServices implements Services {
  @override
  final AuthRepository auth = _FakeAuth();

  @override
  final EntityRegistry entityRegistry = EntityRegistry({
    EntityType.company: EntityHandlers(
      type: EntityType.company,
      wireName: 'company',
      apiPath: '/api/v1/companies',
      routePath: '/settings/company_details',
      icon: Icons.business,
      dispatcher: _NoopDispatcher(),
    ),
    EntityType.user: EntityHandlers(
      type: EntityType.user,
      wireName: 'user_settings',
      extraWireNames: const ['user'],
      apiPath: '/api/v1/company_users',
      routePath: '/settings/account',
      icon: Icons.person,
      dispatcher: _NoopDispatcher(),
    ),
  });

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  final services = _FakeServices();

  String destinationOf({
    required String entityType,
    required String entityId,
    MutationKind kind = MutationKind.update,
    Map<String, Object?> payload = const {},
  }) => unconfirmedRowDestination(
    services,
    OutboxRow(
      id: 1,
      companyId: 'co',
      entityType: entityType,
      entityId: entityId,
      mutationKind: kind.wireName,
      payload: jsonEncode(payload),
      idempotencyKey: 'k',
      attempts: 0,
      nextAttemptAt: 0,
      state: 'unconfirmed',
      requiresPassword: false,
      createdAt: 0,
    ),
  );

  test('another user\'s change opens that user in User Management', () {
    expect(
      destinationOf(entityType: 'user', entityId: 'someone'),
      '/settings/users/someone',
    );
    expect(
      destinationOf(
        entityType: 'user',
        entityId: 'tmp_invite',
        kind: MutationKind.create,
      ),
      '/settings/users',
      reason: 'an invite lands in the list',
    );
  });

  test('the signed-in user\'s own change opens their profile', () {
    expect(
      destinationOf(entityType: 'user', entityId: 'me'),
      '/settings/user_details',
    );
    expect(
      destinationOf(entityType: 'user_settings', entityId: 'me'),
      '/settings/user_details',
    );
  });

  test('a company document upload opens the Documents tab', () {
    expect(
      destinationOf(
        entityType: 'company',
        entityId: 'co',
        payload: {'_action': 'upload_document', 'file_name': 'a.pdf'},
      ),
      '/settings/company_details/documents',
    );
    expect(
      destinationOf(entityType: 'company', entityId: 'co'),
      '/settings/company_details',
    );
  });
}
