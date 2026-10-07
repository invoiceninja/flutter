import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// Inline chip rendering one [FilterToken] inside the token search field.
///
/// Two shapes:
///  * **Plain** (`token.displayComparator == null`): `<key> <value> ×` —
///    key muted, value bold. The body is one tap target ([onTap]).
///
/// The key label keeps the case it was given. It used to be lowercased for a
/// `key:value` look, which is wrong the moment the label is not English: a
/// German noun (`kunde`), an abbreviation (`ust-idnr.`), or the label a
/// company typed for its own custom field.
///  * **Segmented** (a comparable key — `displayComparator != null`):
///    `<field> | <comparator ▾> | <value ▾> | ×` — each of the three
///    parts is its own tap target so the user can change the comparator
///    or the value independently (Sentry-style). Field is faint, the
///    comparator mid-tone, the value bold; the comparator and value
///    segments carry a ▾ affordance and a hover tint.
///
/// The trailing `×` is always its own interactive node ([onRemove]) and
/// sits OUTSIDE every other tap region so its gesture always wins.
/// [FilterTokenChip.readOnly] is a compact, fully-inert variant for the
/// narrow-mode summary row — it shows the comparator inline but no
/// carets, dividers or `×` (false affordances on an inert chip).
class FilterTokenChip extends StatelessWidget {
  const FilterTokenChip({
    required this.token,
    required this.onRemove,
    this.onTap,
    this.onComparatorTap,
    this.onValueTap,
    this.armed = false,
    this.compact = false,
    super.key,
  }) : readOnly = false;

  const FilterTokenChip.readOnly({required this.token, super.key})
    : onRemove = _noop,
      onTap = null,
      onComparatorTap = null,
      onValueTap = null,
      armed = false,
      compact = false,
      readOnly = true;

  final FilterToken token;
  final VoidCallback onRemove;

  /// Tap on the field/value of a plain chip, or the field segment of a
  /// segmented chip. The argument is the tapped chip body's global rect,
  /// so the caller can anchor a dropdown directly at it (same contract as
  /// [onComparatorTap] / [onValueTap]). Null = inert.
  final void Function(Rect anchorGlobalRect)? onTap;

  /// Tap on the comparator segment (segmented chips only). The argument
  /// is the segment's global rect, so the caller can anchor a dropdown
  /// at it.
  final void Function(Rect anchorGlobalRect)? onComparatorTap;

  /// Tap on the value segment (segmented chips only). Same contract as
  /// [onComparatorTap].
  final void Function(Rect anchorGlobalRect)? onValueTap;

  final bool readOnly;

  /// True after one Backspace in the empty input: this chip is the one the
  /// next Backspace removes, and it says so with the accent border — the
  /// keyboard equivalent of pointing at its ✕.
  final bool armed;

  /// True where the chip sits in a row of fixed height (the wide search box):
  /// on a touch platform the ✕ then takes its height from the chip's own
  /// line and keeps a finger's WIDTH, instead of the theme padding its layout
  /// box to 40 px square — which made a single chip 50 px tall, taller than
  /// the header row it sat in. False (the phone sheet, which has the room)
  /// keeps the full square target. No effect with a pointer.
  final bool compact;

  static void _noop() {}

  bool get _segmented =>
      token.displayComparator != null && !readOnly && onTap != null;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final keyStyle = theme.textTheme.bodySmall?.copyWith(
      color: tokens.ink3,
      fontWeight: FontWeight.w500,
    );
    final comparatorStyle = theme.textTheme.bodySmall?.copyWith(
      color: tokens.ink2,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w600,
    );

    final decoration = BoxDecoration(
      color: readOnly ? tokens.surface : tokens.surfaceAlt,
      // Project rule: rounded rectangles, never pills.
      borderRadius: BorderRadius.circular(InRadii.r1),
      border: Border.all(color: armed ? tokens.accent : tokens.border),
    );

