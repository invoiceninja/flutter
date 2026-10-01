import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/auth/widgets/name_required_dialog.dart';

/// React #3341: hosted billing needs the user's first AND last name.
void main() {
  AuthSession session({
    bool isHosted = true,
    String first = '',
    String last = '',
    String userId = 'u1',
    String baseUrl = 'https://invoicing.co',
  }) => AuthSession(
    baseUrl: baseUrl,
    isHosted: isHosted,
    accountId: 'a1',
    companies: const [],
    currentCompanyId: 'co1',
    userId: userId,
    userFirstName: first,
    userLastName: last,
  );

  test('hosted with either name missing', () {
    expect(needsUserName(session()), isTrue);
    expect(needsUserName(session(first: 'Ada')), isTrue);
    expect(needsUserName(session(last: 'Lovelace')), isTrue);
  });

  test('not once both are set, on self-hosted, in the demo, or signed out', () {
    expect(needsUserName(session(first: 'Ada', last: 'Lovelace')), isFalse);
    expect(needsUserName(session(isHosted: false)), isFalse);
    expect(needsUserName(session(baseUrl: kDemoBaseUrl)), isFalse);
    expect(needsUserName(session(userId: '')), isFalse);
    expect(needsUserName(null), isFalse);
  });
}
