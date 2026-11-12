import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/domain/welcome.dart';
import 'package:admin/domain/welcome_content.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/haptics.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';
import 'package:admin/ui/features/feedback/contact_us_dialog.dart';

/// Below this width the Welcome is a bottom sheet; at or above, a dialog.
const double kWelcomeSheetBelow = 600;

/// How the Welcome was closed. Every deliberate close means "seen"; one
/// carrying an [action] also asks for it, done by [followWelcomeResult] once
/// the Welcome is gone. A `null` result instead of one of these is the
/// Welcome torn down under the user — a 401, the idle timeout — never a
/// choice of theirs.
@immutable
class WelcomeResult {
  const WelcomeResult([this.action]);

  final WelcomeAction? action;
}

/// The list the Welcome shows.
enum WelcomeList { getStarted, whatsChanged }

WelcomeList welcomeListFor(WelcomeKind kind) => kind == WelcomeKind.fromOldApp
    ? WelcomeList.whatsChanged
    : WelcomeList.getStarted;

/// Whether [action] leads somewhere this user may go — the sidebar's rules,
/// so a row never opens a screen they can't use.
bool welcomeActionReachable(AuthSession? session, WelcomeAction action) {
  final company = session?.currentCompany;
  return switch (action) {
    WelcomeRoute(:final module, :final permission, :final adminOnly) =>
      company != null &&
          (module == null || company.moduleEnabled(module)) &&
          (permission == null || company.can(permission)) &&
          (!adminOnly || company.isAdmin || company.isOwner),
    WelcomeMobileApp() =>
      currentMobilePromoTargets().isNotEmpty && mobilePromoEligible(session),
    WelcomePalette() || WelcomeContactUs() => true,
  };
}

/// Shows the Welcome on [kind]'s list.
///
/// A swipe down on the sheet pops it with no result, as a teardown does; it
/// is reported through [onSwipeClosed] so the caller can count it as read.
Future<WelcomeResult?> showWelcomeDialog(
  BuildContext context, {
  required WelcomeKind kind,
  VoidCallback? onSwipeClosed,
}) {
  final session = context.read<Services>().auth.session.value;
  final surfaces = currentReleaseNoteSurfaces();
  Widget card(bool sheet) => WelcomeCard(
    initialList: welcomeListFor(kind),
    session: session,
    surfaces: surfaces,
    reachable: (a) => welcomeActionReachable(session, a),
    asSheet: sheet,
    onSwipeClosed: onSwipeClosed,
  );
  // The device, not the window's width: a landscape phone is still a phone,
  // and a dialog there showed a row and a half.
  if (MediaQuery.sizeOf(context).shortestSide < kWelcomeSheetBelow) {
    return showModalBottomSheet<WelcomeResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // On touch a tap above the sheet closes it, as every sheet does, and
      // counts as read like a swipe (WelcomeCard counts both). A pointer's
      // stray click beside it is not an answer.
      isDismissible: Env.isTouchPrimary,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: context.inTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(InRadii.r4)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (_) => card(true),
    );
  }
  return showGeneralDialog<WelcomeResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: InMotion.of(context)(const Duration(milliseconds: 220)),
    pageBuilder: (_, _, _) => card(false),
    transitionBuilder: (context, animation, _, child) {
      final a = CurvedAnimation(
        parent: animation,
        curve: InMotion.out,
        reverseCurve: InMotion.in_,
      );
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(a),
          child: child,
        ),
      );
    },
  );
}

/// Whether About and the command palette offer the Welcome: a live session
/// that isn't the demo account's, with the controller in reach (a harness
/// has none).
bool welcomeAvailable(BuildContext context) {
  try {
    if (context.read<WelcomeController?>() == null) return false;
    final session = context.read<Services>().auth.session.value;
    return session != null && !session.isDemo;
  } catch (_) {
    return false;
  }
}

