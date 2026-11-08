import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/domain/docuninja/docuninja_users.dart';
import 'package:flutter_test/flutter_test.dart';

/// React's user notification codes and permissions grid
/// (`pages/users/common`).
void main() {
  group('notifications', () {
    test('React\'s decode: all, own, none or per type', () {
      expect(DnNotificationChoice.decode(['all', 'x']).master, DnNotify.all);
      expect(
        DnNotificationChoice.decode(['all_user']).master,
        DnNotify.allUser,
      );
      expect(DnNotificationChoice.decode([]).master, DnNotify.none);
      final c = DnNotificationChoice.decode([
        'document_signed',
        'document_sent_user',
      ]);
      expect(c.master, DnNotify.custom);
      expect(c.of('document_signed'), DnNotify.all);
      expect(c.of('document_sent'), DnNotify.allUser);
      expect(c.of('document_viewed'), DnNotify.none);
    });

    test('encodes back to the codes it came from', () {
      const codes = ['document_sent_user', 'document_signed'];
      expect(DnNotificationChoice.decode(codes).encode(), codes);
      expect(const DnNotificationChoice(DnNotify.allUser).encode(), [
        'all_user',
      ]);
    });

    test('a master choice clears the types; a type makes it custom', () {
      final c = DnNotificationChoice.decode([
        'document_signed',
      ]).withMaster(DnNotify.all);
      expect(c.encode(), ['all']);
      final t = c.withType('document_voided', DnNotify.allUser);
      expect(t.master, DnNotify.custom);
      expect(t.encode(), ['document_voided_user']);
    });
  });

  group('permissions', () {
    test('a box adds or removes one global grant', () {
      var p = dnSetPermission(const [], 'documents', DnAction.edit, on: true);
      expect(dnHasPermission(p, 'documents', DnAction.edit), isTrue);
      expect(p.single.toJson(), {
        'model': 'documents',
        'id': '',
        'permission_id': 2,
        'permissionable_id': null,
      });
      p = dnSetPermission(p, 'documents', DnAction.edit, on: false);
      expect(p, isEmpty);
    });

    test('a record-scoped grant is never a box, and survives', () {
      const scoped = DnPermission(
        model: 'documents',
        permissionId: 2,
        permissionableId: 'd1',
      );
      expect(
        dnHasPermission(const [scoped], 'documents', DnAction.edit),
        isFalse,
      );
      final p = dnSetPermission(
        const [scoped],
        'documents',
        DnAction.edit,
        on: false,
      );
      expect(p, [scoped]);
    });

    test('All sets the column on every model that has it', () {
      final p = dnSetPermissionForAll(const [], DnAction.view, on: true);
      expect(p, hasLength(kDnPermissionModels.length));
      final approval = dnSetPermissionForAll(
        const [],
        DnAction.requiresApproval,
        on: true,
      );
      expect(approval.map((x) => x.model), ['documents']);
    });
  });
}
