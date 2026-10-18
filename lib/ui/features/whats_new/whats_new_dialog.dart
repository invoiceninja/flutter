import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/feature_row.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';
import 'package:admin/ui/features/shell/widgets/contact_us_dialog.dart';

/// How the dialog was closed. Every close means "seen"; the last three also
/// ask for something, done by [followWhatsNewResult] once the dialog is gone.
sealed class WhatsNewResult {
  const WhatsNewResult();
}

/// Got it, ✕ or Esc.
final class WhatsNewClosed extends WhatsNewResult {
  const WhatsNewClosed();
}

/// A highlight that leads to a screen.
final class WhatsNewOpenRoute extends WhatsNewResult {
  const WhatsNewOpenRoute(this.path);

  final String path;
}

/// The phone-app highlight.
final class WhatsNewOpenMobileApp extends WhatsNewResult {
  const WhatsNewOpenMobileApp();
}

/// Feedback.
final class WhatsNewFeedback extends WhatsNewResult {
  const WhatsNewFeedback();
}

/// Shows [releases] (newest first — docs/whats-new-dialog.md). [since] is
/// the version the user updated from, for a catch-up across several
/// releases. A `null` result is the dialog torn down under the user — a 401,
/// the idle timeout — never a choice of theirs.
Future<WhatsNewResult?> showWhatsNewDialog(
  BuildContext context, {
  required List<ReleaseNotes> releases,
  String? since,
}) {
  final session = context.read<Services>().auth.session.value;
  final company = session?.currentCompany;
  // The rules the sidebar applies to the same rows, so a highlight never
  // leads somewhere this user can't open.
  bool reachable(ReleaseHighlightTarget target) => switch (target) {
    ReleaseHighlightRoute(:final module, :final permission) =>
      company != null &&
          (module == null || company.moduleEnabled(module)) &&
          (permission == null || company.can(permission)),
    ReleaseHighlightMobileApp() =>
      currentMobilePromoTargets().isNotEmpty && mobilePromoEligible(session),
  };
  return showDialog<WhatsNewResult>(
    context: context,
    // A stray click beside the card isn't an answer; ✕, Esc and the footer
    // are — the same as the mobile-app promo.
    barrierDismissible: false,
    builder: (_) =>
        WhatsNewDialog(releases: releases, since: since, reachable: reachable),
  );
}

/// The notes About and the command palette open — the update's when one is
/// waiting, else this build's release. Null when there are none, or no
/// controller (a harness).
List<ReleaseNotes>? whatsNewOnRequest(BuildContext context) {
  final releases = context.read<WhatsNewController?>()?.onRequest;
  return releases == null || releases.isEmpty ? null : releases;
}

/// Opens the notes because the user asked. Reading an update's notes this
/// way is reading them: they won't open again on their own, and the
/// mobile-app promo keeps its day's distance (docs/whats-new-dialog.md).
Future<void> openWhatsNewOnRequest(BuildContext context) async {
  final controller = context.read<WhatsNewController?>();
  final releases = whatsNewOnRequest(context);
  if (controller == null || releases == null) return;
  final wasPending = controller.pending.isNotEmpty;
  if (wasPending) unawaited(controller.noteOpened(DateTime.now()));
  final result = await showWhatsNewDialog(
    context,
    releases: releases,
    since: wasPending ? controller.state.seenVersion : null,
  );
  if (result == null) return;
  if (wasPending) await controller.markSeen();
  if (context.mounted) await followWhatsNewResult(context, result);
}

/// Does what the user picked on their way out. [context] must outlive the
/// dialog — the shell host's, or About's outer one.
Future<void> followWhatsNewResult(
  BuildContext context,
  WhatsNewResult? result,
) async {
  if (!context.mounted) return;
  switch (result) {
    case WhatsNewOpenRoute(:final path):
      // Leaves the current screen, so it owes the prompt the sidebar gives —
      // About and the palette open over any screen, a dirty editor included.
      final guard = context.read<Services>().unsavedChangesGuard;
      if (!await guard.confirmIfDirty(context)) return;
      if (!context.mounted) return;
      GoRouter.maybeOf(context)?.go(path);
    case WhatsNewOpenMobileApp():
      await showMobileAppPromoDialog(context, isManual: true);
    case WhatsNewFeedback():
      await showContactUsDialog(context);
    case WhatsNewClosed() || null:
      break;
  }
}

/// The dialog. Pumped directly by the tests with each surface's releases —
/// the store filter is applied before it is built (`releasesToShow`).
class WhatsNewDialog extends StatefulWidget {
  const WhatsNewDialog({
    required this.releases,
    required this.reachable,
    this.since,
    super.key,
  }) : assert(releases.length > 0);