/// Opens the Welcome because the user asked (About, the command palette).
/// Reading it this way counts as reading it; a company whose setup
/// checklist was hidden gets it back while it is incomplete.
Future<void> openWelcomeOnRequest(BuildContext context) async {
  final controller = context.read<WelcomeController?>();
  final companyId =
      context.read<Services>().auth.session.value?.currentCompanyId ?? '';
  if (controller != null && companyId.isNotEmpty) {
    final c = controller.checklistFor(companyId);
    if (c != null && c.hidden && c.completedAt == null) {
      unawaited(controller.unhideChecklist(companyId));
    }
  }
  var swiped = false;
  final result = await showWelcomeDialog(
    context,
    kind: controller?.onRequestKind ?? WelcomeKind.existingAccount,
    onSwipeClosed: () => swiped = true,
  );
  if (result == null && !swiped) return;
  // Read on request is read: even one that stopped opening on its own (its
  // attempts spent) is settled, and the server told.
  if (controller != null && controller.currentPending) {
    await controller.markSeen();
  }
  if (context.mounted) await followWelcomeResult(context, result);
}

/// Does what the user picked on their way out. [context] must outlive the
/// Welcome — the shell host's, or About's outer one.
Future<void> followWelcomeResult(
  BuildContext context,
  WelcomeResult? result,
) async {
  if (!context.mounted) return;
  switch (result?.action) {
    case WelcomeRoute(:final path):
      // Leaves the current screen, so it owes the prompt the sidebar gives.
      final guard = context.read<Services>().unsavedChangesGuard;
      if (!await guard.confirmIfDirty(context)) return;
      if (!context.mounted) return;
      GoRouter.maybeOf(context)?.go(path);
    case WelcomePalette():
      await showCommandPalette(context);
    case WelcomeMobileApp():
      await showMobileAppPromoDialog(context, isManual: true);
    case WelcomeContactUs():
      await showContactUsDialog(context);
    case null:
      break;
  }
}

/// The Welcome's content, in a dialog or a sheet. Pumped directly by the
/// tests with each surface.
class WelcomeCard extends StatefulWidget {
  const WelcomeCard({
    super.key,
    required this.initialList,
    required this.session,
    required this.surfaces,
    required this.reachable,
    this.asSheet = false,
    this.onSwipeClosed,
  });

  /// A swipe down closed the sheet — deliberate, unlike a teardown, though
  /// both pop it with no result.
  final VoidCallback? onSwipeClosed;

