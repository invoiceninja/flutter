import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_layout.dart';
import 'package:admin/ui/features/expenses/widgets/edit/receipt_read_banner.dart';
import 'package:admin/ui/features/expenses/widgets/expense_actions.dart';

/// Edit + Create form for an Expense.
///
/// Layout is delegated to [ExpenseEditLayout], which mirrors the v2 two-column
/// pattern: main column (Identity / Amount / Payment) + 360 px sidebar
/// (Notes / Invoicing / collapsibles) on widths ≥1100 px, single column
/// otherwise. The three densest sections (Currency conversion, Banking,
/// Custom fields) start collapsed per the UX spec § Progressive disclosure.
class ExpenseEditScreen extends StatelessWidget {
  const ExpenseEditScreen({this.existingId, this.cloneFrom, super.key});

  final String? existingId;

  /// Edit-mode override draft (parallels InvoiceEditScreen). Null for a normal
  /// edit and for create (which reads the staged draft, and whether it is a
  /// clone, via `Services.takeCreateSeed`). A non-null value is treated as a
  /// clone, so the company's new-expense defaults are not applied over it.
  final Expense? cloneFrom;

  @override
  Widget build(BuildContext context) {
    return EntityEditScreenScaffold<Expense, ExpenseEditViewModel>(
      existingId: existingId,
      entityTypeName: 'expense',
      fetchExisting: (ctx, services, companyId, id) =>
          services.expenses.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) {
        // Create-mode seed staged on `Services` (route extra:/query is dropped
        // cross-branch + on screen reuse); the keyed `/new` route recreates the
        // screen on each stage so buildVm re-reads it. `cloneFrom` is the
        // edit-mode override.
        final seed = cloneFrom != null
            ? (
                draft: cloneFrom!,
                isClone: true,
                attachments: const <UploadSource>[],
              )
            : (existing == null
                  ? services.takeCreateSeed<Expense>('/expenses')
                  : null);
        final clone = stagedExpenseDraft(seed?.draft, isClone: seed?.isClone);
        // Captured now: the fill context is built after an await, when this
        // context may be gone.
        final localization = Localization.of(ctx);
        final vm = ExpenseEditViewModel(
          repo: services.expenses,
          companyId: companyId,
          existing: existing,
          cloneFrom: clone,
          useCommaAsDecimalPlace:
              services
                  .formatterIfReady(companyId)
                  ?.settings
                  .useCommaAsDecimalPlace ??
              false,
          sync: services.sync,
          connectivity: services.connectivity,
          // Files staged with the seed — a receipt shared into the app from
          // another one (`SharedFileIntake`).
          initialDocuments: seed?.attachments ?? const [],
          discardFiles: services.sharedIntakeFiles.delete,
          // While this New Expense is open, a share joins it.
          registerShareTarget: services.sharedFiles.registerAttachTarget,
          // Reads a receipt photo or PDF into the form (docs/receipt-ocr.md).
          // Read as nullable: a test without one gets a form without it.
          receiptScanner: ctx.read<ReceiptScanner?>(),
          receiptFillContext: () async {
            final company = await services.company
                .watchCompany(companyId)
                .first;
            final rates = await services.taxRates
                .watchAll(companyId: companyId)
                .first;
            return ReceiptFillContext(
              enabledTaxTiers: company?.enabledExpenseTaxRates ?? 0,
              taxRates: [
                for (final r in rates)
                  (name: r.name, rate: numToDecimal(r.rate)),
              ],
              currencies: services.statics.currencies,
              receiptNote: (number) =>
                  localization?.lookup('receipt_number_note', {
                    'number': number,
                  }) ??
                  'Receipt #$number',
            );
          },
        );
        // Embedded Project → Expenses-tab "New" stages a draft with a projectId
        // but no client; resolve the project to set clientId. Actions that bake
        // the clientId skip this.
        final seedProjectId =
            (clone != null &&
                clone.projectId.isNotEmpty &&
                clone.clientId.isEmpty)
            ? clone.projectId
            : null;
        if (seedProjectId != null && existing == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              services.projects
                  .watch(companyId: companyId, id: seedProjectId)
                  .first
                  .then((project) {
                    if (project != null) {
                      vm.setProjectId(project.id);
                      vm.setClientId(project.clientId);
                    }
                  })
                  .catchError((Object _) {}),
            );
          });
        }
        // A new expense takes the company's Expense Settings defaults; a clone
        // copies its source instead.
        if (existing == null && !(seed?.isClone ?? false)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              services.company
                  .watchCompany(companyId)
                  .first
                  .then((company) {
                    if (company == null || vm.isDisposed) return;
                    vm.seedCompanyDefaults(company);
                    // After the defaults, so a read's amount and tax decide
                    // the tax mode, not the other way round. A file the form
                    // opened with (Scan Receipt, a share) is read at once.
                    unawaited(vm.autoReadReceipt(vm.documents));
                  })
                  .catchError((Object _) {}),
            );
          });
        }
        return vm;
      },
      titleWhileLoading: (ctx) =>
          existingId == null ? ctx.tr('new_expense') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_expense')
          : (vm.draft.number.isNotEmpty
                ? '${ctx.tr('edit')} · #${vm.draft.number}'
                : ctx.tr('edit')),
      bodyBuilder: (ctx, vm) => ExpenseEditLayout(vm: vm),
      bannerBuilder: (ctx, vm) => ReceiptReadBanner(vm: vm),
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (e) => e.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<ExpenseAction>(
            leading: saveButton,
            items: filterForEditScreen(
              ExpenseActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: ExpenseActions.isLifecycle,
            ),
          ),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return ExpenseActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as ExpenseAction,
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/expenses',
        savedId: saved.id,
      ),
    );
  }
}

/// The draft a New Expense should open on from a staged seed — or null for
/// a blank form.
///
/// Files shared in or captured by Scan Receipt arrive with a blank draft
/// staged beside them (`SharedFileIntake` → `stageCreateDraft`). That is not
/// a prefilled form: opening it as one stopped the receipt being read and its
/// date filled (docs/receipt-ocr.md). The documents keep the form dirty.
@visibleForTesting
Expense? stagedExpenseDraft(Expense? staged, {bool? isClone}) {
  if (staged == null) return null;
  if (isClone ?? false) return staged;
  return staged == emptyExpense().copyWith(date: staged.date) ? null : staged;
}
