import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/widgets/save_failed_banner.dart';

import '../../../_responsive_helper.dart';

/// invoiceninja/flutter#36 — "the server rejects the changes and only option
/// given is to `discard` them".
///
/// The banner used to render ONLY when `fieldErrors` was non-empty, tell the
/// user to "fix the errors below and try again", and offer nothing but
/// "Discard failed save". So a rejection naming keys no field on the form
/// renders — or carrying no field errors at all — showed no reason, nothing to
/// fix, and discard as the only way out. These tests pin the three properties
/// that stop it being a dead end: the reason is always stated, Retry exists,
/// and Retry is suppressed exactly when it would be a lie.
class _FakeVm extends GenericEditViewModel<String> {
  _FakeVm({this.localErrors = const {}}) : super(initialDraft: 'draft');

  /// Returned from [validate] so `save()` takes its client-side block path,
  /// which is the only way to set `localValidationOnly`.
  final Map<String, List<String>> localErrors;

  @override
  Map<String, List<String>> validate() => localErrors;

  @override
  Future<SaveResult<String>> performSave() async =>
      throw UnimplementedError('not exercised — the banner only reads state');

  void rejectWith({
    Map<String, List<String>> errors = const {},
    String? message,
    int? statusCode,
  }) {
    applyFailedSync(
      rowId: 1,
      errors: errors,
      message: message,
      statusCode: statusCode,
    );
  }
}

void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    _FakeVm vm, {
    Future<void> Function()? onRetry,
  }) => pumpAt(
    tester,
    800,
    SaveFailedBanner(vm: vm, onDiscard: () async {}, onRetry: onRetry),
  );

  testWidgets('renders nothing on a clean form', (tester) async {
    await pumpBanner(tester, _FakeVm());
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Discard failed save'), findsNothing);
  });

  testWidgets(
    'a field error whose key no field on the form renders is still shown — '
    'this is the exact case that used to render as an empty accusation',
    (tester) async {
      final vm = _FakeVm()
        ..rejectWith(
          errors: {
            'invitations.0.client_contact_id': ['The contact is invalid.'],
          },
          message: 'The given data was invalid.',
          statusCode: 422,
        );
      await pumpBanner(tester, vm);

      expect(find.text('The server rejected this save.'), findsOneWidget);
      expect(find.text('The contact is invalid.'), findsOneWidget);
    },
  );

  testWidgets(
    'a rejection with NO field errors still states its reason — previously '
    'the banner rendered nothing at all and the reason lived only in a toast '
    'the user had already dismissed',
    (tester) async {
      final vm = _FakeVm()
        ..rejectWith(message: 'Something went wrong', statusCode: 400);
      await pumpBanner(tester, vm);

      expect(find.text('The server rejected this save.'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    },
  );

  testWidgets('Retry re-submits and sits alongside Discard', (tester) async {
    var retried = 0;
    final vm = _FakeVm()..rejectWith(message: 'Server error', statusCode: 500);
    await pumpBanner(tester, vm, onRetry: () async => retried++);

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Discard failed save'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets(
    'a record-deleted rejection drops Retry — the server\'s verdict cannot '
    'change until the record is restored, so a Retry would promise a fix and '
    'deliver the same failure. The instruction to restore is the detail line.',
    (tester) async {
      const serverMessage =
          'Record is deleted and cannot be edited. Restore the record to '
          'enable editing';
      final vm = _FakeVm()..rejectWith(message: serverMessage, statusCode: 400);
      await pumpBanner(tester, vm, onRetry: () async {});

      expect(vm.failedSaveIsRecordDeleted, isTrue);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Discard failed save'), findsOneWidget);
      expect(find.text(serverMessage), findsOneWidget);
    },
  );

  testWidgets(
    'a client-side validate() block keeps the softer copy and no actions — '
    'nothing was written, so there is no outbox row to discard or retry',
    (tester) async {
      final vm = _FakeVm(
        localErrors: const {
          'name': ['Required'],
        },
      );
      await vm.save();
      expect(vm.localValidationOnly, isTrue);
      await pumpBanner(tester, vm, onRetry: () async {});

      expect(
        find.text('Please fix the highlighted fields before saving'),
        findsOneWidget,
      );
      expect(find.text('The server rejected this save.'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    },
  );
}
