import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/utils/formatting.dart';

/// The "Converted to :currency" caption for a money figure the server
/// exchange-rate-converted into the company base currency — or null when there
/// is nothing to flag.
///
/// Three conditions, all required:
///   * "All currencies" is selected. Only the `999` bucket is converted
///     (`SUM(amount / exchange_rate)` server-side); a specific currency renders
///     native amounts, untouched.
///   * The company actually trades in a second currency
///     ([hasForeignCurrency]). A GBP-only company was being told its untouched
///     GBP totals were "Converted to GBP", which reads as a caveat about
///     numbers nothing ever happened to (flutter#22).
///   * The base currency code resolves out of statics (cold-start guard).
///
/// Takes plain values rather than the `DashboardViewModel` so it stays
/// unit-testable and serves both the wide and mobile layouts. This is the only
/// place in `lib/` allowed to reference the `converted_to_currency` key — the
/// guard living in four copies is how it drifted in the first place
/// (`test/lint/converted_hint_single_source_test.dart` enforces that).
String? convertedToBaseCaption(
  BuildContext context, {
  required int selectedCurrencyId,
  required DashboardTotals? totals,
  required Formatter formatter,
}) {
  if (selectedCurrencyId != kDashboardCurrencyAll) return null;
  final baseId = formatter.settings.currencyId;
  if (!hasForeignCurrency(totals, baseId)) return null;
  final baseCode = formatter.currencies[baseId]?.code ?? '';
  if (baseCode.isEmpty) return null;
  return context.tr('converted_to_currency', {'currency': baseCode});
}
