import 'package:flutter/widgets.dart';

/// Whether a field taking [keyboardType] holds a value that reads left to
/// right in every language: a number, a phone number, an email address, a
/// URL or a password.
///
/// Compared by `index`: `TextInputType.numberWithOptions(signed:, decimal:)`
/// is a different object from `TextInputType.number` for every flag pair, but
/// all of them share the number index — `==` would miss the signed and
/// decimal variants, which are most of the money fields.
bool isLtrValueKeyboard(TextInputType? keyboardType) {
  final index = keyboardType?.index;
  return index == TextInputType.number.index ||
      index == TextInputType.phone.index ||
      index == TextInputType.emailAddress.index ||
      index == TextInputType.url.index ||
      index == TextInputType.visiblePassword.index;
}

/// The `textDirection` for a field whose value may read LTR in every
/// language — null (ambient) unless [ltr]. Typing `-12.5` into an RTL-directed
/// field draws `12.5-`; an email draws its `@` and dots in the wrong places.
TextDirection? ltrValueDirection({required bool ltr}) =>
    ltr ? TextDirection.ltr : null;

/// The `textAlign` that keeps an [ltr] value at the field's *ambient* start,
/// beside its label and prefix: in an RTL locale the digits run left to right
/// but sit against the right edge, the convention for numbers in RTL forms.
///
/// `end`, not `right`: the field itself is LTR, so its end is the right edge,
/// and nothing physical leaks into the call site. In an LTR locale this is
/// plain `start`, so nothing changes there.
TextAlign ltrValueAlign(BuildContext context, {required bool ltr}) =>
    ltr && Directionality.of(context) == TextDirection.rtl
    ? TextAlign.end
    : TextAlign.start;
