import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/payment_types.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/after_save_create_action.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/payments/seed_payment_create_defaults.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_edit_layout.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';
import 'package:admin/ui/features/payments/widgets/payment_actions.dart';

class PaymentEditScreen extends StatelessWidget {
  const PaymentEditScreen({this.existingId, this.cloneFrom, super.key});

  final String? existingId;

  /// Edit-mode override draft (parallels InvoiceEditScreen). Null for a normal
  /// edit (uses the fetched record) and for create (which reads the staged
  /// draft via `Services.takeCreateDraft`).
  final Payment? cloneFrom;

  @override
  Widget build(BuildContext context) {
    return EntityEditScreenScaffold<Payment, PaymentEditViewModel>(
      existingId: existingId,
      entityTypeName: 'payment',
      fetchExisting: (ctx, services, companyId, id) =>
          services.payments.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) {
        // Default send-email starts false; the form's switch lets the user
        // opt in. Honoring the company-wide
        // `client_manual_payment_notification` setting as the default is a
        // follow-up (the setting isn't lifted onto the auth session's
        // `AuthCompany`, and reading it from the company repo here would
        // be async — postponed until a single-shot accessor lands).
        // Capture `ctx` once so validation messages thrown from `performSave`
        // can be translated without dragging BuildContext through the VM
        // method signatures. Safe because the scaffold owns the ctx for
        // the VM's lifetime.
        // Create-mode seed staged on `Services` (route extra:/query is dropped
        // cross-branch + on screen reuse); the keyed `/new` route recreates the
        // screen on each stage so buildVm re-reads it. `cloneFrom` is the
        // edit-mode override. Sources (client/invoice/credit) stage a payment
        // draft (clientId + any paymentables) before navigating.
        final clone =
            cloneFrom ??
            (existing == null
                ? services.takeCreateDraft<Payment>('/payments')
                : null);
        final vm = PaymentEditViewModel(
          repo: services.payments,
          companyId: companyId,
          existing: existing,
          cloneFrom: clone,
          translate: ctx.tr,
          useCommaAsDecimalPlace:
              services
                  .formatterIfReady(companyId)
                  ?.settings
                  .useCommaAsDecimalPlace ??
              false,
          sync: services.sync,
          connectivity: services.connectivity,
        );
        // The client's own Default Payment Type, else its last payment's
        // type, else the group's / company's (docs/payment-types.md).
        seedPaymentCreateDefaults(
          settings: services.settings,
          companyId: companyId,
          vm: vm,
          client: PaymentClientLookups(
            clientOverride: (clientId) async => defaultPaymentTypeId(
              (await services.clients
                      .watch(companyId: companyId, id: clientId)
                      .first)
                  ?.settings,
            ),
            lastPaymentType: (clientId) =>
                services.payments.lastManualTypeForClient(
                  companyId: companyId,
                  clientId: clientId,
                ),
            refreshLastPayment: (clientId) =>
                services.payments.refreshLatestForClient(
                  companyId: companyId,
                  clientId: clientId,
                ),
            // A type the company hides is passed over for the default.
            hiddenTypeIds: () async => parseHiddenPaymentTypes(
              (await services.company.get(
                companyId,
              ))?.settings.hiddenPaymentTypes,
            ),
          ),
        );
        return vm;
      },
      titleWhileLoading: (ctx) =>
          existingId == null ? ctx.tr('new_payment') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_payment')
          : (vm.draft.number.isNotEmpty
                ? '${ctx.tr('edit')} · #${vm.draft.number}'
                : ctx.tr('edit')),
      bodyBuilder: (ctx, vm) => PaymentEditLayout(vm: vm),
      // Paying an invoice where a card payment this device took may have
      // been charged could count the money twice: a new payment, or an
      // existing one newly applied to it.
      confirmSave: (ctx, vm) {
        final before = {
          for (final p in vm.original?.paymentables ?? const <Paymentable>[])
            p.invoiceId,
        };
        final invoiceIds = [
          for (final p in vm.draft.paymentables)
            if (p.invoiceId.isNotEmpty && !before.contains(p.invoiceId))
              p.invoiceId,
        ];
        if (invoiceIds.isEmpty) return Future.value(true);
        final services = ctx.read<Services>();
        return InvoiceActions.cardPaymentsSettled(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          invoiceIds,
        );
      },
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (p) => p.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<PaymentAction>(
            leading: saveButton,
            items: filterForEditScreen(
              PaymentActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: PaymentActions.isLifecycle,
            ),
          ),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return PaymentActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as PaymentAction,
        );
      },
      // Create-mode: resolve the tmp id to the real one so Refund keeps its
      // navigation instead of the detail redirect.
      onAfterSaveActionOnCreate: (ctx, saved, a) {
        final services = ctx.read<Services>();
        final companyId = services.auth.session.value!.currentCompanyId;
        return dispatchAfterSaveOnCreate<Payment, PaymentAction>(
          ctx,
          saved: saved,
          idOf: (p) => p.id,
          withId: (p, id) => p.copyWith(id: id),
          resolveId: services.payments.resolveId,
          action: a as PaymentAction,
          navigatesOnCreate: PaymentActions.navigatesOnCreate,
          dispatch: (c, resolved, act) =>
              PaymentActions.dispatch(c, services, companyId, resolved, act),
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/payments',
        savedId: saved.id,
      ),
    );
  }
}
