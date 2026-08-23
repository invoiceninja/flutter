import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_scope.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/shortcut_hint_scope.dart';

/// Shared chrome for an entity edit / create screen.
///
/// Owns:
///   * The AppBar (title + Save button with a saving spinner).
///   * The `FormSaveScope` wiring so Enter inside any single-line field
///     submits the form.
///   * The `PopScope` + `UnsavedChangesScope` discard-confirmation guard.
///   * The post-save side effects: success toast → navigation; non-422
///     errors → SnackBar; 422 errors leave the screen open so inline
///     `errorText` on the fields can drive the fix.
///
/// Concrete screens pass:
///   * a [GenericEditViewModel] (`ClientEditViewModel`, …)
///   * [canSave] — usually `!vm.isSaving && (vm.isCreate ? name.notEmpty : vm.isDirty)`
///   * [titleBuilder] — entity-specific title (Create / Edit · displayName)
///   * [bodyBuilder]  — the form body (cards, fields)
///   * [resetToEmpty] — called by the discard guard when the user picks
///     Discard; concrete VMs implement this with their empty-draft factory
///   * [onSaved] — what to do after a successful save. Defaults to
///     `context.pop()` for edit mode, `context.go(detailRoute)` for create.
class EntityEditScaffold<T> extends StatelessWidget {
  const EntityEditScaffold({
    super.key,
    required this.vm,
    required this.canSave,
    required this.titleBuilder,
    required this.bodyBuilder,
    required this.resetToEmpty,
    required this.onSaved,
    this.onSaveRejected,
    this.topBanner,
    this.embedded = false,
    this.actionsBuilder,
    this.saveParamFor,
    this.onAfterSaveAction,
    this.onAfterSaveActionOnCreate,
    this.onSaveCleanup,
  });

  final GenericEditViewModel<T> vm;
  final bool canSave;
  final String Function(BuildContext context) titleBuilder;
  final Widget Function(BuildContext context) bodyBuilder;
  final VoidCallback resetToEmpty;

  /// Invoked with the saved entity. Concrete screens decide whether to pop
  /// or go to a detail route. Awaited — async cleanup (e.g. deleting a
  /// prior dead outbox row before navigating away) is safe here.
  final FutureOr<void> Function(BuildContext context, T saved) onSaved;

  /// Invoked when [GenericEditViewModel.save] returns null with non-empty
  /// `fieldErrors` (i.e. the server has rejected the save — typically a
  /// 422). The screen uses this to re-fetch the dead outbox row id so the
  /// SaveFailedBanner's Discard button can act on the *fresh* failure,
  /// not a stale link from the prior load. Awaited.
  final FutureOr<void> Function()? onSaveRejected;

  /// Optional banner pinned between the AppBar and the form body. Used by
  /// `SaveFailedBanner` to surface a prior 422 across the whole form.
  /// Renders nothing on screens that don't pass one.
  final Widget? topBanner;

  /// When `true`, the scaffold returns only its body — no outer
  /// `Scaffold`, no `AppBar`. The Save button moves to a thin header
  /// strip rendered above the form body. Used when this edit screen is
  /// hosted inside another container (e.g. the `MasterDetailLayout`
  /// right pane on wide desktop) so the parent's chrome isn't
  /// duplicated.
  final bool embedded;

  /// Builds the right-aligned, overflow-aware header action cluster. The
  /// per-entity caller owns the action enum `A`; it returns an
  /// `EntityOverflowActionBar<A>` with the plain [saveButton] forwarded as
  /// its `leading:` child (Save is the first, never-collapsing item of the
  /// single `OverflowView`, mirroring detail screens' primary button) and
  /// wires each item's `onTap` to the type-erased sink. Null on screens
  /// that don't surface an action bar (Save then renders standalone, still
  /// right-aligned via `actionsWidget ?? saveButton`).
  final Widget Function(
    BuildContext context,
    void Function(Object action) onTap,
    Widget saveButton,
  )?
  actionsBuilder;

