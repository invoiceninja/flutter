import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/offline_banner.dart';
import 'package:admin/ui/features/settings/views/advanced/debug_panel_section.dart';
import 'package:admin/ui/features/shell/branch_company_gate.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';
import 'package:admin/ui/features/shell/widgets/keyboard_shortcuts_dialog.dart';
import 'package:admin/ui/features/shell/widgets/nav_history_buttons.dart';
import 'package:admin/ui/features/shell/widgets/window_caption_strip.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';
import 'package:admin/ui/features/shell/widgets/sync_event_listener.dart';
import 'package:admin/ui/features/tasks/widgets/running_timer_pill.dart';

/// Persistent shell for the authenticated app.
///
/// Hosts the active [StatefulNavigationShell] branch and renders
/// width-appropriate navigation: the v2 design `InSidebar` on wide layouts,
/// and on narrow ones a passthrough where each top-level screen supplies its
/// own `Scaffold` with `drawer: AppDrawer()` + a `DrawerHamburger`.
///
/// There is **no bottom navigation bar** — `NavigationBar` /
/// `BottomNavigationBar` / `NavigationRail` appear nowhere in `lib/`. Mobile
/// navigation is drawer-only. (This doc and `adaptive.dart` both used to
/// claim a bottom bar that never shipped; the `MobileTopBar` it named was
/// deprecated, unreferenced, and has been deleted.)
///
/// Global keyboard shortcuts live here:
/// - `⌘K` / `Ctrl+K` opens the company picker; `⌘/` / `Ctrl+/` opens the
///   global command palette.
/// - `⌘B` / `Ctrl+B` toggles the wide-layout sidebar.
/// - `⌘,` / `Ctrl+,` opens Settings (macOS Preferences convention).
/// - `?` opens the Keyboard Shortcuts helper dialog.
/// - `/` focuses the active list screen's token search field (no-op on
///   screens without one).
/// - `G` followed by a letter (`D`/`C`/`I`/`P`/`S`/`T`) jumps to the
///   matching sidebar branch (Dashboard / Clients / Invoices / Products
///   / Settings / Tasks). Leader-key sequence with a 1.5 s window.
///
/// `?` and `/` use [CharacterActivator] so they fire on the produced
/// character, layout-independently — `Shift+/` on US, `Shift+Comma` on
/// AZERTY, etc. Letter activators (`⌘B`, `G + letter`) use
/// [SingleActivator] on logical keys (no layout ambiguity).
class ScaffoldWithNav extends StatefulWidget {
  const ScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNav> createState() => _ScaffoldWithNavState();
}

class _ScaffoldWithNavState extends State<ScaffoldWithNav> {
  // Leader-key state. `_leaderTimer != null` means "G was pressed; the
  // next plain letter within the timeout is interpreted as a branch
  // selector." Timeout matches GitHub's leader-key convention; users get
  // 1.5 s to complete the sequence before it resets silently.
  Timer? _leaderTimer;
  static const Duration _kLeaderTimeout = Duration(milliseconds: 1500);

  /// Shared with `AppDrawer` via Provider — resets a branch's preserved
  /// stack when it is re-entered under a different company (see
  /// [BranchCompanyGate]).
  final BranchCompanyGate _branchGate = BranchCompanyGate();

  /// Token + captured controller for the always-available global
  /// shortcut-hint scope (registered in [initState], removed in [dispose]).
  /// Registered imperatively rather than via a build-tree `ShortcutHintScope`
  /// so we don't wrap the entire shell subtree.
  final Object _globalHintToken = Object();
  late final ShortcutHintController _shortcutHints;
  late final KeyboardShortcutsController _keyboardShortcuts;

  @override
  void initState() {
    super.initState();
    // Stamp every branch with the mount-time company so branches first
    // entered outside _goBranch (the boot branch, cross-branch go()) still
    // reset correctly on their first re-entry after a company switch.
    _branchGate.seedAll(
      branchCount: kBranchOrder.length,
      companyId:
          context.read<Services>().auth.session.value?.currentCompanyId ?? '',
    );
    _shortcutHints = context.read<Services>().shortcutHints;
    _keyboardShortcuts = context.read<Services>().keyboardShortcuts;
    _shortcutHints.register(_globalHintToken, _globalShortcutHints());
    // Re-register when a binding changes so the hold-modifier bar always shows
    // the user's current chords (unified with the live Shortcuts map + dialog).
    _keyboardShortcuts.addListener(_refreshGlobalHints);
  }