  final WelcomeList initialList;
  final AuthSession? session;
  final Set<ReleaseNoteSurface> surfaces;
  final bool Function(WelcomeAction action) reachable;
  final bool asSheet;

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard> {
  /// A click or key press in the first half-second is ignored: the Welcome
  /// opens on its own, often under a pointer mid-click — and Let's go has
  /// the focus.
  static const Duration _armDelay = Duration(milliseconds: 500);

  late WelcomeList _list = widget.initialList;
  bool _cantFindOpen = false;
  bool _armed = false;
  bool _popping = false;
  Timer? _armTimer;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(_armDelay, () => _armed = true);
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  VoidCallback _guard(VoidCallback action) => () {
    if (_armed) action();
  };

  void _pop([WelcomeAction? action]) {
    _popping = true;
    Navigator.of(context).pop(WelcomeResult(action));
  }

  void _switchList() {
    unawaited(InHaptics.selection());
    setState(() {
      _list = _list == WelcomeList.getStarted
          ? WelcomeList.whatsChanged
          : WelcomeList.getStarted;
      _cantFindOpen = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool get _touch => Env.isTouchPrimary;

  /// Opens "Can't find something?" and, once it has grown, scrolls it into
  /// view — it opens below the fold on a phone, behind the footer.
  void _toggleCantFind() {
    final opening = !_cantFindOpen;
    setState(() => _cantFindOpen = opening);
    if (!opening) return;
    final motion = InMotion.of(context);
    // Two size animations run in turn — the panel's, then the list's around
    // it — so wait out both before measuring how far there is to go.
    Future<void>.delayed(
      motion(const Duration(milliseconds: 420)) +
          const Duration(milliseconds: 40),
      () {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: motion(InMotion.base),
          curve: InMotion.move,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    final narrow = MediaQuery.sizeOf(context).shortestSide < kWelcomeSheetBelow;
    final hPad = narrow ? InSpacing.lg(context) + 4 : InSpacing.xl;

    final items = visibleWelcomeItems(
      _list == WelcomeList.getStarted
          ? kWelcomeGetStarted
          : kWelcomeWhatsChanged,
      surfaces: widget.surfaces,
      reachable: widget.reachable,
      touch: _touch,
    );

    final body = SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsetsDirectional.fromSTEB(
        hPad,
        widget.asSheet ? 0 : InSpacing.xl,
        hPad,
        InSpacing.lg(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: InSpacing.xl),
          AnimatedSize(
            duration: motion(const Duration(milliseconds: 200)),
            curve: InMotion.out,
            alignment: AlignmentDirectional.topStart,
            child: AnimatedSwitcher(
              duration: motion(const Duration(milliseconds: 200)),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topStart,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(_list),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_list == WelcomeList.whatsChanged) ...[
                    _DataCallout(session: widget.session),
                    SizedBox(height: InSpacing.lg(context)),
                  ],
                  for (final item in items) _row(context, item),
                  if (_list == WelcomeList.whatsChanged) _cantFind(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final switchLink = TextButton(
      key: const ValueKey('welcome_switch_list'),
      onPressed: _guard(_switchList),
      child: Text(
        context.tr(
          _list == WelcomeList.getStarted
              ? 'welcome_see_whats_changed'
              : 'welcome_see_basics',
        ),
        textAlign: TextAlign.center,
      ),
    );
    // Autofocused on every device: a touch tablet with a keyboard must still
    // reach the card's Esc and Enter (the route's own Esc is off while the
    // barrier isn't dismissible). The half-second guard keeps a key already
    // in flight from closing it unread, and on touch no focus ring shows.
    final letsGo = PrimaryDialogAction(
      buttonKey: const ValueKey('welcome_lets_go'),
      label: context.tr('welcome_lets_go'),
      onPressed: _guard(_pop),
      // The ↵ hint is for a keyboard; on touch it would name a key nobody has.
      showEnterHint: !_touch,
    );

    final footer = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        hPad,
        InSpacing.md(context),
        hPad,
        InSpacing.md(context),
      ),
      // A phone: the link above, a full-width Let's go below — the primary
      // never ends up bottom-start under a text link. Wider: the link at the
      // start, Let's go at the end, wrapping only at a large text size.
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                switchLink,
                const SizedBox(height: InSpacing.xs),
                letsGo,
              ],
            )
          : OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: InSpacing.sm,
              children: [switchLink, letsGo],
            ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: body),
        Divider(height: 1, color: tokens.border),
        SafeArea(top: false, child: footer),
      ],
    );

    // Esc, and a swipe down on the sheet: both are the user closing it, so
    // both count as seen. The route's own Esc is off while the barrier isn't
    // dismissible, so the card brings its own — guarded like every way out.
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null && !_popping && mounted) {
          // A drag dismissed the sheet; tell the host it was deliberate.
          widget.onSwipeClosed?.call();
        }
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _guard(_pop)();
              return null;
            },
          ),
        },
        child: widget.asSheet
            ? content
            : Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 16 : 40,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Material(
                      color: tokens.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(InRadii.r3),
                      ),
                      elevation: 8,
                      child: PrimaryScrollController(
                        controller: _scroll,
                        automaticallyInheritForPlatforms: TargetPlatform.values
                            .toSet(),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final tokens = context.inTheme;
    final first = widget.session?.userFirstName.trim() ?? '';
    final title = first.isEmpty
        ? context.tr('welcome_new_app_title_plain')
        : context.tr('welcome_new_app_title', {'name': first});
    // At a large text size the icon gives its width back to the title,
    // which would otherwise run four lines between it and the ✕.
    final showIcon = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIcon) ...[
          Container(
            // The black app icon all but vanishes on a dark sheet; a ring
            // gives it an edge.
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: dark ? Border.all(color: tokens.borderStrong) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(InRadii.r2),
              child: Image.asset(
                'assets/images/icon.png',
                width: 40,
                height: 40,
                excludeFromSemantics: true,
              ),
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                headingLevel: 1,
                namesRoute: true,
                child: Text(
                  title,
                  // A display heading scales less than body text.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.5),
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
              ),
              const SizedBox(height: InSpacing.xs + 2),
              Text(
                context.tr('welcome_subtitle'),
                style: TextStyle(fontSize: 14, height: 1.4, color: tokens.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(width: InSpacing.sm),
        IconButton(
          key: const ValueKey('welcome_close'),
          // The desktop theme is compact, which would take the 44 down to 36
          // (docs/touch-targets.md, trap 2).
          visualDensity: VisualDensity.standard,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(InSizes.touchTarget),
          ),
          tooltip: context.tr('close'),
          icon: Icon(Icons.close, color: tokens.ink3),
          onPressed: _guard(_pop),
        ),
      ],
    );
  }