  /// Classifies an action as SAVE-PARAM. Non-null result => the action is
  /// performed *by* the save request via these query params (the server
  /// creates/updates and acts atomically). Null => AFTER-SAVE (save first,
  /// then run [onAfterSaveAction]). Null overall => every action is
  /// after-save (entities with no save-param actions omit this).
  final Map<String, String>? Function(Object action)? saveParamFor;

  /// Runs the entity's existing `<E>Actions.dispatch` for an AFTER-SAVE
  /// action against the freshly-saved (or, on the skip-redundant-save
  /// path, the unchanged) entity. The per-entity closure casts `action`
  /// back to its enum.
  final Future<void> Function(BuildContext context, T saved, Object action)?
  onAfterSaveAction;

  /// CREATE-mode-only variant of [onAfterSaveAction]. Dispatches the after-save
  /// action against the freshly-created entity and returns whether the action
  /// took over post-save navigation. When it returns `true` the create branch
  /// skips its default `saved` toast + [onSaved] detail redirect so the
  /// action's own navigation (e.g. billing-doc Send Email → the email screen,
  /// once the create has drained and the tmp id resolves to a real id) isn't
  /// immediately overridden. The per-entity closure typically delegates to
  /// `dispatchAfterSaveOnCreate` (`after_save_create_action.dart`), which
  /// resolves the tmp id first so server-bound actions act on the real entity.
  /// Null (the default) ⇒ create mode falls back to [onAfterSaveAction] then
  /// [onSaved], preserving today's behavior for every entity that doesn't opt
  /// in. Ignored outside create mode (edit / skip-save use [onAfterSaveAction]).
  final Future<bool> Function(BuildContext context, T saved, Object action)?
  onAfterSaveActionOnCreate;

  /// Prior-dead-outbox-row cleanup that normally rides inside [onSaved]. The
  /// edit-mode AFTER-SAVE branch dispatches its action without calling
  /// [onSaved] (the action owns navigation), so it invokes this directly after
  /// a successful re-save — otherwise a prior 422's `dead` row lingers and the
  /// entity re-hydrates a false SaveFailedBanner on the next open. Awaited.
  final FutureOr<void> Function()? onSaveCleanup;

  Future<bool> _confirmDiscard(BuildContext context) async {
    if (!vm.isDirty) return true;
    return showDiscardChangesDialog(context);
  }

