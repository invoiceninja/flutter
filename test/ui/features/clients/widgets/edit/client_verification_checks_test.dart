import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_verification_checks.dart';

import '../../../shell/_shell_test_helpers.dart';

/// "Check VAT" (React #3415) asks the server about the client as it is
/// SAVED, so it's offered only for an EU client and only while the fields
/// the lookup reads match what the server has.
void main() {
  Client saved({String countryId = '276', String vatNumber = 'DE123'}) =>
      Client.fromApi(
        ClientApi.fromJson({
          'id': 'c1',
          'name': 'Acme',
          'balance': '0',
          'country_id': countryId,
          'vat_number': vatNumber,
        }),
      );

  Future<ClientEditViewModel> pump(
    WidgetTester tester, {
    Client? existing,
    String? serverVersion = '5.13.45',
    bool isHosted = true,
  }) async {
    final fixture = await buildFixture(
      isHosted: isHosted,
      companies: const [FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    fixture.services.serverVersion.value = serverVersion;
    final vm = ClientEditViewModel(
      repo: fixture.services.clients,
      companyId: 'co1',
      existing: existing,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => ClientVerificationChecks(vm: vm),
          ),
        ),
      ),
    );
    await tester.pump();
    return vm;
  }

  // The widget watches the company row — a live Drift stream. Unmount it
  // inside the body and let the watch's close timer fire, or the test hangs
  // at 0% CPU / trips `!timersPending` (see party_money_cell_test.dart).
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder checkVat() => find.widgetWithText(OutlinedButton, 'Check VAT');
  bool enabled(WidgetTester tester) =>
      tester.widget<OutlinedButton>(checkVat()).onPressed != null;

  testWidgets('a saved EU client can be checked', (tester) async {
    await pump(tester, existing: saved());

    expect(checkVat(), findsOneWidget);
    expect(enabled(tester), isTrue);

    await unmount(tester);
  });

  testWidgets('an unsaved VAT number has to be saved first', (tester) async {
    final vm = await pump(tester, existing: saved());

    vm.setVatNumber('DE999');
    await tester.pump();

    expect(enabled(tester), isFalse);
    expect(
      find.text('Save the client changes before checking the VAT number.'),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('a new client has nothing on the server to check', (
    tester,
  ) async {
    final vm = await pump(tester);
    vm.setCountryId('276');
    await tester.pump();

    expect(enabled(tester), isFalse);

    await unmount(tester);
  });

  // Saved here but still in the outbox: the server holds the old number, so
  // the check would answer for that one.
  testWidgets('a client with an unsynced save has to sync first', (
    tester,
  ) async {
    await pump(tester, existing: saved().copyWith(isDirty: true));

    expect(enabled(tester), isFalse);
    expect(
      find.text(
        "This record hasn't synced to the server yet — sync before continuing.",
      ),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('not offered outside the EU', (tester) async {
    await pump(tester, existing: saved(countryId: '840'));

    expect(checkVat(), findsNothing);

    await unmount(tester);
  });

  testWidgets('not offered by a self-hosted server without the route', (
    tester,
  ) async {
    await pump(
      tester,
      existing: saved(),
      serverVersion: '5.13.44',
      isHosted: false,
    );

    expect(checkVat(), findsNothing);

    await unmount(tester);
  });
}
