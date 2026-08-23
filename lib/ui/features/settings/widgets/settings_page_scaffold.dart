import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_scope.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Top-level chrome for any settings page backed by a
/// [SettingsDraftViewModel] subclass (or any [SettingsDraftHost]
/// implementation). Wires:
///
/// * `MultiProvider` exposing the VM as both `ChangeNotifierProvider<V>` and
///   `Provider<SettingsDraftHost>` (so override widgets bind via the
///   interface).
/// * `UnsavedChangesScope` + `PopScope` with the discard-on-exit dialog.
/// * `SettingsScreenScaffold` with title, Save button (state-driven from
///   the VM), caller's `extraActions`, and optional `bottom` (e.g. a
///   [TabBar] for tabbed pages).
/// * Spinner while loading; the inline [_LoadErrorBanner] above the body
///   when `viewModel.loadError` is set.
/// * `FormSaveScope` wrapping the body so Enter on single-line fields fires
///   the same save callback the Save button uses.
/// * Success / error toast via [Notify] on save.
///
/// The [SettingsLevelController] is read from the ambient `Provider` chain
/// (mounted once in `main.dart` and held on `Services.settingsLevel`), not
/// created per-page — that's the only way the override widgets and the
/// scope banner can stay in sync with a level set by another part of the
/// app (e.g. the client-detail "Settings" action).
///
/// New settings pages compose: own a VM, build a body widget, return
/// `SettingsPageScaffold(titleKey: …, viewModel: vm, body: …)`. The tabbed
/// case (Company Details) supplies `bottom: TabBar(…)` and `body:
/// TabBarView(…)` — the scaffold is shape-agnostic.
class SettingsPageScaffold<V extends SettingsDraftHost>
    extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.titleKey,
    required this.viewModel,
    required this.body,
    this.bottom,
    this.extraActions = const <Widget>[],
    this.saveVisible,
    this.canSaveOverride,
  });

  /// Localization key for the AppBar title.
  final String titleKey;

  /// Per-page view-model. Caller owns lifecycle — the scaffold takes it
  /// by `Provider.value` and never disposes it.
  final V viewModel;

  /// Page body. Receives access to `viewModel` (typed) and
  /// `SettingsDraftHost` via Provider. Wrap form content in
  /// [SettingsFormShell] for the standard padding + width constraints.
  final Widget body;

  /// Optional AppBar bottom (typically a [TabBar] for tabbed pages).
  final PreferredSizeWidget? bottom;

  /// Additional AppBar action widgets rendered to the right of the Save
  /// button.
  final List<Widget> extraActions;

  /// Optional toggle for the AppBar Save button. Defaults to always-visible.
  /// Tabbed shells flip this off on tabs that don't bind to the VM (e.g.
  /// Two-Factor's self-contained flow, the device-local Preferences tab)
  /// so the Save button doesn't read as a no-op there.
  final ValueListenable<bool>? saveVisible;

  /// Optional gate ANDed with the scaffold's default `isDirty && !isSaving`
  /// before enabling Save / Enter-submit. Lets a screen veto save until extra
  /// pre-conditions hold (Email Settings disables save when Gmail / Microsoft
  /// is selected without a sending user). Re-evaluated on every VM notify.
  final bool Function(SettingsDraftHost host)? canSaveOverride;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<V>.value(value: viewModel),
        // Expose the same VM as the abstract host so override widgets bind
        // via the interface, not the concrete subclass type. Skip when V
        // already IS the host (CascadeSettingsScaffold's case) — registering
        // the same provider type twice just shadows the outer.
        if (V != SettingsDraftHost)
          ChangeNotifierProvider<SettingsDraftHost>.value(value: viewModel),
      ],
      child: _SettingsPageBody(
        titleKey: titleKey,
        viewModel: viewModel,
        body: body,
        bottom: bottom,
        extraActions: extraActions,
        saveVisible: saveVisible,
        canSaveOverride: canSaveOverride,
      ),
    );
  }
}

class _SettingsPageBody extends StatelessWidget {
  const _SettingsPageBody({
    required this.titleKey,
    required this.viewModel,
    required this.body,
    required this.bottom,
    required this.extraActions,
    required this.saveVisible,
    required this.canSaveOverride,
  });