  String? _body(BuildContext context, WelcomeItem item) {
    final key = _touch && item.touchBodyKey != null
        ? item.touchBodyKey
        : item.bodyKey;
    return key == null ? null : context.tr(key);
  }

  String _title(BuildContext context, WelcomeItem item) {
    final template = item.titleTemplateKey;
    if (template != null) {
      return context.tr(template, {
        for (final e in item.titleArgs.entries) e.key: context.tr(e.value),
      });
    }
    // A row with no body of its own on touch takes the touch line as its
    // title (the "Can't find something?" search line).
    if (_touch && item.bodyKey == null && item.touchBodyKey != null) {
      return context.tr(item.touchBodyKey!);
    }
    return context.tr(item.titleKey);
  }

  Widget _row(BuildContext context, WelcomeItem item) {
    final action = item.action;
    return _WelcomeRow(
      key: ValueKey('welcome_item_${item.id}'),
      icon: item.icon,
      title: _title(context, item),
      body: _body(context, item),
      keys: item.showsPaletteKeys && !_touch ? const _PaletteKeys() : null,
      navigates: action is WelcomeRoute,
      onTap: action == null ? null : _guard(() => _pop(action)),
    );
  }

  Widget _cantFind(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    final items = visibleWelcomeItems(
      kWelcomeCantFind,
      surfaces: widget.surfaces,
      reachable: widget.reachable,
      touch: _touch,
      limit: null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: InSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            button: true,
            expanded: _cantFindOpen,
            child: TextButton.icon(
              key: const ValueKey('welcome_cant_find'),
              onPressed: _toggleCantFind,
              iconAlignment: IconAlignment.end,
              icon: Icon(_cantFindOpen ? Icons.expand_less : Icons.expand_more),
              label: Text(context.tr('welcome_cant_find')),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion(const Duration(milliseconds: 200)),
          curve: InMotion.out,
          alignment: AlignmentDirectional.topStart,
          child: _cantFindOpen
              ? Container(
                  margin: const EdgeInsets.only(top: InSpacing.xs),
                  padding: const EdgeInsets.all(InSpacing.xs),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(InRadii.r2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items)
                        _WelcomeRow(
                          key: ValueKey('welcome_cant_find_${item.id}'),
                          icon: item.icon,
                          title: _title(context, item),
                          compact: true,
                          keys: item.showsPaletteKeys && !_touch
                              ? const _PaletteKeys()
                              : null,
                          navigates: item.action is WelcomeRoute,
                          onTap: item.action == null
                              ? null
                              : _guard(() => _pop(item.action)),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// "All your data is already here" — the old-app user's real question,
/// answered first. While a sync pass runs it says how far along it is, so
/// "already here" beside a list still filling in is not a lie.
class _DataCallout extends StatelessWidget {
  const _DataCallout({required this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    final selfHosted = session?.isSelfHosted ?? false;
    ResyncController? resync;
    try {
      resync = context.read<Services>().resync;
    } catch (_) {
      resync = null;
    }
    final companyId = session?.currentCompanyId ?? '';
    Widget status(ResyncProgress? p) {
      final running = p != null && p.isRunningFor(companyId);
      return AnimatedSwitcher(
        duration: motion(const Duration(milliseconds: 200)),
        child: running
            ? Row(
                key: const ValueKey('syncing'),
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: tokens.accentInk,
                    ),
                  ),
                  const SizedBox(width: InSpacing.sm),
                  Flexible(
                    child: Text(
                      p.total > 0
                          ? context.tr('syncing_progress', {
                              'count': '${p.completed}',
                              'total': '${p.total}',
                            })
                          : context.tr('syncing'),
                      style: TextStyle(fontSize: 12, color: tokens.accentInk),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(key: ValueKey('idle')),
      );
    }

    return Container(
      key: const ValueKey('welcome_data_callout'),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, size: 22, color: tokens.accentInk),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  headingLevel: 2,
                  child: Text(
                    context.tr('welcome_data_title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    selfHosted
                        ? 'welcome_data_body_self_hosted'
                        : 'welcome_data_body',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: tokens.ink2,
                  ),
                ),
                // Only an app can sit beside the previous one; the web has
                // nothing installed to keep.
                if (!kIsWeb) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.tr('welcome_keep_old_app'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: tokens.ink2,
                    ),
                  ),
                ],
                if (resync != null) ...[
                  const SizedBox(height: 6),
                  ValueListenableBuilder<ResyncProgress>(
                    valueListenable: resync,
                    builder: (context, p, _) => status(p),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The command palette's live shortcut, one cap per key — read from the
/// user's own bindings, so a rebound shortcut shows what they set, and an
/// unbound one shows nothing. Never ⌘K: that is Switch company.
class _PaletteKeys extends StatelessWidget {
  const _PaletteKeys();

  @override
  Widget build(BuildContext context) {
    KeyboardShortcutsController? shortcuts;
    try {
      shortcuts = context.read<Services>().keyboardShortcuts;
    } catch (_) {
      shortcuts = null;
    }
    if (shortcuts == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: shortcuts,
      builder: (context, _) {
        final binding = shortcuts!.resolvedBinding(
          ShortcutActionIds.openCommandPalette,
        );
        if (binding == null) return const SizedBox.shrink();
        return KeyCapRow(
          keys: binding.displayGlyphs(platformModifierLabel()),
          dense: true,
        );
      },
    );
  }
}

class _WelcomeRow extends StatelessWidget {
  const _WelcomeRow({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.keys,
    this.onTap,
    this.compact = false,
    this.navigates = true,
  });

  /// The row leads to a screen (a link); otherwise it opens a dialog or the
  /// palette over this one (a button).
  final bool navigates;
  final IconData icon;
  final String title;
  final String? body;
  final Widget? keys;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tap = onTap;
    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 6 : InSpacing.sm),
        child: Row(
          crossAxisAlignment: body == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 28 : 36,
              height: compact ? 28 : 36,
              decoration: BoxDecoration(
                color: compact ? tokens.surface : tokens.accentSoft,
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
              child: Icon(
                icon,
                size: compact ? 16 : 20,
                color: compact ? tokens.ink3 : tokens.accentInk,
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      height: 1.35,
                      fontWeight: compact ? FontWeight.w500 : FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      body!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: tokens.ink3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (keys != null) ...[
              const SizedBox(width: InSpacing.sm),
              ExcludeSemantics(child: keys!),
            ],
            if (tap != null) ...[
              const SizedBox(width: InSpacing.sm),
              Icon(Icons.chevron_right, size: 20, color: tokens.ink3),
            ],
          ],
        ),
      ),
    );
    if (tap == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: InSpacing.xs),
        child: MergeSemantics(child: row),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: InSpacing.xs),
      child: MergeSemantics(
        child: Semantics(
          // The whole row is the one destination (no name link inside it).
          link: navigates && onTap != null,
          button: !navigates && onTap != null,
          // A local Material, never `Ink` (docs/sidebar-and-shell.md).
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(InRadii.r2),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}
