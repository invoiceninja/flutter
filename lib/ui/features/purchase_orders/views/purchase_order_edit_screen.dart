import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/after_save_create_action.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/widgets/edit/purchase_order_edit_layout.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_actions.dart';

class PurchaseOrderEditScreen extends StatelessWidget {
  const PurchaseOrderEditScreen({this.existingId, this.cloneFrom, super.key});

  final String? existingId;

  /// Edit-mode override draft (parallels InvoiceEditScreen). Null for a normal
  /// edit (uses the fetched record) and for create (which reads the staged
  /// draft via `Services.takeCreateDraft`).
  final PurchaseOrder? cloneFrom;

  @override
  Widget build(BuildContext context) {
    // ONE width read, threaded into BOTH halves below: the strip and the
    // header button must appear together or not at all, and the AppBar is
    // built outside the body so no `LayoutBuilder` in the layout could inform
    // it (invoiceninja/flutter#140). `InvoiceEditScreen` carries the full
    // note — the threshold, and the separate measurement
    // `EntityEditScaffold` makes for its own spread-vs-compact branch.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _scaffold(context, narrow: !Breakpoints.isWide(constraints)),
    );
  }

  Widget _scaffold(BuildContext context, {required bool narrow}) {
    return EntityEditScreenScaffold<PurchaseOrder, PurchaseOrderEditViewModel>(
      existingId: existingId,
      entityTypeName: 'purchase_order',
      fetchExisting: (ctx, services, companyId, id) =>
          services.purchaseOrders.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) {
        // Create-mode seed staged on `Services` (route extra:/query is dropped
        // cross-branch + on screen reuse); the keyed `/new` route recreates the
        // screen on each stage so buildVm re-reads it. `cloneFrom` is the
        // edit-mode override (parallels InvoiceEditScreen). Product → New PO
        // bakes the line item into the staged draft.
        final clone =
            cloneFrom ??
            (existing == null
                ? services.takeCreateDraft<PurchaseOrder>('/purchase_orders')
                : null);
        return PurchaseOrderEditViewModel(
          repo: services.purchaseOrders,
          companyId: companyId,
          vendorRequiredMessage: ctx.tr('please_select_a_vendor'),
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
      },
      titleWhileLoading: (ctx) =>
          existingId == null ? ctx.tr('new_purchase_order') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_purchase_order')
          : (vm.draft.number.isNotEmpty
                ? '${ctx.tr('edit')} · #${vm.draft.number}'
                : ctx.tr('edit')),
      bodyBuilder: (ctx, vm) =>
          PurchaseOrderEditLayout(vm: vm, showPdfTab: !narrow),
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (p) => p.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<PurchaseOrderAction>(
            // `Preview · Save · ⋮` — secondary, primary, overflow.
            leading: narrow
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      purchaseOrderDraftPreviewButton(ctx, vm),
                      SizedBox(width: InSpacing.md(ctx)),
                      saveButton,
                    ],
                  )
                : saveButton,
            items: filterForEditScreen(
              PurchaseOrderActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: PurchaseOrderActions.isLifecycle,
            ),
          ),
      saveParamFor: (a) =>
          PurchaseOrderActions.saveParamFor(a as PurchaseOrderAction),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return PurchaseOrderActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as PurchaseOrderAction,
        );
      },
      // Create-mode: resolve the tmp id to the real one so navigating actions
      // (Send Email, View PDF) keep their navigation instead of the redirect.
      onAfterSaveActionOnCreate: (ctx, saved, a) {
        final services = ctx.read<Services>();
        final companyId = services.auth.session.value!.currentCompanyId;
        return dispatchAfterSaveOnCreate<PurchaseOrder, PurchaseOrderAction>(
          ctx,
          saved: saved,
          idOf: (p) => p.id,
          withId: (p, id) => p.copyWith(id: id),
          resolveId: services.purchaseOrders.resolveId,
          action: a as PurchaseOrderAction,
          navigatesOnCreate: PurchaseOrderActions.navigatesOnCreate,
          dispatch: (c, resolved, act) => PurchaseOrderActions.dispatch(
            c,
            services,
            companyId,
            resolved,
            act,
          ),
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/purchase_orders',
        savedId: saved.id,
      ),
    );
  }
}
