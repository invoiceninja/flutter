import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/shell/widgets/plan_expired_footer.dart';

/// React #3222's "Account plan expired — Pay now", for the owner of a lapsed
/// hosted plan (or ended trial) only.
void main() {
  AuthSession session({
    bool isHosted = true,
    bool isOwner = true,
    String plan = 'pro',
    String planExpires = '2000-01-01',
  }) => AuthSession(
    baseUrl: 'https://example.test',
    isHosted: isHosted,
    accountId: 'acc',
    companies: [
      AuthCompany(
        id: 'co',
        name: 'Co',
        displayName: 'Co',
        permissions: '',
        isAdmin: isOwner,
        isOwner: isOwner,
      ),
    ],
    currentCompanyId: 'co',
    plan: plan,
    planExpires: planExpires,
  );

  test('shows for the owner of a lapsed hosted plan', () {
    expect(PlanExpiredFooter.shows(session()), isTrue);
    // What a live server actually sends once the date has passed:
    // `Account::getPlan()` blanks `plan` from then on.
    expect(PlanExpiredFooter.shows(session(plan: '')), isTrue);
  });

  test('never for a non-owner, self-hosted, a live plan, or no expiry', () {
    expect(PlanExpiredFooter.shows(session(isOwner: false)), isFalse);
    expect(PlanExpiredFooter.shows(session(isHosted: false)), isFalse);
    expect(
      PlanExpiredFooter.shows(session(planExpires: '2999-01-01')),
      isFalse,
    );
    // Never had a plan or a trial.
    expect(
      PlanExpiredFooter.shows(session(plan: '', planExpires: '')),
      isFalse,
    );
    expect(PlanExpiredFooter.shows(null), isFalse);
  });
}
