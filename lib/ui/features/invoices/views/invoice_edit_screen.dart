import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/after_save_create_action.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/seed_client_invitations.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/mark_paid_confirm_dialog.dart';
import 'package:admin/ui/features/invoices/widgets/edit/invoice_edit_layout.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_locked_dialog.dart';

/// M1 stub of the Invoice edit + create screen. Renders a "coming soon"
/// body so the route compiles; the M3 milestone replaces this with the
/// full tabbed layout (Details / Contacts / Items / Notes / PDF / E-Invoice)
/// backed by [InvoiceEditViewModel]'s full setter surface.
class InvoiceEditScreen extends StatelessWidget {
  const InvoiceEditScreen({this.existingId, this.cloneFrom, super.key});

  final String? existingId;

  /// Edit-mode override draft: the "Add to invoice" (task / expense) flow
  /// routes to `/invoices/:id/edit` with the chosen invoice + appended line
  /// item as `extra` for review before saving. Null for a normal edit (uses the
  /// fetched record) and for create (which reads the staged draft instead).
  final Invoice? cloneFrom;

  @override
  Widget build(BuildContext context) {
    return EntityEditScreenScaffold<Invoice, InvoiceEditViewModel>(
      existingId: existingId,
      entityTypeName: 'invoice',
      fetchExisting: (ctx, services, companyId, id) async {
        final invoice = await services.invoices
            .watch(companyId: companyId, id: id)
            .first;
        // Hard-block editing a locked invoice. The action-menu /
        // detail-button / list-menu paths are already blocked in
        // InvoiceActions.dispatch; gating here (the single fetch the
        // scaffold already does) additionally covers a direct deep link to
        // `/invoices/:id/edit`, which never goes through dispatch. tmp_ /
        // empty-id drafts are never locked. The scaffold still renders its
        // normal titled loading chrome — the post-frame dialog + nav fire
        // immediately, so there's no extra chrome-less spinner.
        if (invoice != null && id.isNotEmpty && !id.startsWith('tmp_')) {
          final reason = await resolveInvoiceLockReason(
            settings: services.settings,
            companyId: companyId,
            invoice: invoice,
          );
          if (reason != InvoiceLockReason.none) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!ctx.mounted) return;
              await showInvoiceLockedDialog(ctx, reason);
              if (!ctx.mounted) return;
              // Deep-link entry may have no back stack — land on the detail
              // screen (which shows the lock banner) instead of asserting.
              ctx.canPop() ? ctx.pop() : ctx.go('/invoices/$id');
            });
          }
        }
        return invoice;
      },
      buildVm: (ctx, services, companyId, existing) {
        // Create-mode seed: a Client / Product / Project / clone "New Invoice"
        // stages the draft on `Services` (the route `extra:`/query channel is
        // dropped on the cross-branch jump and on create-screen reuse). The
        // generation-keyed `/new` route recreates this screen on each stage, so
        // `buildVm` re-reads the staged draft here.
        final clone =
            cloneFrom ??
            (existing == null
                ? services.takeCreateDraft<Invoice>('/invoices')
                : null);
        final vm = InvoiceEditViewModel(
          repo: services.invoices,
          companyId: companyId,
          clientRequiredMessage: ctx.tr('please_select_a_client'),
          crossClientLineItemsMessage: ctx.tr('cross_client_line_items'),
          partialInvalidMessage: ctx.tr('partial_value'),
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
        );
        // When the staged draft carries a projectId but no client (the embedded
        // Project → Invoices-tab "New", which only knows the project id),
        // resolve the project's client so its contacts seed — same as picking
        // the client in the dropdown. Actions that bake the clientId skip this.
        // Deferred via postFrame so the scaffold's listeners are attached
        // before notifyListeners fires (else a subwidget caching state on first
        // mount — e.g. LineItemTableDesktop's _rows — misses the seed).
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
                  .then((project) async {
                    if (project == null) return;
                    final client = await services.clients
                        .watch(companyId: companyId, id: project.clientId)
                        .first;
                    if (client != null) {
                      vm.selectClient(client.id, client.contacts);
                    } else {
                      vm.setClientId(project.clientId);
                    }
                  })
                  .catchError((Object _) {}),
            );
          });
        }
        // Seed contact invitations when the draft carries a client but no
        // invitations yet — mirrors picking the client in the dropdown.
        if (existing == null) {
          seedClientInvitationsFromPrefill(
            services: services,
            companyId: companyId,
            vm: vm,
          );
        }
        return vm;
      },
      titleWhileLoading: (ctx) =>
          existingId == null ? ctx.tr('new_invoice') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_invoice')
          : (vm.draft.number.isNotEmpty
                ? '${ctx.tr('edit')} · #${vm.draft.number}'
                : ctx.tr('edit')),
      bodyBuilder: (ctx, vm) => InvoiceEditLayout(vm: vm),
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (i) => i.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<InvoiceAction>(
            leading: saveButton,
            items: filterForEditScreen(
              InvoiceActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: InvoiceActions.isLifecycle,
            ),
          ),
      saveParamFor: (a) => InvoiceActions.saveParamFor(a as InvoiceAction),
      // `markPaid` records a synthetic payment for the full outstanding
      // balance. On the detail screen `InvoiceActions.dispatch` always asks
      // first; from here the SAVE-PARAM branch returns before `dispatch` is
      // reached, so the same tap used to do it with no prompt at all. The
      // other SAVE-PARAM verbs (markSent / cancel / autoBill) carry
      // `confirm: true` on their action item and are gated by `guardedOnTap`.
      confirmSaveParam: (BuildContext context, Object action) async =>
          action != InvoiceAction.markPaid ||
          await showMarkPaidConfirmDialog(context),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return InvoiceActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as InvoiceAction,
        );
      },
      // On create the save returns a tmp-id draft; resolve it to the real id
      // so server-bound actions work, and let navigating ones (Send Email, …)
      // own the post-save navigation instead of the detail redirect.
      onAfterSaveActionOnCreate: (ctx, saved, a) {
        final services = ctx.read<Services>();
        final companyId = services.auth.session.value!.currentCompanyId;
        return dispatchAfterSaveOnCreate<Invoice, InvoiceAction>(
          ctx,
          saved: saved,
          idOf: (i) => i.id,
          withId: (i, id) => i.copyWith(id: id),
          resolveId: services.invoices.resolveId,
          action: a as InvoiceAction,
          navigatesOnCreate: InvoiceActions.navigatesOnCreate,
          dispatch: (c, resolved, act) =>
              InvoiceActions.dispatch(c, services, companyId, resolved, act),
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/invoices',
        savedId: saved.id,
      ),
    );
  }
}