  void _refreshGlobalHints() {
    if (!mounted) return;
    _shortcutHints.register(_globalHintToken, _globalShortcutHints());
  }

  /// The global modifier shortcuts surfaced in the hold-modifier hint bar.
  /// Built from the resolved bindings (override → catalog default) so it stays
  /// in lock-step with the live `Shortcuts` map + the `?` dialog. Only chords
  /// that use the platform primary modifier belong in a ⌘/Ctrl bar; the bare
  /// `?` / `/` shortcuts and unbound create actions are omitted.
  List<ShortcutHint> _globalShortcutHints() {
    final mod = platformModifierLabel();
    final hints = <ShortcutHint>[];
    for (final def in kShortcutCatalog) {
      if (def.scope != ShortcutScope.global) continue;
      final binding = _keyboardShortcuts.resolvedBinding(def.id);
      if (binding == null || !binding.usesPrimary) continue;
      hints.add(
        ShortcutHint(keys: binding.displayGlyphs(mod), labelKey: def.labelKey),
      );
    }
    // History back/forward is ⌘+Arrow on Apple but Alt+Arrow on
    // Windows/Linux — a *different* modifier — so only surface it in a
    // ⌘/Ctrl bar when it matches the platform modifier (macOS/iOS). Fixed +
    // non-remappable, so it's appended directly rather than via the catalog.
    if (platformHistoryModifierLabel() == mod) {
      hints.add(ShortcutHint(keys: [mod, '←'], labelKey: 'go_back'));
      hints.add(ShortcutHint(keys: [mod, '→'], labelKey: 'go_forward'));
    }
    return hints;
  }

  late final int? _dashboardIndex = _indexOfFixed(FixedBranchKind.dashboard);
  late final int? _settingsIndex = _indexOfFixed(FixedBranchKind.settings);
  late final int? _clientsIndex = _indexOfEntity(EntityType.client);
  late final int? _productsIndex = _indexOfEntity(EntityType.product);
  late final int? _tasksIndex = _indexOfEntity(EntityType.task);
  late final int? _invoicesIndex = _indexOfEntity(EntityType.invoice);

  static int? _indexOfFixed(FixedBranchKind kind) {
    final i = kBranchOrder.indexWhere(
      (b) => b is FixedBranch && b.kind == kind,
    );
    return i < 0 ? null : i;
  }

  static int? _indexOfEntity(EntityType type) {
    final i = kBranchOrder.indexWhere(
      (b) => b is EntityBranch && b.type == type,
    );
    return i < 0 ? null : i;
  }

  @override
  void dispose() {
    _leaderTimer?.cancel();
    // Clear the global latch if the shell unmounts mid-sequence (e.g. logout
    // during the leader window) so it can't strand single-key shortcuts off.
    leaderModeArmed = false;
    _keyboardShortcuts.removeListener(_refreshGlobalHints);
    _shortcutHints.unregister(_globalHintToken);
    super.dispose();
  }

  // Last `module_off` label we surfaced a notice for. The router appends
  // `?module_off=<labelKey>` when it bounces a deep link / restored route off
  // a disabled module; we show a one-time, non-blocking notice on landing so
  // the user learns *why* they didn't resume where they left off, instead of a
  // silent teleport. Debounced because `build` re-runs on every navigation.
  String? _moduleOffNoticeShownFor;

