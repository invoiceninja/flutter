import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/setup_checklist.dart';

/// The dashboard checklist's rows (docs/first-run-welcome.md): ordered for
/// the first sent invoice, starting with progress, and honest about a logo
/// that is still on its way.
void main() {
  ChecklistRowState stateOf(SetupChecklistFacts f, SetupChecklistItem i) =>
      setupChecklistRows(f).firstWhere((r) => r.item == i).state;

  test('a fresh company starts one in, with the logo next', () {
    final rows = setupChecklistRows(const SetupChecklistFacts());
    expect(rows.map((r) => r.item), SetupChecklistItem.values);
    expect(completedCount(rows), 1);
    expect(nextChecklistItem(rows), SetupChecklistItem.logo);
  });

  test('a logo queued in the outbox counts as done', () {
    const f = SetupChecklistFacts(logoUpload: LogoUploadState.uploading);
    expect(stateOf(f, SetupChecklistItem.logo), ChecklistRowState.uploading);
    final rows = setupChecklistRows(f);
    expect(completedCount(rows), 2);
    expect(nextChecklistItem(rows), SetupChecklistItem.invoice);
  });

  test('a failed upload is not done, and leads so Retry is first', () {
    const f = SetupChecklistFacts(logoUpload: LogoUploadState.failed);
    expect(stateOf(f, SetupChecklistItem.logo), ChecklistRowState.failed);
    expect(nextChecklistItem(setupChecklistRows(f)), SetupChecklistItem.logo);
  });

  test('a logo on the company wins over any upload state', () {
    const f = SetupChecklistFacts(
      hasLogo: true,
      logoUpload: LogoUploadState.failed,
    );
    expect(stateOf(f, SetupChecklistItem.logo), ChecklistRowState.done);
  });

  test('sending the first invoice comes before payments and clients', () {
    const f = SetupChecklistFacts(hasLogo: true, hasClient: true);
    expect(
      nextChecklistItem(setupChecklistRows(f)),
      SetupChecklistItem.invoice,
    );
  });

  test('everything done has no next row', () {
    const f = SetupChecklistFacts(
      hasLogo: true,
      sentInvoice: true,
      hasGateway: true,
      hasClient: true,
    );
    final rows = setupChecklistRows(f);
    expect(nextChecklistItem(rows), isNull);
    expect(completedCount(rows), rows.length);
    expect(doneIds(rows), {for (final i in SetupChecklistItem.values) i.name});
  });
}
