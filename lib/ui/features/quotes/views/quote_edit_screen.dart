import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/after_save_create_action.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/seed_client_invitations.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/edit/quote_edit_layout.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';

class QuoteEditScreen extends StatelessWidget {
  const QuoteEditScreen({this.existingId, this.cloneFrom, super.key});

  final String? existingId;

  /// Edit-mode override draft (parallels InvoiceEditScreen). Null for a normal
  /// edit (uses the fetched record) and for create (which reads the staged
  /// draft via `Services.takeCreateDraft`).
  final Quote? cloneFrom;

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
    return EntityEditScreenScaffold<Quote, QuoteEditViewModel>(
      existingId: existingId,
      entityTypeName: 'quote',
      fetchExisting: (ctx, services, companyId, id) =>
          services.quotes.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) {
        // Create-mode seed staged on `Services` (route extra:/query is dropped
        // cross-branch + on screen reuse); the keyed `/new` route recreates the
        // screen on each stage so buildVm re-reads it. `cloneFrom` is the
        // edit-mode override (parallels InvoiceEditScreen).
        final clone =
            cloneFrom ??
            (existing == null
                ? services.takeCreateDraft<Quote>('/quotes')
                : null);
        final vm = QuoteEditViewModel(
          repo: services.quotes,
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
        // Embedded Project → Quotes-tab "New" stages a draft with a projectId
        // but no client; resolve the project's client so its contacts seed.
        // Actions that bake the clientId skip this. PostFrame per the
        // InvoiceEditScreen trace.
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
          existingId == null ? ctx.tr('new_quote') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_quote')
          : (vm.draft.number.isNotEmpty
                ? '${ctx.tr('edit')} · #${vm.draft.number}'
                : ctx.tr('edit')),
      bodyBuilder: (ctx, vm) => QuoteEditLayout(vm: vm, showPdfTab: !narrow),
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (q) => q.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<QuoteAction>(
            // `Preview · Save · ⋮` — secondary, primary, overflow.
            leading: narrow
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      quoteDraftPreviewButton(ctx, vm),
                      SizedBox(width: InSpacing.md(ctx)),
                      saveButton,
                    ],
                  )
                : saveButton,
            items: filterForEditScreen(
              QuoteActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: QuoteActions.isLifecycle,
            ),
          ),
      saveParamFor: (a) => QuoteActions.saveParamFor(a as QuoteAction),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return QuoteActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as QuoteAction,
        );
      },
      // Create-mode: resolve the tmp id to the real one so navigating actions
      // (Send Email, View PDF) keep their navigation instead of the redirect.
      onAfterSaveActionOnCreate: (ctx, saved, a) {
        final services = ctx.read<Services>();
        final companyId = services.auth.session.value!.currentCompanyId;
        return dispatchAfterSaveOnCreate<Quote, QuoteAction>(
          ctx,
          saved: saved,
          idOf: (q) => q.id,
          withId: (q, id) => q.copyWith(id: id),
          resolveId: services.quotes.resolveId,
          action: a as QuoteAction,
          navigatesOnCreate: QuoteActions.navigatesOnCreate,
          dispatch: (c, resolved, act) =>
              QuoteActions.dispatch(c, services, companyId, resolved, act),
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/quotes',
        savedId: saved.id,
      ),
    );
  }
}
