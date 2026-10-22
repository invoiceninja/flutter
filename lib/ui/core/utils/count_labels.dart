import 'package:flutter/widgets.dart';

import 'package:admin/l10n/localization.dart';

/// "1 day" / "30 days", from one translated template per form, so each
/// language puts the number and the word in its own order (`'$n ${tr('days')}'`
/// fixes English order into every language, a right-to-left one included).
String dayCountLabel(BuildContext context, int n) => context.tr(
  n == 1 ? 'day_count_singular' : 'day_count_plural',
  {'count': '$n'},
);

/// "1 client" / "12 clients" — see [dayCountLabel].
String clientCountLabel(BuildContext context, int n) => context.tr(
  n == 1 ? 'client_count_singular' : 'client_count_plural',
  {'count': '$n'},
);
