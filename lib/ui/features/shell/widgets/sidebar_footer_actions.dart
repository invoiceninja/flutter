import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/features/shell/widgets/about_dialog.dart';
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/contact_us_dialog.dart';
import 'package:admin/ui/features/shell/widgets/show_theme_menu.dart';

const String _kForumUrl = 'https://forum.invoiceninja.com';
const String _kDocsBaseUrl = 'https://invoiceninja.github.io/en';

/// Bottom row pinned to the sidebar: Contact Us, Support Forum, User Guide,
/// About, a theme switcher — and, on the wide layout, the collapse toggle
/// pinned right with a vertical divider between the two groups. When the wide
/// sidebar is collapsed to a 64-px rail (`compact: true`), only the toggle
/// remains; the action icons hide entirely.
///
/// The row is **five actions, or six**: the single-company mobile drawer drops
/// the sidebar header entirely (issue #104) and passes its company switcher in
/// as [leading], which is what keeps `CompanyPicker` — and with it the app's
/// only "New company" entry — reachable.
///
/// Six `Expanded` actions land on **43.83 px** in the 280-px drawer, a rounding
/// error under the 44-px touch floor. The drawer's *content* box is 279, not
/// 280: `InSidebar`'s `AnimatedContainer` carries a `Border(right:)` whose 1 px
/// folds into the container's own padding, inside the width constraint. (The
/// rail escapes that — its `OverflowBox` re-pins the content to exactly 232 —
/// which is why only the drawer figures move.) So 263 / 6 = 43.83. Note the
/// widget test pumps into a bare `SizedBox(width: 280)` and therefore measures
/// 44.0; the gap is called out in its `reason:`.
///
/// A seventh action would take that to 37.6, and this is also why there is
/// deliberately **no divider** between the company action and the five help
/// icons the way the rail has one before its collapse toggle: a 1-px rule plus
/// its 8 px of padding takes every action to 42.3. The avatar separates itself
/// well enough — a tinted rounded square (or an uploaded logo) among grey
/// 18-px line glyphs.
///
/// Visual language matches `SidebarNavItem` — `InkWell` + `Padding` over
/// `tokens.ink3` icons rather than the default Material `IconButton` ripple,
/// which doesn't appear anywhere else in the rail.
///
/// Wrapped in `SafeArea(top: false)` so the row clears the iPhone home
/// indicator / Android gesture bar on the drawer; the safe-area inset is
/// zero on the persistent desktop rail.
class SidebarFooterActions extends StatelessWidget {
  const SidebarFooterActions({
    this.compact = false,
    this.showCollapseToggle = false,
    this.touch = false,
    this.leading,
    super.key,
  });

  /// Hides the help/info actions (and [leading]) when true — only the collapse
  /// toggle remains, and only if [showCollapseToggle] is also true.
  final bool compact;

  /// Whether the collapse toggle is part of this row. False inside `AppDrawer`,
  /// which can't collapse; true on the persistent wide rail.
  final bool showCollapseToggle;

  /// Grows every action to [InSizes.touchTarget] tall. Set from
  /// `Env.isTouchPrimary` by `InSidebar`; see issue #11.
  final bool touch;

  /// Extra action mounted ahead of the help/info icons. Only the
  /// single-company mobile drawer passes one — a [SidebarCompanyFooterAction]
  /// standing in for the header row it no longer renders (issue #104). Null on
  /// the persistent rail, which keeps its header and has no room for a sixth
  /// icon beside the divider and collapse toggle.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final actions = <Widget>[
      if (leading != null) leading!,
      _FooterAction(
        icon: Icons.mail_outline,
        tooltipKey: 'contact_us',
        touch: touch,
        onTap: () => showContactUsDialog(context),
      ),
      _FooterAction(
        icon: Icons.forum_outlined,
        tooltipKey: 'support_forum',
        touch: touch,
        onTap: () => _openExternal(context, _kForumUrl),
      ),
      _FooterAction(
        icon: Icons.help_outline,
        tooltipKey: 'user_guide',
        touch: touch,
        onTap: () => _openExternal(
          context,
          userGuideUrl(GoRouterState.of(context).matchedLocation),
        ),
      ),
      _FooterAction(
        icon: Icons.info_outline,
        tooltipKey: 'about',
        touch: touch,
        onTap: () => showAppAboutDialog(context),
      ),
      _ThemeFooterAction(touch: touch),
    ];

    // On touch each action claims an equal share of the row instead of sitting
    // at its intrinsic 30 px with `spaceEvenly` gaps around it — a near-miss
    // then lands on a neighbour rather than on dead space. It also keeps the
    // row from overflowing: fixed 44-wide actions would need
    // 5×44 + 9 (divider) + 44 (toggle) = 273 px, but the expanded rail only
    // offers 232 − 16 = 216. `Expanded` shares out whatever is there (52.6 px
    // each in the drawer with five actions, 43.8 with the company action's
    // six, 32.6 each on the rail).
    List<Widget> shareWidth(List<Widget> items) =>
        touch ? [for (final a in items) Expanded(child: a)] : items;

    final Widget body;
    if (showCollapseToggle && compact) {
      // Collapsed wide rail: only the expand toggle, pinned right so it
      // slides smoothly from its expanded-state position (rightmost child
      // of the footer Row) rather than jumping inward at toggle-time.
      body = Align(
        alignment: Alignment.centerRight,
        child: _CollapseToggleButton(collapsed: true, touch: touch),
      );
    } else if (showCollapseToggle) {
      // Expanded wide rail: the actions, a vertical divider, collapse toggle.
      body = Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: shareWidth(actions),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(width: 1, height: 24, color: tokens.border),
          ),
          _CollapseToggleButton(collapsed: false, touch: touch),
        ],
      );
    } else {
      // Drawer: the actions, no toggle. Five of them, or six when the
      // single-company layout hands over its company switcher as [leading].
      body = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: shareWidth(actions),
      );
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: body,
      ),
    );
  }
}

