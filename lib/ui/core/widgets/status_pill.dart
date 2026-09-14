import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/link_text.dart' show linkNeedsAtRestCue;
import 'package:admin/ui/core/widgets/widget_preview_support.dart';

/// Small status badge — colored dot + label on a tinted-soft background,
/// wrapped in a rounded rectangle (never a stadium pill — see CLAUDE.md
/// "rounded rectangles, never pills").
///
/// The v2 system uses this shape everywhere an entity needs a state cue
/// (deleted / archived / unsynced on the clients list; paid / overdue /
/// draft / sent on invoices; user-defined task statuses on the task list).
///
/// Colors are passed in by the caller so this widget stays neutral. Pick
/// `(fgColor, bgColor)` pairs from `InTheme` (e.g. `paid` + `paidSoft`).
/// When the caller doesn't have a paired soft token (e.g. task statuses
/// store a per-company hex color), pass `bgColor: null` and the widget
/// derives the soft tone as `fgColor` at 15 % alpha.
///
/// **[fgColor] tints the dot, not the label.** Status colors are chosen to
/// read as *colors* against a pale tint of themselves, which makes them poor
/// text: `paid` on `paidSoft` measures 3.77:1 in light and 2.88:1 in dark
/// Espresso, against the 4.5:1 WCAG AA floor for an 11 px label — 20 of the
/// 36 theme x status combinations failed. The label uses `ink` instead
/// (worst case 11.35:1). Every per-entity wrapper — invoice, quote, credit,
/// payment, expense, recurring invoice, recurring expense — had already
/// arrived at `color: tokens.ink` independently; this just makes the
/// default agree with them, so the un-wrapped call sites (list tiles,
/// detail headers, system-log rows) stop being the exception.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.fgColor,
    this.bgColor,
    this.tooltip,
    this.dotSize = 5,
    this.textStyle,
    this.onTap,
    this.semanticsLabel,
    this.semanticsHint,
  });

  final String label;
  final Color fgColor;
  final Color? bgColor;
  final String? tooltip;
  final double dotSize;
  final TextStyle? textStyle;

  /// Makes the pill a control. **Opt-in, and it must stay that way**: the pill
  /// ships in narrow list rows and wide-table cells, where
  /// `docs/row-actions-and-values.md` § A narrow list row has exactly one
  /// destination forbids a second target, and in
  /// `payment_link_detail_screen.dart` inside a row that already navigates.
  /// With this null the widget builds exactly the tree it always has.
  ///
  /// The link branch differs in four ways, each with a reason:
  ///
  ///  * the ink is painted **inside** the decorated box (a `Material` around it
  ///    registers under the opaque tint and the splash is invisible — the
  ///    mechanism `no_ink_widget_test.dart` and `activity_record_row.dart`
  ///    both spell out), with the padding moved in so the whole pill is the
  ///    target;
  ///  * `overlayColor` is resolved explicitly, because the M3 default paints an
  ///    opaque dark wash over a tinted surface on macOS;
  ///  * focus is a **border**, not an overlay fill, which would erase the
  ///    status colour it sits on;
  ///  * the label underlines — at rest on touch, on hover with a pointer.
  ///
  /// The underline is the affordance and **the colour does not ride along**:
  /// `linkOrText` pairs `underlineAtRest` with `linkAtRestColor`, and copying
  /// that here would recolour the label to `accentInk` — a per-company derived
  /// colour, unmeasured against six status tints, on the one widget whose doc
  /// above records that 20 of 36 theme x status combinations failed contrast.
  /// The label stays `ink`.
  final VoidCallback? onTap;

  /// Overrides the announced label when [onTap] is set. Use it to announce the
  /// answer rather than the word on the pill — "Viewed by Jane Doe, 11 Sep
  /// 2026" instead of "Viewed".
  final String? semanticsLabel;

  /// Announced after the label, naming where [onTap] goes.
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) => onTap == null
      ? _wrapTooltip(_plain(context))
      : _wrapTooltip(_LinkPill(pill: this));

  Widget _wrapTooltip(Widget child) =>
      tooltip == null ? child : Tooltip(message: tooltip!, child: child);

  /// The row inside the decorated box — shared by both branches so the link
  /// variant can never drift from the plain one.
  Widget _content(BuildContext context, {bool underline = false}) {
    final tokens = context.inTheme;
    final base =
        textStyle ??
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.ink,
          letterSpacing: 0.2,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: fgColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // `copyWith` on the RESOLVED style, not on the default: all four
            // billing wrappers pass their own `textStyle` (13 px on a detail
            // header), so decorating the fallback would land on a branch they
            // never take.
            style: underline
                ? base.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: base.color,
                  )
                : base,
          ),
        ),
      ],
    );
  }

  Color get _bg => bgColor ?? fgColor.withValues(alpha: 0.15);

  Widget _plain(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(InRadii.r2),
    ),
    child: _content(context),
  );
}

