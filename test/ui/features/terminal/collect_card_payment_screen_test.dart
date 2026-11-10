import 'dart:async';

import 'package:admin/app/terminal_controller.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/terminal/view_models/collect_card_payment_view_model.dart';
import 'package:admin/ui/features/terminal/views/collect_card_payment_screen.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_services/store_services.dart';

import '../shell/_shell_test_helpers.dart';
import '_terminal_fakes.dart';

/// The collect screen renders every stage a counter can see, at a phone's
/// width and twice the text size, and holds Back while a card is charged
/// (docs/in-person-payments.md).
void main() {
  final invoice = emptyInvoice().copyWith(
    id: 'inv_1',
    number: '0042',
    statusId: InvoiceStatus.sent,
    amount: Decimal.fromInt(100),
    balance: Decimal.fromInt(100),
  );

  Future<(CollectCardPaymentViewModel, FakeTerminalRepo, FakeTerminalPlatform)>
  pump(WidgetTester tester, {double textScale = 1}) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(id: 'co1', name: 'Acme', isAdmin: true, isOwner: true),
      ],
    );
    addTearDown(fixture.dispose);
    final repo = FakeTerminalRepo();
    final platform = FakeTerminalPlatform();
    final terminal = TerminalController(
      repository: repo,
      platform: platform,
      auth: fixture.services.auth,
      prefs: fixture.services.devicePrefs,
      platformReady: true,
    );
    addTearDown(terminal.dispose);
    final vm = CollectCardPaymentViewModel(
      companyId: 'co1',
      invoice: invoice,
      terminal: terminal,
      repository: repo,
      isAdmin: true,
      merchantDisplayName: 'Acme',
      precision: 2,
      pollDelay: Duration.zero,
    );
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: CollectCardPaymentScreen(
            companyId: 'co1',
            invoice: invoice,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (vm, repo, platform);
  }

  testWidgets('configure: test mode, the quoted total, and Collect once the '
      'reader is ready', (tester) async {
    final (vm, _, _) = await pump(tester);
    expect(vm.readerState, ReaderState.ready);
    expect(find.text('TEST MODE'), findsOneWidget);
    expect(find.textContaining('Customer pays'), findsOneWidget);
    expect(find.text('Tap to Pay on this phone'), findsOneWidget);
    final collect = find.ancestor(
      of: find.textContaining(RegExp(r'^Collect ')),
      matching: find.byType(FilledButton),
    );
    expect(collect, findsOneWidget);
    expect(tester.widget<FilledButton>(collect).onPressed, isNotNull);
  });

  testWidgets('every stage fits a phone at twice the text size', (
    tester,
  ) async {
    final (vm, repo, platform) = await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);

    repo.creates.add(fakeIntent());
    final read = Completer<TerminalCollected>();
    platform.session.reads.add(read);
    unawaited(vm.collect());
    await tester.pump();
    await tester.pump();
    expect(vm.stage, CollectStage.waiting);
    expect(
      find.text('Hold the card near the back of the phone'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    repo.finalizes.add(fakeFinalize(10000));
    final confirm = Completer<TerminalPaymentOutcome>();
    platform.session.confirms.add(confirm);
    read.complete(fakeCard);
    await tester.pump();
    await tester.pump();
    expect(vm.stage, CollectStage.processing);
    expect(
      find.text('Charging the card. Keep this screen open.'),
      findsOneWidget,
    );
    // Nothing closes the screen while the card is being charged.
    final close = find.widgetWithIcon(IconButton, Icons.close);
    expect(tester.widget<IconButton>(close).onPressed, isNull);
    expect(tester.takeException(), isNull);

    repo.completes.add(fakeCompletion('recorded'));
    confirm.complete(
      const TerminalPaymentOutcome(
        paymentIntentId: 'pi_1',
        status: 'succeeded',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(vm.stage, CollectStage.approved);
    expect(find.text('Payment recorded'), findsOneWidget);
    expect(find.text('Send card receipt'), findsOneWidget);
    expect(find.text('VISA •• 4242'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown outcome says so, and offers only Check again', (
    tester,
  ) async {
    final (vm, repo, platform) = await pump(tester);
    repo.creates.add(fakeIntent());
    platform.session.reads.add(fakeCard);
    repo.finalizes.add(fakeFinalize(10000));
    platform.session.confirms.add(
      const TerminalError(TerminalErrorCode.outcomeUnknown),
    );
    for (var i = 0; i < 3; i++) {
      repo.completes.add(fakeCompletion('requires_confirmation'));
    }
    // Its retries wait on timers, which only a pump advances.
    unawaited(vm.collect());
    for (var i = 0; i < 20 && vm.stage != CollectStage.checking; i++) {
      await tester.pump(Duration.zero);
    }
    expect(vm.stage, CollectStage.checking);
    expect(find.textContaining("couldn't confirm whether"), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(find.text('Try another card'), findsNothing);
  });
}
