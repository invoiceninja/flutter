import 'package:flutter/foundation.dart';

/// The dashboard's "Start getting paid" checklist, as pure facts → rows
/// (docs/first-run-welcome.md). Ordered for the first sent invoice: the
/// business is set up already (the wizard did it, so the bar starts with
/// progress), then the logo, then sending — clients are created inline from
/// the invoice, so they are not a prerequisite.
enum SetupChecklistItem { business, logo, invoice, payments, clients }

/// Where the logo stands. An upload queued in the outbox counts as done — the
/// user did it, and the row must not read "not done" while it is offline.
enum LogoUploadState { none, uploading, failed }

enum ChecklistRowState { done, uploading, failed, todo }

@immutable
class SetupChecklistFacts {
  const SetupChecklistFacts({
    this.hasLogo = false,
    this.logoUpload = LogoUploadState.none,
    this.sentInvoice = false,
    this.hasGateway = false,
    this.hasClient = false,
  });

  final bool hasLogo;
  final LogoUploadState logoUpload;

  /// An invoice past draft exists.
  final bool sentInvoice;
  final bool hasGateway;
  final bool hasClient;

  @override
  bool operator ==(Object other) =>
      other is SetupChecklistFacts &&
      other.hasLogo == hasLogo &&
      other.logoUpload == logoUpload &&
      other.sentInvoice == sentInvoice &&
      other.hasGateway == hasGateway &&
      other.hasClient == hasClient;

  @override
  int get hashCode =>
      Object.hash(hasLogo, logoUpload, sentInvoice, hasGateway, hasClient);
}

@immutable
class SetupChecklistRow {
  const SetupChecklistRow(this.item, this.state);

  final SetupChecklistItem item;
  final ChecklistRowState state;

  /// Counts toward progress: done, or an upload on its way.
  bool get isComplete =>
      state == ChecklistRowState.done || state == ChecklistRowState.uploading;

  String get id => item.name;
}

List<SetupChecklistRow> setupChecklistRows(SetupChecklistFacts f) {
  ChecklistRowState flag(bool done) =>
      done ? ChecklistRowState.done : ChecklistRowState.todo;
  final logo = f.hasLogo
      ? ChecklistRowState.done
      : switch (f.logoUpload) {
          LogoUploadState.uploading => ChecklistRowState.uploading,
          LogoUploadState.failed => ChecklistRowState.failed,
          LogoUploadState.none => ChecklistRowState.todo,
        };
  return [
    const SetupChecklistRow(
      SetupChecklistItem.business,
      ChecklistRowState.done,
    ),
    SetupChecklistRow(SetupChecklistItem.logo, logo),
    SetupChecklistRow(SetupChecklistItem.invoice, flag(f.sentInvoice)),
    SetupChecklistRow(SetupChecklistItem.payments, flag(f.hasGateway)),
    SetupChecklistRow(SetupChecklistItem.clients, flag(f.hasClient)),
  ];
}

/// The one row that gets the filled button: the first not yet complete. A
/// failed upload is not complete, so Retry leads.
SetupChecklistItem? nextChecklistItem(List<SetupChecklistRow> rows) =>
    rows.where((r) => !r.isComplete).firstOrNull?.item;

int completedCount(List<SetupChecklistRow> rows) =>
    rows.where((r) => r.isComplete).length;

/// Item ids that count as done, as the card remembers them between visits.
Set<String> doneIds(List<SetupChecklistRow> rows) => {
  for (final r in rows)
    if (r.isComplete) r.id,
};