  /// Runs `vm.save()` and surfaces failures (non-422 SnackBar, 422
  /// dead-row re-link). Returns the saved entity on success, null on
  /// failure. Does **not** toast success or navigate — the caller decides
  /// (plain Save navigates via [onSaved]; an AFTER-SAVE action dispatches
  /// instead).
  Future<T?> _runSave(BuildContext context) async {
    // Commit any typed-but-unblurred field before reading the draft. InDateField
    // / InTimeField / MarkdownTextField only commit on blur or Enter, but ⌘S and
    // the Save button don't blur the active field — so without this a value the
    // user typed and didn't Enter/tab away from is silently dropped. Unfocus
    // fires each field's focus-loss commit; the FocusManager applies focus
    // changes on a microtask, so yield once before reading the draft.
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) {
      focus.unfocus();
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return null;
    }
    final result = await vm.save();
    if (!context.mounted) return null;
    if (result == null) {
      if (vm.fieldErrors.isNotEmpty) {
        // Server rejected validation — let the screen pick up the freshly
        // created dead outbox row so the banner's Discard / Retry actions know
        // which row they act on. Fire-and-await; screen handles its own
        // mounted check. Skipped for a client-side [validate] block: no
        // row was written, and the dead-row lookup could otherwise surface
        // an unrelated stale row and clobber the local field errors.
        //
        // The inline per-field text plus the banner (which now also renders
        // the server's top-level message and any unmapped keys) carry the
        // detail here, so no toast — a duplicate would just cover the fields
        // the user has to fix.
        if (!vm.localValidationOnly) await onSaveRejected?.call();
      } else if (vm.submitError != null) {
        // No per-field mapping to fall back on (network, 5xx, permanent 4xx):
        // the server's own words are all the user gets.
        Notify.error(
          context,
          context.tr('could_not_save'),
          detail: vm.submitError,
        );
      }
      return null;
    }
    return result;
  }

  /// Plain Save (Save button / Enter / ⌘S) and the SAVE-PARAM action path:
  /// save, then on success toast + navigate via [onSaved]. For a SAVE-PARAM
  /// action the caller has already stashed the query on the VM, so the same
  /// save round-trip carries the action — nothing extra runs afterward.
  Future<void> _onSave(BuildContext context) async {
    final result = await _runSave(context);
    if (result == null || !context.mounted) return;
    // On a sync-wait timeout the server hasn't confirmed yet, so a plain
    // "Saved" toast misleads the user into thinking the save landed; show
    // a "Saving in background…" message instead. Offline saves are unchanged
    // — `lastSaveWasOptimistic` stays false on the offline path.
    final toastKey = vm.lastSaveWasOptimistic
        ? 'saving_in_background'
        : 'saved';
    Notify.success(context, context.tr(toastKey));
    await onSaved(context, result);
  }

  /// Overflow action-bar tap. Three buckets (see plan / CLAUDE.md):
  ///   * SAVE-PARAM  — server performs it via the save request's query.
  ///   * AFTER-SAVE  — save first, then `<E>Actions.dispatch`.
  ///   * skip-save   — unchanged existing record + after-save action:
  ///                   dispatch directly, no redundant outbox row.
  Future<void> _onAction(BuildContext context, Object action) async {
    if (vm.isSaving) return;
    final query = saveParamFor?.call(action);

    if (query != null) {
      // SAVE-PARAM: the action *is* the change to persist, so it must not
      // require `isDirty` (some screens fold `isDirty` into `canSave` — a
      // mark-sent on an untouched existing record must still go through).
      // The `vm.isSaving` guard at the top of _onAction already covers the
      // busy case; in create mode still enforce the screen's create-validity
      // gate (e.g. invoice needs a client) since `canSave` carries it.
      if (vm.isCreate && !canSave) return;
      vm.setPendingSaveQuery(query);
      await _onSave(context);
      return;
    }

    // AFTER-SAVE / SECOND-REQUEST.
    final wasCreate = vm.isCreate;
    if (!wasCreate && !vm.isDirty) {
      // Skip-redundant-save: nothing to persist — dispatch straight away
      // (matches old admin-portal `isOld && !isChanged && isClientSide`).
      await onAfterSaveAction?.call(context, vm.draft, action);
      return;
    }
    // Must persist first; same validity gate as Save.
    if (!canSave) return;
    final saved = await _runSave(context);
    if (saved == null || !context.mounted) return;
    if (wasCreate) {
      // The just-saved entity still carries its `tmp_<uuid>` id (save() returns
      // the draft even after a successful online drain). A create-mode handler,
      // when supplied, resolves that to the real id and dispatches against it —
      // and reports whether the action took over navigation (e.g. Send Email →
      // the email screen). When it did, skip the default toast + detail
      // redirect so that navigation isn't overridden. Otherwise (no handler, or
      // the action didn't navigate — offline / non-navigating) leave create
      // mode via the normal post-save navigation so a second Save can't create
      // a duplicate.
      bool navigated = false;
      if (onAfterSaveActionOnCreate != null) {
        navigated = await onAfterSaveActionOnCreate!(context, saved, action);
      } else {
        await onAfterSaveAction?.call(context, saved, action);
      }
      if (!context.mounted) return;
      if (navigated) return;
      Notify.success(context, context.tr('saved'));
      await onSaved(context, saved);
      return;
    }
    // Editing an existing record: real id — dispatch owns its own
    // toast/navigation (clone → go to new, email → sheet, …). This branch
    // skips onSaved, so run the prior-dead-row cleanup it would have done,
    // otherwise a resolved 422 lingers as a false SaveFailedBanner on reopen.
    await onSaveCleanup?.call();
    if (!context.mounted) return;
    await onAfterSaveAction?.call(context, saved, action);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesScope(
      isDirty: () => vm.isDirty,
      source: vm,
      onDiscard: resetToEmpty,
      child: PopScope(
        canPop: !vm.isDirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await _confirmDiscard(context);
          if (!shouldPop) return;
          // Leave the VM clean before leaving: the navigation below re-enters
          // the route's `onExit` discard guard, which would otherwise see this
          // editor still-dirty and prompt a second time (the system-back /
          // Android twin of the chained-guard bug). Mirrors what
          // `_closePaneAnimated`'s up-front `confirmIfDirty` relies on.
          if (vm.isDirty) resetToEmpty();
          if (!context.mounted) return;
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
            return;
          }
          // Create routes (`/x/new`) are *siblings* of the list inside the
          // entity `ShellRoute`, so nothing anywhere holds a second page and
          // `pop()` throws `GoError('There is nothing to pop')` — Discard
          // silently did nothing on Android. Navigate to the same close target
          // the pane's leading arrow uses instead.
          final uri = GoRouterState.of(context).uri;
          router.go(
            entityCloseTargetPath(
              basePath: entityBasePathFromEditorPath(uri.path),
              currentPath: uri.path,
              isFullView: uri.queryParameters['view'] == 'full',
            ),
          );
        },
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            final saveLabel = context.tr('save');
            // Save is the OverflowView's `leading` child — measured inside
            // `OverflowView`'s layout callback. It must therefore be a
            // plain button: NO `Tooltip` and NO `AnimatedSize` (both
            // markNeedsLayout / mount an `OverlayPortal` during layout,
            // which corrupts the element tree — the `_elements.contains` /
            // `_ReorderableItem` crash). This mirrors the detail screens'
            // plain `isPrimary` FilledButton, which is crash-free. The ⌘S
            // shortcut still works via the body's Shortcuts/Actions. The
            // saving state swaps to a fixed-size spinner (repaint-only,
            // safe) without animating the button's width.
            final saveButton = FilledButton(
              // Stable, locale-independent hook for integration tests
              // (demo_harness.tapSave). The label is context.tr('save'),
              // so a text/type finder is fragile — key it instead.
              key: const ValueKey('entity_edit_save'),
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: canSave ? () => _onSave(context) : null,
              child: vm.isSaving
                  ? const SizedBox(
                      width: 36,
                      height: 16,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Text(saveLabel),
            );
            // Overflow entity-action bar (Email / Mark sent / Clone / …).
            // Built by the per-entity caller. The plain [saveButton] is
            // folded in as the bar's `leading:` child so the whole cluster
            // is one bounded `OverflowView` (extras collapse into "More")
            // wrapped in the proven `SizedBox(∞)` + `Align(centerRight)`
            // pattern — exactly how detail screens render their primary
            // button. Save is plain (no Tooltip/AnimatedSize) so being
            // measured in the OverflowView layout callback is safe.
            final actionsWidget = actionsBuilder?.call(
              context,
              (action) => _onAction(context, action),
              saveButton,
            );
            final body = ShortcutHintScope(
              hints: [
                ShortcutHint(
                  keys: [platformModifierLabel(), 'S'],
                  labelKey: 'save',
                ),
              ],
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                      _SaveFormIntent(),
                  SingleActivator(LogicalKeyboardKey.keyS, control: true):
                      _SaveFormIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _SaveFormIntent: CallbackAction<_SaveFormIntent>(
                      onInvoke: (_) {
                        // Mirror the Save button — same gate, same handler.
                        // Pressing ⌘S while the form is invalid or already
                        // saving is a silent no-op.
                        if (canSave) _onSave(context);
                        return null;
                      },
                    ),
                  },
                  child: FormSaveScope(
                    enabled: canSave,
                    onSubmit: () => _onSave(context),
                    child: topBanner == null
                        ? bodyBuilder(context)
                        : Column(
                            children: [
                              topBanner!,
                              Expanded(child: bodyBuilder(context)),
                            ],
                          ),
                  ),
                ),
              ),
            );
            // Embedded mode: no Scaffold / AppBar — render an inline
            // header strip with the title + Save button so the host
            // shell's chrome owns the window-level slots. Auto-detect
            // when mounted inside a master-detail right pane so
            // concrete screens never need to pass `embedded: true`.
            final inPane = MasterDetailPaneScope.isInPane(context);
            if (embedded || inPane) {
              // When mounted inside the slide-over pane, the layout
              // publishes its X + full-screen icons through the scope.
              // Render them at the trailing end of the header so they
              // share a row with Save instead of floating overlay on
              // top of it.
              final paneActions = MasterDetailPaneScope.paneActionsOf(context);
              // Narrow viewport: the pane publishes a leading back arrow (and
              // no trailing X / full-screen toggle).
              final paneLeading = MasterDetailPaneScope.paneLeadingOf(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsetsDirectional.only(
                      start: paneLeading != null ? 4 : 16,
                      end: 4,
                      top: 4,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      // Match the detail / list AppBars (M3 default
                      // `ColorScheme.surface`) instead of showing through to
                      // the pane's `inTheme.bg` — white in light mode, the
                      // dark surface in dark mode.
                      color: context.inTheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = Breakpoints.isWide(constraints);
                        // The bar reads this to render the spread bar (wide) or
                        // the compact Save + `⋮` (narrow) — decided here from the
                        // full header width, not the bar's reduced slot.
                        final actions = ActionBarLayoutScope(
                          wide: wide,
                          child: actionsWidget ?? saveButton,
                        );
                        final title = Text(
                          titleBuilder(context),
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                        return Row(
                          children: [
                            if (paneLeading != null) ...[
                              paneLeading,
                              const SizedBox(width: 4),
                            ],
                            // Wide: title is NON-flex (capped + ellipsised) so
                            // the actions `Expanded` is the *only* flex child and
                            // the "More"-collapsing OverflowView gets every
                            // remaining pixel. Narrow: the actions are a fixed
                            // Save + `⋮` cluster, so the title flexes /
                            // ellipsises instead and yields room — otherwise the
                            // cluster would overflow a tight slot.
                            if (wide) ...[
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: title,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: actions,
                                ),
                              ),
                            ] else ...[
                              Expanded(child: title),
                              const SizedBox(width: 12),
                              actions,
                            ],
                            if (paneActions != null) ...[
                              const SizedBox(width: 8),
                              paneActions,
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  Expanded(child: body),
                ],
              );
            }
            return Scaffold(
              appBar: AppBar(
                titleSpacing: 16,
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = Breakpoints.isWide(constraints);
                    final actions = ActionBarLayoutScope(
                      wide: wide,
                      child: actionsWidget ?? saveButton,
                    );
                    final title = Text(
                      titleBuilder(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                    // Wide: capped, non-flex title so the actions `Expanded`
                    // gets every remaining pixel for the spread "More" bar.
                    // Narrow: the actions are a fixed Save + `⋮` cluster, so the
                    // title flexes / ellipsises and yields room instead.
                    return Row(
                      children: wide
                          ? [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: title,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: actions,
                                ),
                              ),
                            ]
                          : [
                              Expanded(child: title),
                              const SizedBox(width: 12),
                              actions,
                            ],
                    );
                  },
                ),
              ),
              body: body,
            );
          },
        ),
      ),
    );
  }
}

class _SaveFormIntent extends Intent {
  const _SaveFormIntent();
}