/// Flips `Services.sidebar` between collapsed and expanded. Shares the
/// footer row with the help/info actions when expanded; sits alone when
/// the rail is collapsed.
class _CollapseToggleButton extends StatelessWidget {
  const _CollapseToggleButton({required this.collapsed, this.touch = false});

  final bool collapsed;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      message: context.tr(collapsed ? 'show_sidebar' : 'hide_sidebar'),
      waitDuration: const Duration(milliseconds: 600),
      child: IconButton(
        // The theme sets `IconButton.minimumSize = Size.fromHeight(44)` via
        // the surrounding button defaults; without these overrides the
        // toggle balloons inside this tight footer. 44 on touch still fits the
        // collapsed 64-px rail (64 − 16 padding = 48). This goes through
        // `ButtonStyle`, not `IconButton.constraints`, so the density
        // adjustment that shrinks an explicit `constraints` box doesn't apply.
        style: IconButton.styleFrom(
          minimumSize: touch
              ? const Size(InSizes.touchTarget, InSizes.touchTarget)
              : const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          collapsed ? Icons.chevron_right : Icons.chevron_left,
          size: 18,
          color: tokens.ink3,
        ),
        onPressed: () => context.read<Services>().sidebar.toggle(),
      ),
    );
  }
}

/// Pure-function URL mapping: matched route → docs sub-path. Extracted so the
/// table can be unit-tested without pumping a widget tree.
@visibleForTesting
String userGuideUrl(String location) {
  if (location.startsWith('/clients')) return '$_kDocsBaseUrl/clients';
  if (location.startsWith('/dashboard')) return '$_kDocsBaseUrl/user-guide';
  if (location.startsWith('/settings/company_details')) {
    return '$_kDocsBaseUrl/basic-settings';
  }
  if (location.startsWith('/settings')) {
    return '$_kDocsBaseUrl/advanced-settings';
  }
  // The docs site has no page at the bare `/en` base — it 404s. Every route
  // without a specific mapping (Invoices, Products, Tasks, Reports, …) reaches
  // this line, so returning the base sent most of the app to a "page not
  // found". `/user-guide` is the docs landing page and is what Dashboard
  // already uses. Found while fixing issue #12: once the Android launch bug was
  // fixed, this was the next thing standing between the button and a useful page.
  return '$_kDocsBaseUrl/user-guide';
}

Future<void> _openExternal(BuildContext context, String url) async {
  // Capture the messenger + localized string pre-await so the error toast
  // survives any context disposal (e.g. drawer pop) during the launch handshake.
  await openExternalUrl(context, url);
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.tooltipKey,
    required this.onTap,
    this.touch = false,
  });

  final IconData icon;
  final String tooltipKey;
  final VoidCallback onTap;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      message: context.tr(tooltipKey),
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: _footerActionBody(
            glyph: Icon(icon, size: 18, color: tokens.ink3),
            touch: touch,
          ),
        ),
      ),
    );
  }
}

/// Shared inner body for the footer's icon actions.
///
/// On touch the slot's width is tight (the caller wraps each action in an
/// `Expanded`), so the icon has to be explicitly centred — a bare `Padding`
/// would pin it to the left edge of its share of the row. `SizedBox` is safe
/// for the height here because it wraps an `Icon`, not text: there is no line
/// box to clamp, unlike `SidebarNavItem`, which must use a minimum.
Widget _footerActionBody({required Widget glyph, required bool touch}) {
  if (touch) {
    return SizedBox(
      height: InSizes.touchTarget,
      child: Center(child: glyph),
    );
  }
  return Padding(
    // 6, not 8: with the fifth (theme) action the expanded 232-px rail
    // would otherwise sit flush against the divider + collapse toggle
    // with no inter-icon breathing room.
    padding: const EdgeInsets.all(6),
    child: glyph,
  );
}