    if (_segmented) {
      return Semantics(
        container: true,
        child: Container(
          decoration: decoration,
          padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _Segment(
                  onTap: onTap == null ? null : (r) => onTap!(r),
                  semanticLabel:
                      '${token.displayKey}, ${context.tr('filter_field')}',
                  child: Text(
                    token.displayKey,
                    style: keyStyle,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
              _divider(tokens),
              _Segment(
                onTap: onComparatorTap,
                semanticLabel:
                    '${token.displayComparator}, '
                    '${context.tr('change_comparator')}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(token.displayComparator!, style: comparatorStyle),
                    _caret(tokens),
                  ],
                ),
              ),
              _divider(tokens),
              // Flexible so the value segment shrinks (its Text ellipsizes)
              // rather than overflowing when the chip is squeezed into a
              // narrow `Wrap` cell.
              Flexible(
                child: _Segment(
                  onTap: onValueTap,
                  semanticLabel:
                      '${token.displayValue}, ${context.tr('change_value')}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: _maybeTooltip(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              token.displayValue,
                              style: valueStyle,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      _caret(tokens),
                    ],
                  ),
                ),
              ),
              _closeButton(context, tokens),
            ],
          ),
        ),
      );
    }

    // ── Plain chip (non-comparable, or read-only summary) ──
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Key and value both shrink/ellipsize so the chip never overflows a
        // `Wrap` cell narrower than its natural width; the value is the long
        // part, so it carries most of the shrink.
        Flexible(
          child: Text(
            token.displayKey,
            style: keyStyle,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 4),
        if (token.displayComparator != null) ...[
          Text(token.displayComparator!, style: comparatorStyle),
          const SizedBox(width: 4),
        ],
        Flexible(
          flex: 2,
          child: _maybeTooltip(
            Text(
              token.displayValue,
              style: valueStyle,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
      ],
    );

    final tappableBody = onTap != null
        ? MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Builder(
              builder: (innerContext) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Report the tapped body's global rect (same pattern as
                // `_Segment`) so the caller can anchor the value/checkbox
                // dropdown directly under the chip instead of the field's
                // left edge.
                onTap: () {
                  final box = innerContext.findRenderObject();
                  if (box is! RenderBox || !box.attached) return;
                  onTap!(box.localToGlobal(Offset.zero) & box.size);
                },
                child: body,
              ),
            ),
          )
        : body;

    return Semantics(
      button: onTap != null,
      label:
          '${context.tr('filter_label_prefix')}: '
          '${token.displayKey} '
          '${token.displayComparator == null ? '' : '${token.displayComparator} '}'
          '${token.displayValue}',
      child: Container(
        decoration: decoration,
        padding: readOnly
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
            : const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible so a long value shrinks (its inner Text ellipsizes)
            // instead of overflowing when a `Wrap` squeezes the chip into a
            // cell narrower than its natural width.
            Flexible(child: tappableBody),
            if (!readOnly) ...[
              const SizedBox(width: 2),
              _closeButton(context, tokens),
            ],
          ],
        ),
      ),
    );
  }

  Widget _maybeTooltip(Widget child) => token.valueTooltip == null
      ? child
      : Tooltip(message: token.valueTooltip!, child: child);

  Widget _divider(InTheme tokens) => Container(
    width: 1,
    height: 14,
    color: tokens.border,
    margin: const EdgeInsets.symmetric(horizontal: 6),
  );

  Widget _caret(InTheme tokens) => Padding(
    padding: const EdgeInsets.only(left: 1),
    child: Icon(Icons.arrow_drop_down, size: 14, color: tokens.ink3),
  );

  Widget _closeButton(BuildContext context, InTheme tokens) {
    if (readOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: compact && Env.isTouchPrimary
          ? IconButton(
              tooltip: context.tr('clear_filter'),
              iconSize: 14,
              padding: EdgeInsets.zero,
              // `shrinkWrap`, no `visualDensity` — see `SidebarRowIconButton`
              // for why each is needed to make the constraints below real.
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              constraints: const BoxConstraints.tightFor(width: 40, height: 24),
              onPressed: onRemove,
              icon: Icon(Icons.close, color: tokens.ink3),
            )
          : IconButton(
              tooltip: context.tr('clear_filter'),
              iconSize: 14,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              // 24×24 hit slop — under that, iOS HIG reports the button as
              // below the minimum touch target. Icon stays 14 px for density.
              constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
              onPressed: onRemove,
              icon: Icon(Icons.close, color: tokens.ink3),
            ),
    );
  }
}

/// One tappable region of a segmented chip. Pointer cursor + a subtle
/// `surface→surfaceAlt`-style hover tint so the boundaries are
/// discoverable before the click (mirrors the suggestion menu's
/// `_Highlightable` hover model). Inert when [onTap] is null.
class _Segment extends StatefulWidget {
  const _Segment({
    required this.child,
    required this.semanticLabel,
    this.onTap,
  });

  final Widget child;
  final String semanticLabel;

  /// Receives this segment's global rect so the caller can anchor a
  /// dropdown directly at it. Null = inert.
  final void Function(Rect anchorGlobalRect)? onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: widget.child,
    );
    if (widget.onTap == null) return content;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final box = context.findRenderObject();
            if (box is! RenderBox || !box.attached) return;
            widget.onTap!(box.localToGlobal(Offset.zero) & box.size);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered ? tokens.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(InRadii.r1),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
