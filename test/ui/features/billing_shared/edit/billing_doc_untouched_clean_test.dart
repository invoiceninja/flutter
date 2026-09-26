// A new billing document is dirty exactly when it differs from what the
// untouched form held (`BillingDocEditViewModel.draftIsNonEmpty`). That makes
// any write the layout does on its own while mounting — a default seeded into
// the draft, a hook that "normalizes" a field — a spurious Discard prompt on a
// form the user never touched. Pin that every layout settles clean.

import 'package:flutter_test/flutter_test.dart';

import '../../shell/_shell_test_helpers.dart';
import '_billing_edit_harness.dart';

void main() {
  for (final doc in BillingDoc.values) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('${doc.name} at ${width.toInt()} px: an untouched new '
          'document settles clean', (tester) async {
        setWindow(tester, width);
        final fixture = await buildFixture(
          closeStreamsSynchronously: true,
          companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
        );
        addTearDown(fixture.dispose);
        final mounted = buildLayout(
          doc,
          fixture.services,
          showPdfTab: width >= 600,
        );
        addTearDown(mounted.vm.dispose);
        await tester.pumpWidget(
          wrapWithShell(fixture.services, mounted.layout),
        );
        await settle(tester);
        expect(mounted.vm.isDirty, isFalse);
        await unmount(tester, fixture);
      });
    }
  }
}