/// The tappable branch of [StatusPill]. Separate and stateful only because the
/// hover underline needs somewhere to live; the plain pill stays stateless.
class _LinkPill extends StatefulWidget {
  const _LinkPill({required this.pill});

  final StatusPill pill;

  @override
  State<_LinkPill> createState() => _LinkPillState();
}

class _LinkPillState extends State<_LinkPill> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final pill = widget.pill;
    final tokens = context.inTheme;
    // At rest on touch, on hover with a pointer — the split
    // `docs/row-actions-and-values.md` sets, because a hover cue can never fire
    // on a finger. Computed here rather than by reusing `LinkText`, whose own
    // `MouseRegion` covers only the glyphs while this InkWell covers the whole
    // box: the two halves of one hover state would disagree over the padding.
    final underline = linkNeedsAtRestCue || _hovered;
    // The partial-exclude case that lint's own doc names: the
    // `ExcludeSemantics` below covers the LABEL only, so the `InkResponse`'s
    // node still supplies both the tap and the focus action and this role is
    // fully activatable. Re-declaring `onTap:` here would make this an explicit
    // node that stops merging that one — costing the FOCUS action, i.e. the
    // asked-for fix makes the control worse. `status_pill_test.dart`'s
    // "announces as an activatable button" asserts the real node carries
    // `hasTapAction` AND `hasFocusAction`, a stronger guard than a text scan.
    // lint: allow-semantics-no-ontap the excluded leaf is the label, not the action
    return Semantics(
      button: true,
      label: pill.semanticsLabel ?? pill.label,
      hint: pill.semanticsHint,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          decoration: BoxDecoration(
            color: pill._bg,
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          // Inside the decoration, so the ink paints over the tint rather than
          // under it. Transparent so the tint still shows through.
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: pill.onTap,
              borderRadius: BorderRadius.circular(InRadii.r2),
              // Three states, three answers. Hover is transparent because the
              // MouseRegion above owns it; pressed darkens; focus is a border
              // rather than a fill, because an opaque fill would erase the
              // status colour and this is the only focus cue the pill gets.
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.pressed)) return tokens.border;
                return Colors.transparent;
              }),
              focusColor: Colors.transparent,
              onFocusChange: (v) => setState(() => _focused = v),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  border: _focused
                      ? Border.all(color: tokens.accentInk, width: 1.5)
                      : null,
                ),
                child: Padding(
                  // The pill's own padding, moved inside the InkWell so the
                  // whole box is the target rather than just the text.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  // The LABEL's node is excluded, not the whole subtree.
                  // Without this the outer `Semantics.label` merges with the
                  // `Text`'s own node and a screen reader reads the answer and
                  // then the word on the pill again ("…11 Sep 2026. Viewed").
                  // Excluding higher up would take the `InkResponse`'s node
                  // with it — and that is where the tap action AND the focus
                  // action live, so the pill would announce as a button that
                  // could be neither invoked nor tabbed to.
                  child: ExcludeSemantics(
                    child: pill._content(context, underline: underline),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(name: 'All statuses', group: 'StatusPill', theme: appPreviewTheme)
Widget previewStatusPillAll() {
  return Builder(
    builder: (context) {
      final t = context.inTheme;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(label: 'Paid', fgColor: t.paid, bgColor: t.paidSoft),
            StatusPill(
              label: 'Overdue',
              fgColor: t.overdue,
              bgColor: t.overdueSoft,
            ),
            StatusPill(label: 'Sent', fgColor: t.sent, bgColor: t.sentSoft),
            StatusPill(label: 'Draft', fgColor: t.draft, bgColor: t.draftSoft),
            StatusPill(
              label: 'Partial',
              fgColor: t.partial,
              bgColor: t.partialSoft,
            ),
            // Auto-derived background (caller has no paired soft token).
            const StatusPill(label: 'Custom', fgColor: Color(0xFF8E44AD)),
            // The link variant. Underlined at rest here because the preview
            // reports a touch platform; with a pointer the underline arrives
            // on hover and the cursor changes.
            StatusPill(
              label: 'Viewed',
              fgColor: t.sent,
              bgColor: t.sentSoft,
              onTap: () {},
            ),
          ],
        ),
      );
    },
  );
}