/// The company switcher, shaped as a footer action.
///
/// Mounted as [SidebarFooterActions.leading] by the single-company mobile
/// drawer, which drops the sidebar header row to give the nav list ~60 px back
/// (issue #104). It is not decoration: `CompanyPicker` is the app's **only**
/// "New company" entry — `new_company` appears nowhere else in `lib/` — so
/// hiding the header without re-homing this control would leave a one-company
/// owner permanently unable to create a second one, a failure that locks
/// itself in. (Sign out is the softer half: it is also in Settings -> User
/// Details, whose `sign_out` search key makes it findable from both the
/// settings search and the command palette.)
///
/// **Sizing.** The avatar is 24, between the siblings' 18-px line glyphs and
/// the 28 both other `CompanyAvatar` mounts use: a filled square reads smaller
/// than a line glyph in the same box, and at 20 the initials would render at
/// `20 * 0.42` = 8.4 px, smaller than anything else in the app.
///
/// **Semantics are explicit, not inherited from the [Tooltip].** Unlike its
/// five siblings this action has a real text node inside it — `CompanyAvatar`
/// paints initials — so a tooltip-only label announces twice ("AC", then the
/// name). The initials are excluded and the label/hint set by hand, matching
/// `CompanyPicker._ActionRow`. The hint also carries "switch company", which is
/// what makes this findable by TalkBack's find-on-screen now that reaching it
/// means traversing the whole scrolling nav list first — it leads the footer
/// row, but the footer is the last thing in the drawer, where the header this
/// replaces was the fourth focusable on a touch drawer. (That hint is
/// English-only: `switch_company` is in `en.json` but in none of the ten
/// translated bundles, so it falls back to English on every locale.)
class SidebarCompanyFooterAction extends StatelessWidget {
  const SidebarCompanyFooterAction({
    required this.company,
    required this.onTap,
    this.touch = false,
    super.key,
  });

  /// Active company, or null when the roster is empty — the degenerate state
  /// issue #16 was about. That case gets a neutral business glyph and the
  /// "Switch company" label rather than the header switcher's '—' fallback: as
  /// the *sole* account affordance, a tinted square containing an em dash whose
  /// tooltip is also an em dash reads as a rendering bug, and the picker's own
  /// empty state (plus New company / Sign out) is a real recovery screen the
  /// user needs to be able to find.
  final AuthCompany? company;

  final VoidCallback onTap;

  /// Grows the action to [InSizes.touchTarget] tall, like its siblings.
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final me = company;
    final action = context.tr('switch_company');
    final label = me?.displayName ?? action;
    // Null company: label and hint would be the same string, and a screen
    // reader would say "Switch Company, button, Switch Company".
    final hint = label == action ? null : action;
    final Widget glyph = me == null
        ? Icon(Icons.business_outlined, size: 18, color: tokens.ink3)
        : CompanyAvatar(
            name: me.displayName,
            seed: me.id,
            size: 24,
            logoUrl: me.logoUrl,
          );
    return Tooltip(
      // The Semantics below owns the announcement; without this the tooltip
      // adds a second one.
      excludeFromSemantics: true,
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(InRadii.r2),
            child: _footerActionBody(
              touch: touch,
              glyph: ExcludeSemantics(child: glyph),
            ),
          ),
        ),
      ),
    );
  }
}

/// The theme switcher action. Unlike [_FooterAction] it owns a [GlobalKey] to
/// anchor the popup ([showThemeMenu]) and a dynamic icon that reflects the
/// active [ThemeMode] (sun / moon / auto), so the current theme reads at a
/// glance. The key lives in [State] so it stays stable across rebuilds — a
/// fresh `GlobalKey` per build would fail `Material.canUpdate` (keys differ by
/// identity) and needlessly remount the subtree, which can also drop the
/// popup's anchor mid-rebuild. (Collision isn't the concern — only one footer
/// is ever mounted, rail XOR drawer — instability across rebuilds is.)
class _ThemeFooterAction extends StatefulWidget {
  const _ThemeFooterAction({this.touch = false});

  final bool touch;

  @override
  State<_ThemeFooterAction> createState() => _ThemeFooterActionState();
}

class _ThemeFooterActionState extends State<_ThemeFooterAction> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = context.read<Services>().theme;
    return Tooltip(
      message: context.tr('appearance'),
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        key: _anchorKey,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: InkWell(
          onTap: () => showThemeMenu(context, anchorKey: _anchorKey),
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: _footerActionBody(
            touch: widget.touch,
            glyph: ListenableBuilder(
              listenable: theme,
              builder: (context, _) =>
                  Icon(_iconFor(theme.themeMode), size: 18, color: tokens.ink3),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };
}
