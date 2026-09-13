import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/billing/e_invoice_tab.dart';

/// Resolve whether this company's billing docs offer an **E-Invoice** tab.
///
/// One caller per host (invoice / credit / recurring invoice), each of which
/// starts with the tab hidden and reveals it if this answers true — see
/// [eInvoiceTabVisible] for why that direction, and for why this goes through
/// the **async** `SettingsRepository.resolved` rather than its synchronous
/// `resolvedIfReady` seed.
///
/// [context] is read synchronously, before the await, so a call site does not
/// trip `use_build_context_synchronously`. Callers still have to re-check
/// `mounted` after awaiting.
Future<bool> resolveEInvoiceTabVisible(
  BuildContext context,
  String companyId,
) async {
  final settings = context.read<Services>().settings;
  return eInvoiceTabVisible(await settings.resolved(companyId: companyId));
}
