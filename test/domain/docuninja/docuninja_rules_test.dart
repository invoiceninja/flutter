import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dnCan (React permission.ts)', () {
    const member = DnCompanyUser(
      isAdmin: false,
      isOwner: false,
      notifications: [],
    );

    test('an admin or owner may do everything', () {
      for (final u in const [
        DnCompanyUser(isAdmin: true, isOwner: false, notifications: []),
        DnCompanyUser(isAdmin: false, isOwner: true, notifications: []),
      ]) {
        expect(dnCan(u, const [], DnModels.documents, DnAction.delete), isTrue);
      }
    });

    test('a member needs the grant; edit or create imply view', () {
      expect(
        dnCan(member, const [], DnModels.documents, DnAction.view),
        isFalse,
      );
      const edit = [DnPermission(model: 'documents', permissionId: 2)];
      expect(dnCan(member, edit, DnModels.documents, DnAction.edit), isTrue);
      expect(dnCan(member, edit, DnModels.documents, DnAction.view), isTrue);
      expect(dnCan(member, edit, DnModels.documents, DnAction.delete), isFalse);
      expect(dnCan(member, edit, DnModels.templates, DnAction.view), isFalse);
      const create = [DnPermission(model: 'documents', permissionId: 4)];
      expect(dnCan(member, create, DnModels.documents, DnAction.view), isTrue);
    });

    test('a grant scoped to one record does not count', () {
      const scoped = [
        DnPermission(
          model: 'documents',
          permissionId: 1,
          permissionableId: 'x',
        ),
      ];
      expect(dnCan(member, scoped, DnModels.documents, DnAction.view), isFalse);
    });
  });

  group('resolveDocuNinjaAccess (React provider, Join and Documents)', () {
    DocuNinjaAccess resolve({
      bool hosted = true,
      DnLoginOutcome outcome = DnLoginOutcome.ok,
      bool matched = true,
      bool admin = false,
      String plan = 'pro',
    }) => resolveDocuNinjaAccess(
      isHosted: hosted,
      outcome: outcome,
      companyMatched: matched,
      dnAdmin: admin,
      dnPlan: plan,
    );

    test('self-hosted has no DocuNinja', () {
      expect(resolve(hosted: false), DocuNinjaAccess.unavailable);
    });

    test('every refusal is Join, as React sends it there with ie=true', () {
      // Join offers Create to an eligible owner or admin and tells everyone
      // else to ask their admin, whether or not the account has seats.
      expect(
        resolve(outcome: DnLoginOutcome.refused),
        DocuNinjaAccess.notJoined,
      );
    });

    test('an account without this company is company setup', () {
      expect(resolve(matched: false), DocuNinjaAccess.companySetup);
    });

    test('only a DocuNinja admin off the pro plan hits the plan wall', () {
      expect(resolve(admin: true, plan: 'free'), DocuNinjaAccess.planWall);
      // Before company setup, in `Documents.tsx`'s order.
      expect(
        resolve(admin: true, plan: 'free', matched: false),
        DocuNinjaAccess.planWall,
      );
      expect(resolve(admin: false, plan: 'free'), DocuNinjaAccess.ready);
      expect(resolve(admin: true), DocuNinjaAccess.ready);
    });

    test('offline and failure are their own states', () {
      expect(resolve(outcome: DnLoginOutcome.offline), DocuNinjaAccess.offline);
      expect(resolve(outcome: DnLoginOutcome.failed), DocuNinjaAccess.failed);
    });
  });
}
