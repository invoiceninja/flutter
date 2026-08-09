// Completeness guard for the Sync pass (Services.resyncAllEntities).
// Its whole promise is to re-download everything the user can browse, but the
// covered set is a hand-maintained list (Services._resyncSteps). This asserts
// that list covers every workspace-sidebar (SidebarSection.top) entity, so a
// future list entity can't be silently left out of the offline cache.

import 'package:flutter_test/flutter_test.dart';

import '../ui/features/shell/_shell_test_helpers.dart';

void main() {
  testWidgets('resyncAllEntities covers every workspace-sidebar list entity', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    final browsable = fixture.services.entityRegistry.sidebarTop
        .map((h) => h.type)
        .toSet();

    expect(
      browsable.difference(fixture.services.resyncEntityTypes),
      isEmpty,
      reason:
          'every workspace-sidebar list entity must be re-downloaded by a '
          'Sync pass — add the missing entity to Services._resyncSteps',
    );

    // restore() armed the recently-viewed debounce timer; dispose it so the
    // binding's end-of-test pending-timer check passes.
    fixture.services.recentlyViewed.dispose();
  });
}