  final List<ReleaseNotes> releases;
  final String? since;

  /// Whether a highlight's target is open to this user; a highlight that
  /// isn't is left out.
  final bool Function(ReleaseHighlightTarget target) reachable;

  @override
  State<WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<WhatsNewDialog> {
  /// How long a click or a key press is ignored after the card appears. It
  /// opens on its own, often under a pointer mid-click or a finger on Enter
  /// — and Got it has the focus.
  static const Duration _armDelay = Duration(milliseconds: 500);

  final _scroll = ScrollController();
  final _toggleKey = GlobalKey();
  late final List<ReleaseHighlight> _highlights = [
    for (final release in widget.releases)
      for (final h in release.highlights)
        if (h.target == null || widget.reachable(h.target!)) h,
  ].take(kMaxReleaseHighlights).toList();

  /// The full list starts open when there is nothing to lead with.
  late bool _expanded = _highlights.isEmpty;

  /// Releases whose list is open; only the newest at first.
  late final Set<String> _openReleases = {widget.releases.first.version};

  bool _armed = false;
  bool _overflows = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(_armDelay, () => _armed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Wraps every way out so it does nothing until the card is armed. The
  /// buttons stay enabled — greying them out for half a second would read as
  /// a glitch.
  VoidCallback _guard(VoidCallback action) => () {
    if (_armed) action();
  };

  void _pop(WhatsNewResult result) => Navigator.of(context).pop(result);

  WhatsNewResult _resultFor(ReleaseHighlightTarget target) => switch (target) {
    ReleaseHighlightRoute(:final path) => WhatsNewOpenRoute(path),
    ReleaseHighlightMobileApp() => const WhatsNewOpenMobileApp(),
  };

  /// The divider above the footer marks a body that scrolls under it.
  void _measure() {
    if (!mounted || !_scroll.hasClients) return;
    final overflows = _scroll.position.maxScrollExtent > 0;
    if (overflows != _overflows) setState(() => _overflows = overflows);
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    // With animations off nothing grows, so there is no end to wait for.
    if (_expanded && _animation(context) == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  /// Bring the toggle to the top, the list under it, once the list has its
  /// full height — before that, the scroll view has nowhere to go.
  void _reveal() {
    final target = _toggleKey.currentContext;
    if (!_expanded || target == null || !target.mounted) return;
    Scrollable.ensureVisible(
      target,
      duration: _animation(context),
      curve: Curves.easeOut,
    );
  }

  Duration _animation(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200);

  int get _itemCount => widget.releases.fold(0, (n, r) => n + r.items.length);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tokens = context.inTheme;
    final body = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return false;
      },
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: Env.isDesktop && _overflows,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsetsDirectional.fromSTEB(
            InSpacing.xl,
            InSpacing.xl,
            InSpacing.xl,
            InSpacing.lg(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              if (_highlights.isNotEmpty) ...[
                const SizedBox(height: InSpacing.xl),
                for (final h in _highlights)
                  FeatureRow(
                    icon: h.icon,
                    title: h.title,
                    body: h.body,
                    inset: true,
                    onTap: switch (h.target) {
                      final target? => _guard(() => _pop(_resultFor(target))),
                      null => null,
                    },
                  ),
                SizedBox(height: InSpacing.md(context)),
                _toggleButton(context),
              ] else
                SizedBox(height: InSpacing.lg(context)),
              AnimatedSize(
                duration: _animation(context),
                curve: Curves.easeOut,
                alignment: AlignmentDirectional.topStart,
                onEnd: _reveal,
                child: _expanded
                    ? _fullList(context)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: body),
        if (_overflows) Divider(height: 1, color: tokens.border),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.xl,
            vertical: InSpacing.md(context),
          ),
          child: _footer(context),
        ),
      ],
    );
    // Esc. The route's own handler is off whenever the barrier isn't
    // dismissible (`_DismissModalAction.isEnabled`), so the card brings its
    // own — guarded like every other way out.
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _guard(() => _pop(const WhatsNewClosed()))();
            return null;
          },
        ),
      },
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 600 ? 16 : 40,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          // Page Up / Page Down scroll the notes while Got it holds the
          // focus — it sits outside the scroll view, so the scroll action
          // finds the notes through this controller.
          child: PrimaryScrollController(
            controller: _scroll,
            automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
            child: content,
          ),
        ),
      ),
    );
  }

  /// The title, and the ✕ beside it. The ✕ scrolls away with the title
  /// rather than floating over the notes — pinned, it sat on the first
  /// highlight's chevron on a phone — and Got it, in the pinned footer, is
  /// always on screen.
  Widget _header(BuildContext context) {
    final tokens = context.inTheme;
    final since = widget.since;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                headingLevel: 1,
                namesRoute: true,
                child: Text(
                  context.tr('whats_new_in_version', {
                    'version': widget.releases.first.version,
                  }),
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
                widget.releases.length > 1 && since != null
                    ? context.tr('whats_new_since_version', {'version': since})
                    : context.tr('welcome_to_the_new_version'),
                style: TextStyle(fontSize: 14, height: 1.4, color: tokens.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(width: InSpacing.sm),
        IconButton(
          // The desktop theme is compact, which would take the 44 down to
          // 36 (docs/touch-targets.md, trap 2).
          visualDensity: VisualDensity.standard,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(InSizes.touchTarget),
          ),
          tooltip: context.tr('close'),
          icon: Icon(Icons.close, color: tokens.ink3),
          onPressed: _guard(() => _pop(const WhatsNewClosed())),
        ),
      ],
    );
  }

  Widget _toggleButton(BuildContext context) => Semantics(
    key: _toggleKey,
    button: true,
    expanded: _expanded,
    child: TextButton.icon(
      onPressed: _toggle,
      iconAlignment: IconAlignment.end,
      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
      label: Text(
        _expanded
            ? context.tr('show_fewer_changes')
            : context.tr('see_all_changes', {'count': '$_itemCount'}),
      ),
    ),
  );

  Widget _fullList(BuildContext context) {
    final many = widget.releases.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final release in widget.releases) ...[
          if (many) _releaseHeader(context, release),
          if (!many || _openReleases.contains(release.version))
            _releaseItems(context, release),
        ],
      ],
    );
  }

  /// One release in a catch-up: its version, and — collapsed — how many
  /// changes it holds.
  Widget _releaseHeader(BuildContext context, ReleaseNotes release) {
    final tokens = context.inTheme;
    final open = _openReleases.contains(release.version);
    final n = release.items.length;
    final count = n == 1
        ? context.tr('release_change_count_one')
        : context.tr('release_changes_count', {'count': '$n'});
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r2),
        onTap: () => setState(() {
          if (!_openReleases.remove(release.version)) {
            _openReleases.add(release.version);
          }
        }),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 36,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  open ? 'v${release.version}' : 'v${release.version} · $count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                color: tokens.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _releaseItems(BuildContext context, ReleaseNotes release) {
    final groups = <ReleaseNoteKind, List<ReleaseNoteItem>>{};
    for (final item in release.items) {
      if (item.kind case final kind?) {
        (groups[kind] ??= []).add(item);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in ReleaseNoteKind.values)
          if (groups[kind] case final items?) ...[
            _kindHeading(context, kind),
            for (final item in items) _bullet(context, item.displayText),
          ],
      ],
    );
  }

  Widget _kindHeading(BuildContext context, ReleaseNoteKind kind) => Padding(
    padding: EdgeInsetsDirectional.only(
      top: InSpacing.lg(context),
      bottom: InSpacing.sm,
    ),
    child: Semantics(
      header: true,
      headingLevel: 2,
      child: Text(
        context.tr(switch (kind) {
          ReleaseNoteKind.added => 'release_notes_added',
          ReleaseNoteKind.updated => 'release_notes_updated',
          ReleaseNoteKind.fixed => 'release_notes_fixed',
        }).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
          color: context.inTheme.ink3,
        ),
      ),
    ),
  );

  Widget _bullet(BuildContext context, String text) {
    final tokens = context.inTheme;
    final style = TextStyle(fontSize: 14, height: 1.45, color: tokens.ink2);
    return Padding(
      padding: const EdgeInsets.only(bottom: InSpacing.sm),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text('•', style: style.copyWith(color: tokens.ink3)),
            ),
            const SizedBox(width: InSpacing.sm),
            Expanded(child: Text(text, style: style)),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final tokens = context.inTheme;
    // Got it keeps its width; Feedback gives way — down to its icon, on a
    // phone at a large text size — so the two stay side by side.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: tokens.ink3),
            onPressed: _guard(() => _pop(const WhatsNewFeedback())),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(
              context.tr('feedback'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        PrimaryDialogAction(
          label: context.tr('got_it'),
          onPressed: _guard(() => _pop(const WhatsNewClosed())),
        ),
      ],
    );
  }
}
