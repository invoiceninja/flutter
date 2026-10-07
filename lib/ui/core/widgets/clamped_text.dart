import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';

/// Free text the user wrote themselves — a note — held to [maxLines] with an
/// in-place More / Less.
///
/// A note has no length limit, so on a record screen an unclamped one decides
/// where everything under it starts. Clamping fixes that without hiding the
/// note: the first lines stay where the user will see them, and the rest is
/// one tap away *in place* — no navigation, no losing the scroll position.
///
/// The toggle appears only when the text actually overflows, measured against
/// the width it is given, so a two-line note never grows a pointless "More".
class ClampedText extends StatefulWidget {
  const ClampedText({
    super.key,
    required this.text,
    required this.maxLines,
    this.style,
  });

  final String text;
  final int maxLines;
  final TextStyle? style;

  @override
  State<ClampedText> createState() => _ClampedTextState();
}

class _ClampedTextState extends State<ClampedText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        final text = Text(
          widget.text,
          style: widget.style,
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
        );
        if (!overflows) return text;
        final tokens = context.inTheme;
        final label = context.tr(_expanded ? 'less' : 'more');
        void toggle() => setState(() => _expanded = !_expanded);
        // The WHOLE note is the tap target, with the word as its cue. A
        // separate 44 px button under two lines of text cost more height than
        // the clamp saved on a phone; two lines plus the cue already clear
        // the touch floor as one target.
        // One node: the note is the label and the cue is its hint. Left to
        // merge on its own this splits in two — the ink well's node carrying
        // the text, and a second one carrying the button role with nothing to
        // read.
        return Semantics(
          button: true,
          expanded: _expanded,
          label: widget.text,
          hint: label,
          onTap: toggle,
          excludeSemantics: true,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(InRadii.r1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.accentInk,
                    fontWeight: FontWeight.w600,
                    decoration: Env.isTouchPrimary
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