  void _maybeNotifyModuleDisabled(BuildContext context) {
    final label = GoRouterState.of(context).uri.queryParameters['module_off'];
    if (label == null || label.isEmpty) {
      _moduleOffNoticeShownFor = null;
      return;
    }
    if (_moduleOffNoticeShownFor == label) return;
    _moduleOffNoticeShownFor = label;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Notify.info(
        context,
        context.tr('module_disabled_notice', {'module': context.tr(label)}),
      );
    });
  }

  Future<void> _goBranch(int index) async {
    final services = context.read<Services>();
    // Don't navigate into an entity branch whose module is disabled for the
    // active company (leader-key jump / saved-view shortcut). The router
    // redirect would bounce it anyway — this avoids the flash. Defensive:
    // index out of range falls through to the normal guard.
    if (index >= 0 && index < kBranchOrder.length) {
      final branch = kBranchOrder[index];
      if (branch is EntityBranch) {
        final modules =
            services.auth.session.value?.currentCompany?.enabledModules ?? 0;
        if (!isEntityModuleEnabledForCompany(branch.type, modules)) return;
      }
    }
    final guard = services.unsavedChangesGuard;
    if (!await guard.confirmIfDirty(context)) return;
    if (!context.mounted) return;
    // Re-entering a branch last visited under a different company must drop
    // its preserved stack (see [BranchCompanyGate]).
    final staleCompanyStack = _branchGate.shouldResetOnEnter(
      index: index,
      companyId: services.auth.session.value?.currentCompanyId ?? '',
    );
    widget.navigationShell.goBranch(
      index,
      initialLocation:
          staleCompanyStack || index == widget.navigationShell.currentIndex,
    );
  }

  void _enterLeaderMode() {
    _leaderTimer?.cancel();
    // Arm the global latch so descendant single-key shortcuts (list `N`, pane
    // `F`/`J`/`K`, Tasks `S`) stand down and the second key reaches this
    // handler instead of being consumed leaf-first (U3).
    leaderModeArmed = true;
    _leaderTimer = Timer(_kLeaderTimeout, () {
      _leaderTimer = null;
      leaderModeArmed = false;
    });
  }

  void _exitLeaderMode() {
    _leaderTimer?.cancel();
    _leaderTimer = null;
    leaderModeArmed = false;
  }

  int? _leaderTarget(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyD) return _dashboardIndex;
    if (key == LogicalKeyboardKey.keyC) return _clientsIndex;
    if (key == LogicalKeyboardKey.keyI) return _invoicesIndex;
    if (key == LogicalKeyboardKey.keyP) return _productsIndex;
    if (key == LogicalKeyboardKey.keyS) return _settingsIndex;
    if (key == LogicalKeyboardKey.keyT) return _tasksIndex;
    return null;
  }

  /// Leader-key key handler attached to the shell's focus node. Sees the
  /// raw event before the surrounding `Shortcuts` widget so `G` doesn't
  /// also feed back into a future single-letter activator if one is ever
  /// added.
  KeyEventResult _handleLeaderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final armed = _leaderTimer?.isActive ?? false;

    // Typing inside a text field always wins — the field types `g` etc. If the
    // leader was armed, the user has started typing instead of completing the
    // sequence, so cancel it now (don't leave `leaderModeArmed` set until the
    // timeout, which would keep single-key shortcuts stood down after they blur).
    if (isTextInputFocused()) {
      if (armed) _exitLeaderMode();
      return KeyEventResult.ignored;
    }

    // Modifier keys (Ctrl / Alt / Meta) suppress leader handling so
    // shortcuts like `⌘S` can pass through. Shift is allowed — capital
    // `G` is still semantically the letter `G`. A modifier combo mid-sequence
    // likewise abandons the leader, so cancel it rather than letting it linger.
    final hk = HardwareKeyboard.instance;
    if (hk.isControlPressed || hk.isAltPressed || hk.isMetaPressed) {
      if (armed) _exitLeaderMode();
      return KeyEventResult.ignored;
    }

    if (armed) {
      final index = _leaderTarget(event.logicalKey);
      _exitLeaderMode();
      if (index != null) {
        _goBranch(index);
        return KeyEventResult.handled;
      }
      // Invalid second key — silently cancel leader mode and let the
      // event bubble up so the user's normal binding (if any) runs.
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyG) {
      _enterLeaderMode();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// action id → the Intent to fire, handed to the controller's
  /// `activatorsFor`. Data only — the behavior lives in the Actions map below;
  /// built once. Create actions carry their entity type.
  static final Map<String, Intent> _globalIntents = <String, Intent>{
    ShortcutActionIds.openCompanyPicker: const _OpenCompanyPickerIntent(),
    ShortcutActionIds.openCommandPalette: const _OpenCommandPaletteIntent(),
    ShortcutActionIds.toggleSidebar: const _ToggleSidebarIntent(),
    ShortcutActionIds.openSettings: const _OpenSettingsIntent(),
    ShortcutActionIds.openKeyboardShortcuts:
        const _OpenKeyboardShortcutsIntent(),
    ShortcutActionIds.focusSearch: const _FocusSearchIntent(),
    for (final type in kCreateShortcutEntities)
      ShortcutActionIds.create(type): _CreateEntityIntent(type),
  };

  /// Non-remappable global combos merged in after the catalog map: browser
  /// history back/forward. macOS uses ⌘+Arrow, Windows/Linux Alt+Arrow;
  /// registering all four is harmless (a ⌘ combo won't fire on Windows and
  /// vice-versa). Kept out of the catalog because one binding can't express
  /// the per-OS modifier split.
  static const Map<ShortcutActivator, Intent>
  _fixedGlobalShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true): _GoBackIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _GoBackIntent(),
    SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
        _GoForwardIntent(),
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
        _GoForwardIntent(),
  };

  /// Navigate to an entity's create route (fired by a `create_<entity>`
  /// shortcut). No-op when the entity has no create route or its module is
  /// disabled for the active company (mirrors [_goBranch] — avoids the flash of
  /// a router redirect).
  Future<void> _createEntity(EntityType type) async {
    // A modal sheet lives in THIS navigator (`showModalBottomSheet` defaults to
    // `useRootNavigator: false`, and all but one call site takes that default),
    // so it sits inside this `Shortcuts` subtree and a bare-letter binding would
    // still fire — swapping the route out from under the open sheet. Dialogs
    // use the root navigator and are unaffected either way.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final services = context.read<Services>();
    final route = services.entityRegistry[type]?.newRoute;
    if (route == null || route.isEmpty) return;
    // Don't navigate into an entity whose module is disabled for the active
    // company (mirrors [_goBranch] — avoids the flash of a router redirect).
    final modules =
        services.auth.session.value?.currentCompany?.enabledModules ?? 0;
    if (!isEntityModuleEnabledForCompany(type, modules)) return;
    // Same guard every other shell-level navigation runs: leaving a dirty
    // editor must prompt, not silently discard. Async like [_goBranch], which
    // is likewise invoked fire-and-forget from a shortcut action.
    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) return;
    // `State.mounted` (not `context.mounted`) — `context` below is this
    // State's, and the analyzer only accepts the matching guard.
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    _maybeNotifyModuleDisabled(context);
    // Remappable global shortcuts come from the keyboard-shortcuts controller
    // (user override → catalog default); the map rebuilds only when a binding
    // changes. The browser-history ⌘/Alt+Arrow combos stay fixed — their
    // per-OS asymmetric modifier isn't expressible as one portable binding —
    // and the `G`+letter leader sequence is handled by the Focus below, not
    // here. Full model: `lib/app/shortcuts/`.
    final shortcutsController = context.read<Services>().keyboardShortcuts;
    return ListenableBuilder(
      listenable: shortcutsController,
      builder: (context, child) => Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          ...shortcutsController.activatorsFor(
            ShortcutScope.global,
            _globalIntents,
          ),
          ..._fixedGlobalShortcuts,
        },
        child: child!,
      ),
      // Built once — a binding change only re-wraps `Shortcuts`, never this
      // Actions/Focus subtree.
      child: Actions(
        actions: <Type, Action<Intent>>{
          // These four are now remappable (the recorder accepts bare keys), so
          // they use `GuardedShortcutAction` — same as `?`/`/` and the create
          // actions below. It disables the action (isEnabled + consumesKey)
          // while a text field is focused or the leader is armed, so a bare-key
          // rebind falls through to the field / leader handler instead of being
          // swallowed. A plain CallbackAction would consume the key even while
          // no-op'ing, making a rebound letter un-typeable app-wide.
          _OpenCompanyPickerIntent:
              GuardedShortcutAction<_OpenCompanyPickerIntent>(
                onInvoke: (_) {
                  showCompanyPicker(context);
                  return null;
                },
              ),
          _OpenCommandPaletteIntent:
              GuardedShortcutAction<_OpenCommandPaletteIntent>(
                onInvoke: (_) {
                  showCommandPalette(context);
                  return null;
                },
              ),
          // `?` and `/` are *unmodified* character activators — they
          // collide with typing in a field. Disable the action (via
          // `GuardedShortcutAction`, which overrides isEnabled +
          // consumesKey) while text input has focus so the keystroke
          // falls through to the field instead of being swallowed.
          _OpenKeyboardShortcutsIntent:
              GuardedShortcutAction<_OpenKeyboardShortcutsIntent>(
                onInvoke: (_) {
                  showKeyboardShortcutsDialog(context);
                  return null;
                },
              ),
          _FocusSearchIntent: GuardedShortcutAction<_FocusSearchIntent>(
            onInvoke: (_) {
              context.read<Services>().searchFocus.current?.requestFocus();
              return null;
            },
          ),
          _ToggleSidebarIntent: GuardedShortcutAction<_ToggleSidebarIntent>(
            onInvoke: (_) {
              context.read<Services>().sidebar.toggle();
              return null;
            },
          ),
          _OpenSettingsIntent: GuardedShortcutAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              final idx = _settingsIndex;
              if (idx != null) _goBranch(idx);
              return null;
            },
          ),
          _GoBackIntent: _TextFieldAwareAction<_GoBackIntent>(
            onInvoke: (_) {
              // Cmd/Alt+Arrow are caret/word motions inside a text field —
              // the action doesn't consume the key there (see
              // _TextFieldAwareAction), so the field handles the motion.
              if (isTextInputFocused()) return null;
              context.read<NavHistoryController>().back();
              return null;
            },
          ),
          _GoForwardIntent: _TextFieldAwareAction<_GoForwardIntent>(
            onInvoke: (_) {
              if (isTextInputFocused()) return null;
              context.read<NavHistoryController>().forward();
              return null;
            },
          ),
          // One shared action for every "create X" shortcut — the invoked
          // intent carries the entity type, resolved to its `/…/new` route.
          // `GuardedShortcutAction` stands the key down while a field is
          // focused (or a leader sequence is armed), so an unmodified-letter
          // binding still types normally in a text field.
          _CreateEntityIntent: GuardedShortcutAction<_CreateEntityIntent>(
            onInvoke: (intent) {
              unawaited(_createEntity(intent.type));
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleLeaderKey,
          child: MultiProvider(
            // Expose the shell so descendants (notably `AppDrawer` on each
            // top-level mobile screen) can call `goBranch` without
            // re-receiving it through a constructor chain — plus the shared
            // [BranchCompanyGate] so every branch-switch site applies the
            // same stale-company stack reset.
            providers: [
              Provider<StatefulNavigationShell>.value(
                value: widget.navigationShell,
              ),
              Provider<BranchCompanyGate>.value(value: _branchGate),
            ],
            child: SyncEventListener(
              // Mouse back/forward thumb buttons walk the same history as
              // Cmd/Alt+←/→ — exactly what a browser does with them.
              child: NavHistoryMouseListener(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (Breakpoints.isWide(constraints)) {
                      final services = context.read<Services>();
                      // Built once; passed through the ValueListenableBuilder's
                      // `child` so a collapse toggle re-runs only the Positioned
                      // wrapper (snapping the inset) and never rebuilds the page
                      // body / RunningTimerPill subtree.
                      final content = RepaintBoundary(
                        child: Column(
                          children: [
                            const OfflineBanner(),
                            Expanded(
                              child: Stack(
                                children: [
                                  widget.navigationShell,
                                  // Pinned bottom-right above the active route's
                                  // body. Hidden when no task is running — see
                                  // `RunningTimerPill`.
                                  const Positioned(
                                    right: 16,
                                    bottom: 16,
                                    child: RunningTimerPill(),
                                  ),
                                ],
                              ),
                            ),
                            _DebugPanelBand(),
                          ],
                        ),
                      );
                      return Scaffold(
                        body: Stack(
                          children: [
                            // Surface backstop behind the rail: during an
                            // expand the content inset has already snapped to
                            // 232 while the sidebar is still mid-grow, so this
                            // strip reads as sidebar chrome rather than blank
                            // page for the ≤150 ms tween.
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: kInSidebarWidth,
                              child: ColoredBox(color: context.inTheme.surface),
                            ),
                            // Content layer — its left inset SNAPS to the
                            // target rail width (one relayout per toggle, never
                            // per animation frame). The sidebar animates on top
                            // of it.
                            ValueListenableBuilder<bool>(
                              valueListenable: services.sidebar,
                              child: content,
                              builder: (context, collapsed, child) {
                                final targetWidth = collapsed
                                    ? kInSidebarCollapsedWidth
                                    : kInSidebarWidth;
                                return Positioned.fill(
                                  left: targetWidth,
                                  child: child!,
                                );
                              },
                            ),
                            // Sidebar layer — overlays the content; its own
                            // RepaintBoundary + AnimatedContainer run the
                            // 150 ms width tween in isolation.
                            //
                            // Intentionally no `width`/`right` on this
                            // Positioned: the child self-sizes to the
                            // *current* (animating) rail width via its
                            // non-null `AnimatedContainer.width`. A fixed
                            // width here would force-expand the rail (collapse
                            // can't shrink) and make the full 232 band hit-test
                            // as sidebar, swallowing content taps when
                            // collapsed. `InSidebar` here must keep a non-null
                            // `width` (defaults to `kInSidebarWidth`).
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: InSidebar(
                                currentBranch:
                                    widget.navigationShell.currentIndex,
                                onSelectBranch: _goBranch,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // Narrow: passthrough — each top-level screen renders its
                    // own Scaffold with `drawer: AppDrawer()` + a hamburger.
                    // No outer Scaffold avoids `Scaffold.of(context)` ambiguity.
                    // The banner stacks above the per-screen Scaffold here;
                    // `OfflineBanner` handles its own top inset when shown so
                    // it doesn't disappear behind the status bar / notch.
                    final services = context.read<Services>();
                    return Column(
                      children: [
                        // Desktop hidden-title-bar caption strip — macOS today. No
                        // sidebar in the narrow layout, so this top strip keeps the
                        // window controls from overlapping each screen's AppBar.
                        WindowCaptionStrip(
                          controller: services.screenshotWindow,
                        ),
                        const OfflineBanner(),
                        Expanded(
                          child: Stack(
                            children: [
                              widget.navigationShell,
                              // Narrow: pin above the bottom NavigationBar each
                              // screen owns + clear of the per-screen FAB
                              // (Material default bottom 16, FAB extends to ~72;
                              // bottom: 112 guarantees a 40px gap on shorter
                              // phones where the nav bar pushes the FAB up).
                              // The pill hides itself when no task is running,
                              // so it never obstructs empty space.
                              const Positioned(
                                right: 12,
                                bottom: 112,
                                child: RunningTimerPill(),
                              ),
                            ],
                          ),
                        ),
                        _DebugPanelBand(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenCompanyPickerIntent extends Intent {
  const _OpenCompanyPickerIntent();
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _OpenKeyboardShortcutsIntent extends Intent {
  const _OpenKeyboardShortcutsIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

/// A [CallbackAction] that does NOT consume the key when a text field is
/// focused. The history-nav shortcuts bind Cmd/Alt+Arrow — caret/word motions
/// inside a text field — so returning null from `onInvoke` isn't enough: the
/// shortcut still *consumes* the key, swallowing the motion. Overriding
/// `consumesKey` lets the event fall through to the field. (`onInvoke` still
/// fires but its own `isTextInputFocused()` guard no-ops it.)
class _TextFieldAwareAction<T extends Intent> extends CallbackAction<T> {
  _TextFieldAwareAction({required super.onInvoke});

  @override
  bool consumesKey(T intent) => !isTextInputFocused();
}

class _GoBackIntent extends Intent {
  const _GoBackIntent();
}

class _GoForwardIntent extends Intent {
  const _GoForwardIntent();
}

/// Fires the "create X" shortcut for [type]. One shared action resolves it to
/// the entity's `/…/new` route (see [_createEntity]); the [type] rides on the
/// intent so a single Actions entry covers every create shortcut.
class _CreateEntityIntent extends Intent {
  const _CreateEntityIntent(this.type);
  final EntityType type;
}

/// The hidden Debug Panel band, pinned at the bottom of the authenticated
/// shell. Listens to `Services.debugPanelRevealed` so once the user reveals
/// the panel (About dialog → "Debug Panel") it stays visible across
/// navigation between routes. Hidden = renders `SizedBox.shrink()`,
/// taking no layout space.
class _DebugPanelBand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return ValueListenableBuilder<bool>(
      valueListenable: services.debugPanelRevealed,
      builder: (context, revealed, _) {
        if (!revealed) return const SizedBox.shrink();
        // ~45 % of viewport, clamped so toolbar + tabs + a few rows always
        // fit on small windows and the panel never devours the whole screen
        // on tall ones. Matches what System Logs previously used. The bottom
        // safe-area inset rides on top: the panel's own SafeArea consumes it
        // on phones, so the clamped height stays all content.
        final h = MediaQuery.of(context).size.height;
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        return ListenableBuilder(
          listenable: services.screenshotWindow,
          child: SizedBox(
            height: (h * 0.45).clamp(320.0, 480.0) + bottomInset,
            child: DebugPanelSection(
              store: services.debugCaptureStore,
              windowController: services.screenshotWindow,
              onHide: () => services.debugPanelRevealed.value = false,
            ),
          ),
          // While a screenshot is being taken the band goes Offstage: it leaves
          // the layout (so the content above fills the window) and isn't painted
          // (so it's excluded from the capture), but stays mounted — the panel
          // keeps its tab / filter / scroll state across the shot.
          builder: (context, child) => Offstage(
            offstage: services.screenshotWindow.capturing,
            child: child,
          ),
        );
      },
    );
  }
}
