import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

/// A value that reads left-to-right in every language — an amount, a number,
/// a date, a document number, an email, a phone number, a code.
///
/// Inside a right-to-left layout a plain `Text` would lay a value out in the
/// paragraph's direction, and the bidi algorithm then moves its neutrals:
/// `-$1,234.50` reads `$1,234.50-`, `3:45 PM` reads `PM 3:45`, `+1 (555)
/// 123-4567` comes out in reversed groups. This lays the text out
/// left-to-right while [textAlign] keeps meaning start / end of the
/// *surrounding* layout, so a right-aligned amount column still sits at the
/// end of the row in Arabic.
///
/// [keepRtlScript] is for a cell that may hold either kind of text (a name, a
/// free-text field): text containing any Arabic or Hebrew keeps the ambient
/// direction; everything else is laid out left-to-right.
///
/// Never put direction control characters in `Formatter` output instead — its
/// strings are parsed, compared and copied. See docs/right-to-left-layout.md.
class LtrText extends StatelessWidget {
  const LtrText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.keepRtlScript = false,
  });

  final String data;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final bool keepRtlScript;

  @override
  Widget build(BuildContext context) {
    final ambient = Directionality.of(context);
    if (ambient == TextDirection.ltr ||
        (keepRtlScript && Bidi.hasAnyRtl(data))) {
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }
    return Text(
      data,
      style: style,
      textDirection: TextDirection.ltr,
      textAlign: physicalTextAlign(textAlign, ambient),
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// [align] with start / end resolved against [ambient], for a `Text` whose own
/// direction differs from the layout it sits in.
TextAlign physicalTextAlign(TextAlign align, TextDirection ambient) {
  final rtl = ambient == TextDirection.rtl;
  return switch (align) {
    TextAlign.start => rtl ? TextAlign.right : TextAlign.left, // rtl: physical
    TextAlign.end => rtl ? TextAlign.left : TextAlign.right, // rtl: physical
    _ => align,
  };
}