  final String titleKey;
  final SettingsDraftHost viewModel;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final List<Widget> extraActions;
  final ValueListenable<bool>? saveVisible;
  final bool Function(SettingsDraftHost host)? canSaveOverride;

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesScope(
      isDirty: () => viewModel.isDirty,
      source: viewModel,
      onDiscard: viewModel.reset,
      child: ListenableBuilder(
        // PopScope.canPop is read at frame-build time, so the scope needs
        // to rebuild whenever the dirty state flips. Listen against the VM
        // directly rather than `context.watch` so the rest of the chrome
        // doesn't rebuild on every notify.
        listenable: viewModel,
        builder: (context, _) {
          return PopScope(
            canPop: !viewModel.isDirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              if (!viewModel.isDirty) return;
              final discard = await showDiscardChangesDialog(context);
              if (!discard) return;
              viewModel.reset();
              if (!context.mounted) return;
              // `pop`, not `maybePop`: `PopScope.canPop` is a build-time value
              // and its notifier hasn't caught up with the `reset()` above, so
              // the route still reports `doNotPop` — `maybePop` would re-enter
              // this very callback, hit the `!isDirty` early-return above, and
              // silently leave the user on the page they just discarded.
              // Guarded because `pop` has no floor of its own: it pops whatever
              // is on top, even the last route.
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
            child: SettingsScreenScaffold(
              titleKey: titleKey,
              actions: [
                _SaveButton(
                  viewModel: viewModel,
                  visible: saveVisible,
                  canSaveOverride: canSaveOverride,
                ),
                const SizedBox(width: 8),
                ...extraActions,
              ],
              bottom: bottom,
              body: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) {
                  // Hold the spinner until both `isLoaded` and the host's
                  // own `draftReady` gate (default `true`; the company VM
                  // narrows it to `_draft != null`) flip — see
                  // [SettingsDraftHost.draftReady] for why a tabbed shell
                  // needs the extra frame.
                  if (!viewModel.isLoaded || !viewModel.draftReady) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final err = viewModel.loadError;
                  final canSave =
                      viewModel.isDirty &&
                      !viewModel.isSaving &&
                      (canSaveOverride?.call(viewModel) ?? true);
                  final wrapped = FormSaveScope(
                    enabled: canSave,
                    onSubmit: () => runSettingsSave(context, viewModel),
                    child: body,
                  );
                  if (err != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LoadErrorBanner(message: err),
                        Expanded(child: wrapped),
                      ],
                    );
                  }
                  return wrapped;
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Save the [viewModel]'s draft and surface the outcome as a [Notify] toast.
/// Shared by the Save button and `FormSaveScope.onSubmit` so Enter and tap
/// take the same path.
@visibleForTesting
Future<void> runSettingsSave(
  BuildContext context,
  SettingsDraftHost viewModel,
) async {
  // Commit any typed-but-unblurred field before reading the draft. A settings
  // markdown field (OverridableMarkdownField → MarkdownTextField) emits on a
  // ~300ms debounce and flushes synchronously on blur, but clicking Save /
  // pressing Enter doesn't blur the editor — so without this a value typed in
  // the last debounce window is silently dropped from the saved payload while
  // the toast says "Saved" (finding U5, same mechanism as the entity-edit ⌘S
  // flush in `entity_edit_scaffold._runSave`). Unfocus fires the field's
  // focus-loss commit; the FocusManager applies focus changes on a microtask,
  // so yield once before reading the draft.
  final focus = FocusManager.instance.primaryFocus;
  if (focus != null && focus.context != null) {
    focus.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
  }
  final successText = context.tr('saved_settings');
  final errorFallback = context.tr('error_refresh_page');
  final result = await viewModel.save();
  if (!context.mounted) return;
  if (result != null) {
    Notify.success(context, successText);
    return;
  }
  // The VM stashes the raw exception text on `submitError`; surface it as
  // the detail line so the user (or dev tester) sees what actually broke
  // instead of a generic banner.
  Notify.error(context, errorFallback, detail: viewModel.submitError);
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.viewModel,
    required this.visible,
    required this.canSaveOverride,
  });

  final SettingsDraftHost viewModel;
  final ValueListenable<bool>? visible;
  final bool Function(SettingsDraftHost host)? canSaveOverride;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final button = ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final canSave =
            viewModel.isDirty &&
            !viewModel.isSaving &&
            (canSaveOverride?.call(viewModel) ?? true);
        return TextButton(
          onPressed: canSave ? () => runSettingsSave(context, viewModel) : null,
          style: TextButton.styleFrom(foregroundColor: tokens.accent),
          child: viewModel.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('save')),
        );
      },
    );
    final v = visible;
    if (v == null) return button;
    return ValueListenableBuilder<bool>(
      valueListenable: v,
      builder: (context, value, _) => value ? button : const SizedBox.shrink(),
    );
  }
}

/// Inline error banner shown above the body when `viewModel.loadError` is
/// set. The form below it still renders against whatever subset of the
/// settings the typed parse could recover, so the user can read + edit the
/// parts that work while the developer chases down the bad field.
class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('error_refresh_page'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SelectableText(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: context.tr('copy'),
              color: theme.colorScheme.onErrorContainer,
              onPressed: () => _copy(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) => copyToClipboard(
    context,
    // No label — `message` is short, readable text, so naming it in the toast
    // is more useful than a generic noun.
    message,
  );
}
