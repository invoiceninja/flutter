import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_sheet.dart';

/// Shared "open the picker and append the result" pipeline that every
/// billing-doc edit screen calls. Centralizes the five invariants:
///
///   1. Already-attached tasks/expenses are excluded so users can't
///      double-add the same row.
///   2. The sheet's chosen rows replace any trailing blank/ghost rows in
///      the draft — the new rows sit at the end of the real list.
///   3. If a picked task carries a `projectId` and the draft has none yet,
///      adopt it via the per-doc `setProjectId` callback.
///   4. If picked tasks/expenses carry a `clientId` and the draft has no
///      client yet, adopt the first non-blank source `clientId` via
///      `setClientId`. Mirrors admin-portal's `invoice_edit_vm.dart:204-212`
///      cascade. The picker filter (Round 2) already prevents cross-client
///      picks, so this only fires when the draft is genuinely client-less.
///   5. The picked tasks'/expenses' `taskId → clientId` maps are pushed
///      back to the host VM via `registerSourceClientIds` so the
///      cross-client save validator can use the cached lookup instead of
///      re-fetching every line item's source from Drift.
///   6. PO edits pass `showTasksAndExpenses: false` and stub all
///      client-related callbacks — the picker collapses to Products only.
///
/// VM type is intentionally not constrained: each per-entity edit VM has
/// its own `companyId` / `setProjectId` shape, so the call site supplies
/// them as plain parameters.
Future<void> openLineItemPicker(
  BuildContext context, {
  required String companyId,
  required String clientId,
  required bool showTasksAndExpenses,
  required bool invoiceInclusive,
  required List<LineItem> currentLineItems,
  required String currentProjectId,
  required String currentClientId,
  required void Function(List<LineItem> next) replaceLineItems,
  required void Function(String projectId) setProjectId,
  required void Function(String clientId) setClientId,
  required void Function(
    Map<String, String> tasks,
    Map<String, String> expenses,
  )
  registerSourceClientIds,
  bool showStockQuantity = false,
}) async {
  final services = context.read<Services>();
  final excludedTaskIds = currentLineItems
      .map((li) => li.taskId)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet();
  final excludedExpenseIds = currentLineItems
      .map((li) => li.expenseId)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet();

  // Projects the doc already shows a task line for — they mustn't get a
  // second project header when more of their tasks are added.
  final headedProjectIds = <String>{
    for (final t in await services.tasks.getByIds(
      companyId: companyId,
      ids: excludedTaskIds,
    ))
      if (t.projectId.isNotEmpty) t.projectId,
  };
  if (!context.mounted) return;

  final result = await showLineItemPickerSheet(
    context,
    companyId: companyId,
    clientId: clientId,
    showTasksAndExpenses: showTasksAndExpenses,
    invoiceInclusive: invoiceInclusive,
    excludedTaskIds: excludedTaskIds,
    excludedExpenseIds: excludedExpenseIds,
    headedProjectIds: headedProjectIds,
    formatter: services.formatterIfReady(companyId),
    showStockQuantity: showStockQuantity,
  );
  if (result == null || result.lineItems.isEmpty) return;

  // Drop any trailing blanks / ghost rows so the new additions land at the
  // end of the real list; the line-item editor will re-add its own ghost.
  final base = currentLineItems.where((i) => !i.isBlank).toList();
  replaceLineItems(<LineItem>[...base, ...result.lineItems]);

  // Prime the host VM's cross-client validation cache with the picked
  // rows' source clientIds (already in memory in the picker — no extra
  // Drift round-trip needed).
  if (result.pickedTaskClientIds.isNotEmpty ||
      result.pickedExpenseClientIds.isNotEmpty) {
    registerSourceClientIds(
      result.pickedTaskClientIds,
      result.pickedExpenseClientIds,
    );
  }

  // ClientId carry-over — only when the draft has none.
  if (result.clientIdHint.isNotEmpty && currentClientId.isEmpty) {
    setClientId(result.clientIdHint);
  }

  // ProjectId carry-over — only when the draft has none.
  if (result.projectIdHint.isNotEmpty && currentProjectId.isEmpty) {
    setProjectId(result.projectIdHint);
  }
}
